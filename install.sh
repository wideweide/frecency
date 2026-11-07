#!/bin/bash
# ============================================================================
# install.sh - frecency installer
# ============================================================================
# Installs:
#   scripts/frecency, scripts/frecency-test, scripts/bmark.sh
#                                         -> ${XDG_CONFIG_HOME:-~/.config}/vifm/scripts/
#   frecency.vifm                         -> ${XDG_CONFIG_HOME:-~/.config}/vifm/frecency.vifm
#   bundled/sqlite3-<arch>                -> vifm scripts/ (flattened)
#   shell/frecency.fish                   -> fish config dir (when fish is installed)
#   shell/frecency.bash                   -> ${XDG_CONFIG_HOME:-~/.config}/frecency/
#   nvim/frecency.lua                     -> nvim config dir (when init.lua exists)
#
# Registration appends a marked source/dofile line to vifmrc, config.fish,
# ~/.bashrc and init.lua. Markers prevent duplicate blocks; nothing is touched
# when the marker already exists.
#
# Usage:
#   ./install.sh                     interactive menu on a TTY; plain install
#                                     without registration otherwise
#   ./install.sh --register          install and register everything
#   ./install.sh --no-register       install files only, skip all registration
#   ./install.sh --unregister        show and remove registered source lines
#   ./install.sh --uninstall         remove installed files
#   ./install.sh --vifm-dir DIR      use DIR instead of ~/.config/vifm
#   ./install.sh --dry-run           show what would be done
#
# Requirements: bash 4.4+, sqlite3 >= 3.35 with exp() (bundled static binaries
# are used as fallback), fzf >= 0.48 for the interactive UI.
# ============================================================================
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
XDG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
VIFM_DIR="${XDG_DIR}/vifm"
VIFMRC=""
FISH_DIR="${XDG_DIR}/fish"
FISH_FILE="${FISH_DIR}/frecency.fish"
FISH_CONFIG="${FISH_DIR}/config.fish"
BASH_DIR="${XDG_DIR}/frecency"
BASH_FILE="${BASH_DIR}/frecency.bash"
BASH_RC="${BASH_RC:-$HOME/.bashrc}"
NVIM_DIR="${XDG_DIR}/nvim"
NVIM_FILE="${NVIM_DIR}/frecency/frecency.lua"
NVIM_INIT="${NVIM_DIR}/init.lua"

SCRIPTS=(frecency frecency-test bmark.sh)
BUNDLED=(bundled/sqlite3-x86_64 bundled/sqlite3-arm64)

DRY_RUN=0
UNINSTALL=0
UNREGISTER=0
NO_REGISTER=0
REGISTER=-1   # vifm only: -1 = undecided, 0 = skip, 1 = register
MODE_GIVEN=0
while [[ $# -gt 0 ]]; do
    arg="$1"
    case "$arg" in
        --dry-run)     DRY_RUN=1 ;;
        --uninstall)   UNINSTALL=1; MODE_GIVEN=1 ;;
        --unregister)  UNREGISTER=1; MODE_GIVEN=1 ;;
        --register)    REGISTER=1; MODE_GIVEN=1 ;;
        --no-register) REGISTER=0; NO_REGISTER=1; MODE_GIVEN=1 ;;
        --vifm-dir)
            [[ $# -ge 2 ]] || { printf '--vifm-dir requires a directory\n' >&2; exit 2; }
            VIFM_DIR="$2"; shift ;;
        --vifm-dir=*)  VIFM_DIR="${arg#*=}" ;;
        -h|--help)
            sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)
            printf 'unknown option: %s (see --help)\n' "$arg" >&2; exit 2 ;;
    esac
    shift
done
VIFMRC="${VIFM_DIR}/vifmrc"

run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        printf '[dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

# Is this file already registered? Match the marker literally (-- in case the
# marker itself starts with dashes, e.g. the Lua comment "-- #frecency for nvim").
has_marker() { [[ -f "$1" ]] && grep -qF -- "$2" "$1"; }

# Append "<marker>\n<source line>\n" unless the marker is already present.
register_source() {
    local file="$1" marker="$2" source_line="$3" label="$4"
    if has_marker "$file" "$marker"; then
        printf '%s already registered in %s; leaving it untouched.\n' "$label" "$file"
        printf '  Compare the existing block with the installed files, or delete\n'
        printf '  the marked block from %s and re-run with --register.\n' "$file"
        return 0
    fi
    printf 'Registering %s in %s\n' "$label" "$file"
    run mkdir -p "$(dirname "$file")"
    if [[ $DRY_RUN -eq 0 ]]; then
        # Ensure the existing last line is terminated before appending.
        [[ -f "$file" && -s "$file" ]] && printf '\n' >> "$file"
        printf '%s\n%s\n' "$marker" "$source_line" >> "$file"
    else
        printf '[dry-run] append to %s: %s / %s\n' "$file" "$marker" "$source_line"
    fi
}

# Remove the marker line and the immediately following source line.
unregister_source() {
    local file="$1" marker="$2" source_line="$3" label="$4"
    [[ -f "$file" ]] || { printf '%s: %s not found, nothing to do.\n' "$label" "$file"; return 0; }
    has_marker "$file" "$marker" || { printf '%s: no registration marker in %s.\n' "$label" "$file"; return 0; }

    printf 'Will remove %s registration from %s:\n' "$label" "$file"
    awk -v m="$marker" 'index($0, m) { print "  -", $0; found=1; next }
        found && !done { print "  -", $0; done=1; exit }' "$file"
    printf '\n'

    local tmp="${file}.frecency.$$"
    awk -v m="$marker" -v s="$source_line" '
        index($0, m) { skip = 1; next }
        skip == 1 {
            if (index($0, s)) { skip = 0; next }
            skip = 0
        }
        { print }
    ' "$file" > "$tmp"
    if [[ $DRY_RUN -eq 1 ]]; then
        rm -f "$tmp"
    else
        mv -f "$tmp" "$file"
        printf 'Removed %s registration from %s\n' "$label" "$file"
    fi
}

# Warn (never block) when vifmrc already maps a key that frecency.vifm
# redefines. Best effort: only definitions written in vifmrc itself are
# visible here; vifm defaults, mappings from other sourced files and runtime
# :map commands cannot be detected from a config file.
warn_vifm_key_conflicts() {
    [[ -f "$VIFMRC" ]] || return 0
    # Keys frecency.vifm redefines; compared case-insensitively (<cr>/<CR>, o/O).
    local -a ours=('l' '<cr>' 'dd' 'm' 'o')
    local line lineno norm cmd rest tok k found=0
    while IFS= read -r line; do
        lineno="${line%%:*}"
        norm="${line#*:}"
        norm="${norm#"${norm%%[![:space:]]*}"}"
        norm="${norm#:}"
        norm="${norm#"${norm%%[![:space:]]*}"}"
        cmd="${norm%%[[:space:]]*}"
        case "$cmd" in
            nn|nnoremap|nm|nmap|no|noremap|vn|vnoremap|vm|vmap|mn|mnoremap|mm|mmap|map) ;;
            *) continue ;;
        esac
        rest="${norm#"$cmd"}"
        rest="${rest#"${rest%%[![:space:]]*}"}"
        # Inspect at most the first two tokens after the command (skipping
        # <silent>): the lhs, possibly preceded by mode letters (":map n l ...").
        local checked=0
        while [[ $checked -lt 2 && -n "$rest" ]]; do
            tok="${rest%%[[:space:]]*}"
            rest="${rest#"$tok"}"
            rest="${rest#"${rest%%[![:space:]]*}"}"
            if [[ "$tok" == "<silent>" ]]; then
                continue
            fi
            checked=$((checked + 1))
            local hit=0
            for k in "${ours[@]}"; do
                if [[ "${tok,,}" == "$k" ]]; then
                    hit=1
                fi
            done
            if [[ $hit -eq 1 ]]; then
                if [[ $found -eq 0 ]]; then
                    printf '\nwarning: %s already maps keys that frecency.vifm redefines\n' "$VIFMRC"
                    printf '         (frecency is sourced last and wins; edit frecency.vifm to change its keys):\n'
                    found=1
                fi
                printf '  line %s: %s\n' "$lineno" "$norm"
            fi
        done
    done < <(grep -nE '^[[:space:]]*:?[[:space:]]*(nn|nnoremap|nm|nmap|no|noremap|vn|vnoremap|vm|vmap|mn|mnoremap|mm|mmap|map)([[:space:]]|$)' "$VIFMRC" || true)
}

# ---------------------------------------------------------------------------
# Interactive menu (no mode flags given + TTY)
# ---------------------------------------------------------------------------
interactive_menu() {
    printf 'frecency installer\n'
    printf '==================\n'
    printf '  vifm dir: %s\n\n' "$VIFM_DIR"
    printf '  1) Install and register everything (recommended)\n'
    printf '  2) Install files only (skip registration)\n'
    printf '  3) Unregister (remove source lines)\n'
    printf '  4) Uninstall (remove installed files)\n'
    printf '  5) Dry-run: preview install + register\n'
    printf '  q) Quit\n'
    printf 'Choice [1]: '
    local choice
    read -r choice || choice=""
    case "${choice:-1}" in
        1) REGISTER=1 ;;
        2) REGISTER=0; NO_REGISTER=1 ;;
        3) UNREGISTER=1 ;;
        4) UNINSTALL=1 ;;
        5) DRY_RUN=1; REGISTER=1 ;;
        q|Q) exit 0 ;;
        *)  printf 'Invalid choice: %s\n' "$choice" >&2; exit 2 ;;
    esac
}

if [[ $MODE_GIVEN -eq 0 && -t 0 ]]; then
    interactive_menu
fi

register_vifm() {
    warn_vifm_key_conflicts
    register_source "$VIFMRC" '" #frecency for vifm' \
        "source ${VIFM_DIR}/frecency.vifm" "frecency vifm"
}

# ---------------------------------------------------------------------------
# Unregister only
# ---------------------------------------------------------------------------
if [[ $UNREGISTER -eq 1 ]]; then
    unregister_source "$VIFMRC"  '" #frecency for vifm' "source ${VIFM_DIR}/frecency.vifm" "frecency vifm"
    unregister_source "$FISH_CONFIG" '#frecency for fish' "source ${FISH_FILE}" "frecency fish"
    unregister_source "$BASH_RC" '#frecency for bash' "source ${BASH_FILE}" "frecency bash"
    unregister_source "$NVIM_INIT" '-- #frecency for nvim' "dofile(\"${NVIM_FILE}\")" "frecency nvim"
    exit 0
fi

# ---------------------------------------------------------------------------
# Uninstall installed files
# ---------------------------------------------------------------------------
if [[ $UNINSTALL -eq 1 ]]; then
    removed=()
    for f in "${SCRIPTS[@]}" "${BUNDLED[@]##*/}"; do
        if [[ -e "$VIFM_DIR/scripts/$f" ]]; then
            run rm -f "$VIFM_DIR/scripts/$f"
            removed+=("$VIFM_DIR/scripts/$f")
        fi
    done
    for f in "$VIFM_DIR/frecency.vifm" "$FISH_FILE" "$BASH_FILE" "$NVIM_FILE"; do
        if [[ -e "$f" ]]; then
            run rm -f "$f"
            removed+=("$f")
        fi
    done
    [[ $DRY_RUN -eq 0 ]] && printf 'Removed %d file(s).\n' "${#removed[@]}"
    printf 'Registration lines were left in place; run --unregister to remove them.\n'
    exit 0
fi

# ---------------------------------------------------------------------------
# Install files
# ---------------------------------------------------------------------------
[[ -x "$SRC_DIR/scripts/frecency" ]] || {
    printf 'frecency not found in %s/scripts\n' "$SRC_DIR" >&2; exit 1
}

TARGET="$VIFM_DIR/scripts"
installed=()
run mkdir -p "$TARGET"
for f in "${SCRIPTS[@]}"; do
    run install -m 755 "$SRC_DIR/scripts/$f" "$TARGET/$f"
    installed+=("$TARGET/$f")
done
run install -m 644 "$SRC_DIR/frecency.vifm" "$VIFM_DIR/frecency.vifm"
installed+=("$VIFM_DIR/frecency.vifm")
for f in "${BUNDLED[@]}"; do
    [[ -e "$SRC_DIR/$f" ]] || continue
    run install -m 755 "$SRC_DIR/$f" "$TARGET/${f##*/}"
    installed+=("$TARGET/${f##*/}")
done

if [[ $DRY_RUN -eq 0 ]]; then
    printf 'Installed %d file(s) into %s and %s\n' "${#installed[@]}" "$TARGET" "$VIFM_DIR"
fi

# ---------------------------------------------------------------------------
# Shell integration (only when the shell is installed)
# ---------------------------------------------------------------------------
if [[ -f "$SRC_DIR/shell/frecency.fish" ]] && command -v fish >/dev/null 2>&1; then
    run install -m 644 "$SRC_DIR/shell/frecency.fish" "$FISH_FILE"
    if [[ $NO_REGISTER -eq 0 ]]; then
        register_source "$FISH_CONFIG" '#frecency for fish' "source ${FISH_FILE}" "frecency fish"
    else
        printf 'fish: integration file installed; registration skipped (--no-register).\n'
    fi
else
    printf 'fish: not installed; skipping.\n'
fi

if [[ -f "$SRC_DIR/shell/frecency.bash" ]]; then
    run mkdir -p "$BASH_DIR"
    run install -m 644 "$SRC_DIR/shell/frecency.bash" "$BASH_FILE"
    if [[ $NO_REGISTER -eq 0 ]]; then
        if [[ -e "$BASH_RC" ]]; then
            register_source "$BASH_RC" '#frecency for bash' "source ${BASH_FILE}" "frecency bash"
        else
            printf 'bash: %s not found; add this line manually:\n  source %s\n' "$BASH_RC" "$BASH_FILE"
        fi
    else
        printf 'bash: integration file installed; registration skipped (--no-register).\n'
    fi
fi

# ---------------------------------------------------------------------------
# Neovim integration (only when an init.lua exists)
# ---------------------------------------------------------------------------
if [[ -f "$SRC_DIR/nvim/frecency.lua" && -f "$NVIM_INIT" ]]; then
    run mkdir -p "$(dirname "$NVIM_FILE")"
    run install -m 644 "$SRC_DIR/nvim/frecency.lua" "$NVIM_FILE"
    if [[ $NO_REGISTER -eq 0 ]]; then
        register_source "$NVIM_INIT" '-- #frecency for nvim' "dofile(\"${NVIM_FILE}\")" "frecency nvim"
    else
        printf 'nvim: integration file installed; registration skipped (--no-register).\n'
    fi
else
    printf 'nvim: %s not found; skipping.\n' "$NVIM_INIT"
fi

# ---------------------------------------------------------------------------
# Vifm registration (optional)
# ---------------------------------------------------------------------------
if [[ $REGISTER -eq -1 ]]; then
    REGISTER=0
    printf 'Non-interactive session: skipping vifm registration (use --register).\n'
fi

if [[ $REGISTER -eq 1 ]]; then
    register_vifm
else
    printf 'Skipped vifm registration. Add this line to %s manually:\n' "$VIFMRC"
    printf '  " #frecency for vifm\n  source %s/frecency.vifm\n' "$VIFM_DIR"
fi

# ---------------------------------------------------------------------------
if [[ $DRY_RUN -eq 0 ]]; then
    printf '\nRunning self-check...\n'
    "$TARGET/frecency-test" || printf 'self-check reported issues (see above)\n'
fi

cat <<EOF

Done.

Installed:
  vifm scripts : $TARGET
  vifm plugin  : $VIFM_DIR/frecency.vifm
  fish (if any): $FISH_FILE
  bash         : $BASH_FILE
  nvim (if any): $NVIM_FILE

Vifm keys (all defined in frecency.vifm):
  l / <cr>  open and record the file
  dd        delete and remove the record
  M         create a bookmark (keyword)
  o         jump from history (EMS + match grade)
  O         browse the current directory tree with fzf

See README.md for key conflicts, customization and configuration options
(SEARCH_MODE / GRADE_MODE / MULTIWORD_MODE ...).
EOF

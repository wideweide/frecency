#!/bin/bash
# ============================================================================
# install.sh - frecency installer
# ============================================================================
# Installs:
#   scripts/frecency, scripts/frecency-test, scripts/bmark.sh
#                                         -> ${XDG_CONFIG_HOME:-~/.config}/vifm/scripts/
#   frecency.vifm                         -> ${XDG_CONFIG_HOME:-~/.config}/vifm/frecency.vifm
#   bundled/sqlite3-<native arch>         -> vifm scripts/ (only when the system
#                                            sqlite3 does not already qualify)
#   shell/frecency.fish                   -> fish config dir (when fish is installed)
#   shell/frecency.bash                   -> ${XDG_CONFIG_HOME:-~/.config}/frecency/
#   nvim/frecency.lua                     -> nvim config dir (when init.lua exists)
#   symlink                               -> ${XDG_BIN_HOME:-~/.local/bin}/frecency
#
# Registration appends a marked source/dofile line to vifmrc, config.fish,
# ~/.bashrc and init.lua. Markers prevent duplicate blocks; nothing is touched
# when the marker already exists.
#
# The ~/.local/bin symlink makes the frecency script reachable from any shell
# (bash, fish, zsh, ...) without further PATH setup.
#
# Usage:
#   ./install.sh                     interactive menu on a TTY; plain install
#                                     (files only, no registration) otherwise
#   ./install.sh --register          install and register everything
#   ./install.sh --no-register       install files only, skip all registration
#   ./install.sh --unregister        show and remove registered source lines
#   ./install.sh --uninstall         remove registration lines and installed files
#   ./install.sh --vifm-dir DIR      use DIR instead of ~/.config/vifm
#   ./install.sh --bin-link          create the ~/.local/bin symlink (default
#                                     with --register; skipped otherwise)
#   ./install.sh --no-bin-link       never create the symlink
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
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
BIN_LINK_TARGET="$VIFM_DIR/scripts/frecency"

# Only the native-architecture sqlite3 is installed; frecency-test probes it.
ARCH=""
case "$(uname -m)" in
    x86_64|amd64)  ARCH="x86_64" ;;
    aarch64|arm64) ARCH="arm64"  ;;
esac

SCRIPTS=(frecency frecency-test bmark.sh)
# Both architecture binaries are removed by --uninstall (leftovers of older
# installs that shipped both); only the native one is installed.
BUNDLED_ALL=(sqlite3-x86_64 sqlite3-arm64)

DRY_RUN=0
UNINSTALL=0
UNREGISTER=0
REGISTER=-1   # vifm: -1 = undecided, 0 = skip, 1 = register
REG_FISH=-1   # same tri-state for the other integrations
REG_BASH=-1
REG_NVIM=-1
BIN_LINK=-1   # symlink in $BIN_DIR: -1 = undecided, 0 = skip, 1 = create
MODE_GIVEN=0
while [[ $# -gt 0 ]]; do
    arg="$1"
    case "$arg" in
        --dry-run)     DRY_RUN=1 ;;
        --uninstall)   UNINSTALL=1; MODE_GIVEN=1 ;;
        --unregister)  UNREGISTER=1; MODE_GIVEN=1 ;;
        --register)    REGISTER=1; REG_FISH=1; REG_BASH=1; REG_NVIM=1; BIN_LINK=1; MODE_GIVEN=1 ;;
        --no-register) REGISTER=0; REG_FISH=0; REG_BASH=0; REG_NVIM=0; MODE_GIVEN=1 ;;
        --bin-link)    BIN_LINK=1 ;;
        --no-bin-link) BIN_LINK=0 ;;
        --vifm-dir)
            [[ $# -ge 2 ]] || { printf '--vifm-dir requires a directory\n' >&2; exit 2; }
            VIFM_DIR="$2"; shift ;;
        --vifm-dir=*)  VIFM_DIR="${arg#*=}" ;;
        -h|--help)
            sed -n '2,37p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)
            printf 'unknown option: %s (see --help)\n' "$arg" >&2; exit 2 ;;
    esac
    shift
done
VIFMRC="${VIFM_DIR}/vifmrc"
BIN_LINK_TARGET="$VIFM_DIR/scripts/frecency"

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
        # Terminate an unterminated last line before appending (no extra blank
        # line when the file already ends with a newline).
        if [[ -f "$file" && -s "$file" ]] && [[ -n "$(tail -c 1 "$file")" ]]; then
            printf '\n' >> "$file"
        fi
        printf '%s\n%s\n' "$marker" "$source_line" >> "$file"
    else
        printf '[dry-run] append to %s: %s / %s\n' "$file" "$marker" "$source_line"
    fi
}

# Remove the marked block: the marker line through the first following line
# that references this project's file. The reference line is matched by file
# name (frecency.vifm / frecency.fish / ...), not by the absolute path that
# was written at registration time, so hand-written variants such as
# "source ~/.config/vifm/frecency.vifm" are removed as well. Comment lines
# between the marker and the reference are included; when no reference line
# follows, nothing is removed and the user is asked to check manually.
unregister_source() {
    local file="$1" marker="$2" fname="$3" label="$4"
    [[ -f "$file" ]] || { printf '%s: %s not found, nothing to do.\n' "$label" "$file"; return 0; }
    has_marker "$file" "$marker" || { printf '%s: no registration marker in %s.\n' "$label" "$file"; return 0; }

    local marker_ln src_ln
    marker_ln=$(grep -nF -- "$marker" "$file" | head -n 1 | cut -d: -f1)
    src_ln=$(awk -v start="$marker_ln" -v fname="$fname" '
        NR > start {
            if (index($0, fname)) { print NR; exit }
            # Only comment lines may sit between the marker and the reference;
            # a blank line or any code line ends the block.
            if ($0 ~ /^[[:space:]]*$/ || $0 !~ /^[[:space:]]*(#|--|")/) exit
        }' "$file")
    if [[ -z "$src_ln" ]]; then
        printf '%s: marker found in %s but no line referencing %s follows;\n' "$label" "$file" "$fname"
        printf '  leaving the block untouched - please check %s manually.\n' "$file"
        return 0
    fi

    printf 'Will remove %s registration from %s:\n' "$label" "$file"
    sed -n "${marker_ln},${src_ln}p" "$file" | sed 's/^/  - /'
    printf '\n'

    if [[ $DRY_RUN -eq 1 ]]; then
        return 0
    fi
    local tmp="${file}.frecency.$$"
    sed "${marker_ln},${src_ln}d" "$file" > "$tmp" && mv -f "$tmp" "$file"
    printf 'Removed %s registration from %s\n' "$label" "$file"
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
# Ask a yes/no question; empty input accepts the default.
ask_yes() {
    local prompt="$1" default="$2" choice
    printf '%s [%s]: ' "$prompt" "$default"
    read -r choice || choice=""
    choice="${choice:-$default}"
    case "$choice" in
        y|Y|yes|Yes) return 0 ;;
        *)           return 1 ;;
    esac
}

# Per-integration choices for menu entry 2.
choose_integrations() {
    if ask_yes 'Register vifm (source line in vifmrc)' 'Y'; then REGISTER=1; else REGISTER=0; fi
    if command -v fish >/dev/null 2>&1; then
        if ask_yes 'Register fish (source line in config.fish)' 'Y'; then REG_FISH=1; else REG_FISH=0; fi
    else
        printf 'fish not installed; skipping fish integration.\n'
        REG_FISH=0
    fi
    if ask_yes 'Register bash (source line in ~/.bashrc)' 'Y'; then REG_BASH=1; else REG_BASH=0; fi
    if [[ -f "$NVIM_INIT" ]]; then
        if ask_yes 'Register Neovim (dofile line in init.lua)' 'Y'; then REG_NVIM=1; else REG_NVIM=0; fi
    else
        printf '%s not found; skipping Neovim integration.\n' "$NVIM_INIT"
        REG_NVIM=0
    fi
    if ask_yes "Create $BIN_DIR/frecency symlink (usable from any shell)" 'Y'; then BIN_LINK=1; else BIN_LINK=0; fi
}

interactive_menu() {
    printf 'frecency installer\n'
    printf '==================\n'
    printf '  vifm dir: %s\n\n' "$VIFM_DIR"
    printf '  1) Install and register everything (recommended)\n'
    printf '  2) Install, choosing each integration individually\n'
    printf '  3) Install files only (skip registration)\n'
    printf '  4) Unregister (remove source lines)\n'
    printf '  5) Uninstall (remove installed files)\n'
    printf '  6) Dry-run: preview install + register\n'
    printf '  q) Quit\n'
    printf 'Choice [1]: '
    local choice
    read -r choice || choice=""
    case "${choice:-1}" in
        1) REGISTER=1; REG_FISH=1; REG_BASH=1; REG_NVIM=1; BIN_LINK=1 ;;
        2) choose_integrations ;;
        3) REGISTER=0; REG_FISH=0; REG_BASH=0; REG_NVIM=0; BIN_LINK=0 ;;
        4) UNREGISTER=1 ;;
        5) UNINSTALL=1 ;;
        6) DRY_RUN=1; REGISTER=1; REG_FISH=1; REG_BASH=1; REG_NVIM=1; BIN_LINK=1 ;;
        q|Q) exit 0 ;;
        *)  printf 'Invalid choice: %s\n' "$choice" >&2; exit 2 ;;
    esac
}

if [[ $MODE_GIVEN -eq 0 && -t 0 ]]; then
    interactive_menu
elif [[ $REGISTER -eq -1 && $UNREGISTER -eq 0 && $UNINSTALL -eq 0 ]]; then
    # Non-interactive install without an explicit mode: plain install. Files
    # are installed; no rc file is touched and no symlink is created.
    # Everything is opt-in via --register / --bin-link.
    REGISTER=0; REG_FISH=0; REG_BASH=0; REG_NVIM=0
    printf 'Non-interactive session: installing files only (no registration).\n'
    printf 'Use --register to also register vifm/fish/bash/nvim, --bin-link for the symlink.\n'
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
    unregister_source "$VIFMRC"     '" #frecency for vifm' 'frecency.vifm' "frecency vifm"
    unregister_source "$FISH_CONFIG" '#frecency for fish'  'frecency.fish' "frecency fish"
    unregister_source "$BASH_RC"     '#frecency for bash'  'frecency.bash' "frecency bash"
    unregister_source "$NVIM_INIT"   '-- #frecency for nvim' 'frecency.lua' "frecency nvim"
    exit 0
fi

# ---------------------------------------------------------------------------
# Uninstall: remove the registration lines first (a reference to a removed
# file would only error at startup), then the installed files themselves
# ---------------------------------------------------------------------------
if [[ $UNINSTALL -eq 1 ]]; then
    unregister_source "$VIFMRC"      '" #frecency for vifm'  'frecency.vifm' "frecency vifm"
    unregister_source "$FISH_CONFIG" '#frecency for fish'    'frecency.fish' "frecency fish"
    unregister_source "$BASH_RC"     '#frecency for bash'    'frecency.bash' "frecency bash"
    unregister_source "$NVIM_INIT"   '-- #frecency for nvim' 'frecency.lua'  "frecency nvim"

    removed=()
    for f in "${SCRIPTS[@]}" "${BUNDLED_ALL[@]}"; do
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
    # Our symlink only; anything else at that path is left alone.
    if [[ -L "$BIN_DIR/frecency" ]] \
        && [[ "$(readlink "$BIN_DIR/frecency")" == "$BIN_LINK_TARGET" ]]; then
        run rm -f "$BIN_DIR/frecency"
        removed+=("$BIN_DIR/frecency")
    fi
    # Directories that only held installed files (rmdir: never recursive).
    for d in "$BASH_DIR" "$(dirname "$NVIM_FILE")"; do
        if [[ -d "$d" ]]; then
            run rmdir --ignore-fail-on-non-empty "$d" || true
        fi
    done
    [[ $DRY_RUN -eq 0 ]] && printf 'Removed %d file(s) and cleaned up registration lines.\n' "${#removed[@]}"
    exit 0
fi

# ---------------------------------------------------------------------------
# Install files
# ---------------------------------------------------------------------------
[[ -x "$SRC_DIR/scripts/frecency" ]] || {
    printf 'frecency not found in %s/scripts\n' "$SRC_DIR" >&2; exit 1
}

# Does the system sqlite3 satisfy frecency's requirements: >= 3.35.0 built
# with exp()? Same checks as frecency's own resolver (version + real exp()
# probe, not just the version number).
_install_ver_num() { awk -F. '{printf "%d", ($1*1000000)+($2*1000)+$3}' <<< "$1"; }

system_sqlite_ok() {
    command -v sqlite3 >/dev/null 2>&1 || return 1
    local v
    v=$(sqlite3 --version 2>/dev/null | awk '{print $1}') || return 1
    [[ -n "$v" ]] || return 1
    (( $(_install_ver_num "$v") >= 3035000 )) || return 1
    [[ "$(sqlite3 :memory: "SELECT printf('%.4f', exp(1));" 2>/dev/null)" == "2.7183" ]]
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
# The bundled static binary is only installed when the system sqlite3 does
# not already satisfy the requirements; it is a fallback for machines without
# a usable system sqlite3. Only the native-architecture binary is installed,
# and stale binaries from older installs are pruned. When the choice was left
# to frecency-test below, its self-check rewrites the selection cache.
BUNDLED_KEEP=""
if [[ -n "$ARCH" ]]; then
    if system_sqlite_ok; then
        printf 'System sqlite3 (%s) meets the requirements; skipping the bundled static binary.\n' \
            "$(sqlite3 --version 2>/dev/null | awk '{print $1}')"
    elif [[ -e "$SRC_DIR/bundled/sqlite3-$ARCH" ]]; then
        printf 'System sqlite3 does not qualify; installing the bundled static binary (%s).\n' "$ARCH"
        run install -m 755 "$SRC_DIR/bundled/sqlite3-$ARCH" "$TARGET/sqlite3-$ARCH"
        installed+=("$TARGET/sqlite3-$ARCH")
        BUNDLED_KEEP="sqlite3-$ARCH"
    else
        printf 'No usable system sqlite3 and no bundled binary for %s; install sqlite3 >= 3.35.\n' "$(uname -m)"
    fi
    for f in "${BUNDLED_ALL[@]}"; do
        [[ "$f" == "$BUNDLED_KEEP" ]] && continue
        if [[ -e "$TARGET/$f" ]]; then
            printf 'Removing stale bundled binary: %s\n' "$TARGET/$f"
            run rm -f "$TARGET/$f"
        fi
    done
else
    printf 'Unknown architecture %s; skipping bundled sqlite3 (system sqlite3 is used).\n' "$(uname -m)"
fi

if [[ $DRY_RUN -eq 0 ]]; then
    printf 'Installed %d file(s) into %s and %s\n' "${#installed[@]}" "$TARGET" "$VIFM_DIR"
fi

# ---------------------------------------------------------------------------
# Shell integration (only when the shell is installed)
# ---------------------------------------------------------------------------
if [[ -f "$SRC_DIR/shell/frecency.fish" ]] && command -v fish >/dev/null 2>&1; then
    run mkdir -p "$FISH_DIR"
    run install -m 644 "$SRC_DIR/shell/frecency.fish" "$FISH_FILE"
    if [[ $REG_FISH -eq 1 ]]; then
        register_source "$FISH_CONFIG" '#frecency for fish' "source ${FISH_FILE}" "frecency fish"
    else
        printf 'fish: integration file installed; registration skipped.\n'
    fi
else
    printf 'fish: not installed; skipping.\n'
fi

if [[ -f "$SRC_DIR/shell/frecency.bash" ]]; then
    run mkdir -p "$BASH_DIR"
    run install -m 644 "$SRC_DIR/shell/frecency.bash" "$BASH_FILE"
    if [[ $REG_BASH -eq 1 ]]; then
        if [[ -e "$BASH_RC" ]]; then
            register_source "$BASH_RC" '#frecency for bash' "source ${BASH_FILE}" "frecency bash"
        else
            printf 'bash: %s not found; add this line manually:\n  source %s\n' "$BASH_RC" "$BASH_FILE"
        fi
    else
        printf 'bash: integration file installed; registration skipped.\n'
    fi
fi

# ---------------------------------------------------------------------------
# Neovim integration (only when an init.lua exists)
# ---------------------------------------------------------------------------
if [[ -f "$SRC_DIR/nvim/frecency.lua" && -f "$NVIM_INIT" ]]; then
    run mkdir -p "$(dirname "$NVIM_FILE")"
    run install -m 644 "$SRC_DIR/nvim/frecency.lua" "$NVIM_FILE"
    if [[ $REG_NVIM -eq 1 ]]; then
        register_source "$NVIM_INIT" '-- #frecency for nvim' "dofile(\"${NVIM_FILE}\")" "frecency nvim"
    else
        printf 'nvim: integration file installed; registration skipped.\n'
    fi
else
    printf 'nvim: %s not found; skipping.\n' "$NVIM_INIT"
fi

# ---------------------------------------------------------------------------
# Vifm registration (optional)
# ---------------------------------------------------------------------------
if [[ $REGISTER -eq 1 ]]; then
    register_vifm
else
    printf 'Skipped vifm registration. Add this line to %s manually:\n' "$VIFMRC"
    printf '  " #frecency for vifm\n  source %s/frecency.vifm\n' "$VIFM_DIR"
fi

# ---------------------------------------------------------------------------
# ~/.local/bin symlink: makes `frecency` reachable from any shell without
# further PATH setup (bash, fish and zsh all include it by default).
# ---------------------------------------------------------------------------
if [[ $BIN_LINK -eq 1 ]]; then
    if [[ -e "$BIN_DIR/frecency" || -L "$BIN_DIR/frecency" ]]; then
        if [[ "$(readlink "$BIN_DIR/frecency" 2>/dev/null || true)" == "$BIN_LINK_TARGET" ]]; then
            printf 'symlink already in place: %s -> %s\n' "$BIN_DIR/frecency" "$BIN_LINK_TARGET"
        else
            printf '%s/frecency already exists and is not ours; leaving it untouched.\n' "$BIN_DIR"
        fi
    else
        run mkdir -p "$BIN_DIR"
        run ln -s "$BIN_LINK_TARGET" "$BIN_DIR/frecency"
        printf 'Created %s/frecency -> %s\n' "$BIN_DIR" "$BIN_LINK_TARGET"
    fi
    if [[ ":${PATH}:" != *":${BIN_DIR}:"* ]]; then
        printf 'note: %s is not on PATH yet; add it to your shell profile.\n' "$BIN_DIR"
    fi
else
    printf 'Skipped %s symlink. Without it, shell integrations need %s on PATH.\n' "$BIN_DIR/frecency" "$VIFM_DIR/scripts"
fi

# ---------------------------------------------------------------------------
if [[ $DRY_RUN -eq 0 ]]; then
    printf '\nRunning self-check...\n'
    "$TARGET/frecency-test" || printf 'self-check reported issues (see above)\n'
fi

if [[ $BIN_LINK -eq 1 ]]; then
    BIN_SUMMARY="symlink      : $BIN_DIR/frecency"
else
    BIN_SUMMARY="symlink      : skipped (use --bin-link)"
fi
cat <<EOF

Done.

Installed:
  vifm scripts : $TARGET
  vifm plugin  : $VIFM_DIR/frecency.vifm
  fish (if any): $FISH_FILE
  bash         : $BASH_FILE
  nvim (if any): $NVIM_FILE
  $BIN_SUMMARY

Vifm keys (all defined in frecency.vifm):
  l / <cr>  open and record the file
  dd        delete and remove the record
  M         create a bookmark (keyword)
  o         jump from history (EMS + match grade)
  O         browse the current directory tree with fzf

See README.md for key conflicts, customization and configuration options
(SEARCH_MODE / GRADE_MODE / MULTIWORD_MODE ...).
EOF

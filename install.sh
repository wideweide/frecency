#!/bin/bash
# ============================================================================
# install.sh — frecency installer
# ============================================================================
# Installs:
#   frecency, frecency-test, frecency.vifm  -> ~/.config/vifm/scripts/
#   bundled/sqlite3-<arch>                  -> ~/.config/vifm/scripts/ (flattened)
# It never touches your vifmrc; the required snippets are printed at the end
# (also available in README.md).
#
# Usage:
#   ./install.sh                 install / update
#   ./install.sh --dry-run       show what would be done
#   ./install.sh --uninstall     remove installed files
#
# Requirements: bash 4.4+, sqlite3 >= 3.35 with exp() (bundled static binaries
# are used as fallback), fzf >= 0.48 for the interactive UI.
# ============================================================================
set -euo pipefail

TARGET="${HOME}/.config/vifm/scripts"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

FILES=(frecency frecency-test frecency.vifm bmark.sh)
BUNDLED=(bundled/sqlite3-x86_64 bundled/sqlite3-arm64)

DRY_RUN=0
UNINSTALL=0
for arg in "$@"; do
    case "$arg" in
        --dry-run)   DRY_RUN=1 ;;
        --uninstall) UNINSTALL=1 ;;
        -h|--help)
            sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)
            printf 'unknown option: %s (see --help)\n' "$arg" >&2; exit 2 ;;
    esac
done

run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        printf '[dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

installed=()
removed=()

if [[ $UNINSTALL -eq 1 ]]; then
    for f in "${FILES[@]}" "${BUNDLED[@]##*/}"; do
        if [[ -e "$TARGET/$f" ]]; then
            run rm -f "$TARGET/$f"
            removed+=("$f")
        fi
    done
    if [[ $DRY_RUN -eq 0 ]]; then
        printf 'Removed %d file(s) from %s\n' "${#removed[@]}" "$TARGET"
    fi
    printf 'Note: remove the frecency lines from your vifmrc manually.\n'
    exit 0
fi

[[ -x "$SRC_DIR/frecency" ]] || { printf 'frecency not found in %s\n' "$SRC_DIR" >&2; exit 1; }

run mkdir -p "$TARGET"
for f in "${FILES[@]}"; do
    run install -m 755 "$SRC_DIR/$f" "$TARGET/$f"
    installed+=("$f")
done
for f in "${BUNDLED[@]}"; do
    [[ -e "$SRC_DIR/$f" ]] || continue
    run install -m 755 "$SRC_DIR/$f" "$TARGET/${f##*/}"
    installed+=("${f##*/}")
done

if [[ $DRY_RUN -eq 0 ]]; then
    printf 'Installed %d file(s) into %s\n' "${#installed[@]}" "$TARGET"
    printf 'Running self-check...\n'
    "$TARGET/frecency-test" || printf 'self-check reported issues (see above)\n'
fi

# ---------------------------------------------------------------------------
cat <<'EOF'

Done. Now add the integration lines to your vifmrc (~/.config/vifm/vifmrc):

    " --- frecency: commands (silent, async, non-blocking) ---
    command! trackPath !frecency file add "%d" %a >/dev/null 2>&1 &
    command! trackFile
        \ ! [ ! -d "%d/%f" ] && frecency file add "%d/%f" %a >/dev/null 2>&1 &
    command! removeRecord
        \ !frecency file remove "%d/%f" >/dev/null 2>&1 &
    command! Bmark : execute '!bmark.sh %d/%f %a &'

    " record every directory you enter
    autocmd DirEnter *,.* trackPath

    " record on open / remove record on delete / bookmark with keyword
    nnoremap <silent> l    :trackFile<cr>l
    nnoremap <silent> <cr> :trackFile<cr><cr>
    nnoremap <silent> dd   :removeRecord<cr>dd
    nnoremap          M    :Bmark<space>

    " o = jump from history (EMS + match grade), O = browse current tree
    source ~/.config/vifm/scripts/frecency.vifm

See README.md for fish shell integration, the full key list and
configuration options (SEARCH_MODE / GRADE_MODE / MULTIWORD_MODE ...).
EOF

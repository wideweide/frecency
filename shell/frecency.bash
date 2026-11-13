# ============================================================================
# frecency.bash - Bash integration for frecency
# ============================================================================
# #frecency for bash
#
# Requires `frecency` on PATH: install.sh creates a ~/.local/bin symlink for
# this (--register / --bin-link).
# Loaded from ~/.bashrc:
#     source ~/.config/frecency/frecency.bash
#
# Provides:
#   o / j / J     unified history / directory history / file history
#   Alt-T         pick a path from history and insert it at the command line
#   PROMPT_COMMAND hook
#                 record every directory change in the `file` topic

# --- j / J: type-specific jumps ---
# Copy a path to the clipboard (wl-copy first, xclip fallback), the same
# behavior the jump handler and Alt-T use.
__frecency_copy_path() {
    if command -v wl-copy >/dev/null 2>&1; then
        printf '%s' "$1" | wl-copy
    elif command -v xclip >/dev/null 2>&1; then
        printf '%s' "$1" | xclip -selection clipboard
    fi
}

# Enter an existing file's parent and copy its absolute path: the same
# semantics as selecting a file history entry, for the cd-compat pre-branch.
__frecency_open_file() {
    local target=$1
    cd -- "$(dirname -- "$target")" || return 1
    target=$PWD/${target##*/}
    __frecency_copy_path "$target"
    printf 'Copied path: %s\n' "$target"
}

# cd-compat pre-branch: with a single argument, `-` and existing paths are
# honored before any history lookup (existing paths win over history
# matches), so `alias cd=j` behaves like cd for plain navigation. Multi-word
# arguments are always treated as history queries.
o() {
    if (( $# == 1 )); then
        if [[ -d "$1" ]]; then
            cd -- "$1"
            return
        fi
        if [[ -f "$1" ]]; then
            __frecency_open_file "$1"
            return
        fi
    fi
    local cmd
    cmd=$(frecency file jump-handler "$*") || return
    [[ -n "$cmd" ]] && eval "$cmd"
}

j() {
    if (( $# == 1 )); then
        if [[ "$1" == "-" ]]; then
            cd -
            return
        fi
        if [[ -d "$1" ]]; then
            cd -- "$1"
            return
        fi
    fi
    local cmd
    cmd=$(frecency file_dir jump-handler "$*") || return
    [[ -n "$cmd" ]] && eval "$cmd"
}

J() {
    if (( $# == 1 )) && [[ -f "$1" ]]; then
        __frecency_open_file "$1"
        return
    fi
    local cmd
    cmd=$(frecency file_file jump-handler "$*") || return
    [[ -n "$cmd" ]] && eval "$cmd"
}

# --- Pick a path from history into the command line (Alt-T) ---
# Same as the fish integration: insert at the cursor, copy to the clipboard
# (wl-copy first, xclip as fallback). Implemented with the readline
# READLINE_LINE/READLINE_POINT variables, the same mechanism fzf's official
# bash key bindings use. Overrides the default M-t (transpose-words).
__frecency_pick() {
    local selected
    selected=$(frecency file query) || return 0
    [[ -n "$selected" ]] || return 0
    READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}${selected}${READLINE_LINE:$READLINE_POINT}"
    READLINE_POINT=$((READLINE_POINT + ${#selected}))
    if command -v wl-copy >/dev/null 2>&1; then
        printf '%s' "$selected" | wl-copy
    elif command -v xclip >/dev/null 2>&1; then
        printf '%s' "$selected" | xclip -selection clipboard
    fi
}

# Bind only in an interactive shell, judged the way bash itself does: the
# `i' flag in $-. ([[ -o interactive ]] is not reliable in every
# environment, e.g. command feeds into a pty under bash 5.3.)
if [[ $- == *i* ]]; then
    bind -x '"\et":__frecency_pick'
fi

# --- Automatically record directory changes ---
# The event clock must tick on navigation, not on every prompt: fish tracks
# PWD changes through its variable hook, but bash has no equivalent, so
# compare $PWD against the last value seen at a prompt and record only real
# changes. Filtered directories still update the comparison value, so leaving
# one for a previously visited directory is still detected as a change.
__frecency_last_pwd=""
__frecency_pwd_handler() {
    local changed=0
    [[ "$PWD" != "$__frecency_last_pwd" ]] && changed=1
    __frecency_last_pwd=$PWD
    ((changed)) || return 0
    case "$PWD" in
        /tmp/*|/run/*|/sys/*|/proc/*) return 0 ;;
    esac
    # disown removes the job from the job table, so bash does not print a
    # "[1]+ Done" notification at the next prompt.
    nohup frecency file add --route unified,dir "$PWD" >/dev/null 2>&1 &
    disown
}

# Append after any existing PROMPT_COMMAND without replacing it.
case ";${PROMPT_COMMAND:-};" in
    *";__frecency_pwd_handler;"*) ;;
    *) PROMPT_COMMAND="__frecency_pwd_handler${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
esac

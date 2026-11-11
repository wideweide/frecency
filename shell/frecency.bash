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
o() {
    local cmd
    cmd=$(frecency file jump-handler "$*") || return
    [[ -n "$cmd" ]] && eval "$cmd"
}

j() {
    local cmd
    cmd=$(frecency file_dir jump-handler "$*") || return
    [[ -n "$cmd" ]] && eval "$cmd"
}

J() {
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
__frecency_pwd_handler() {
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

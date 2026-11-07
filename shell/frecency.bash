# ============================================================================
# frecency.bash - Bash integration for frecency
# ============================================================================
# #frecency for bash
#
# Requires frecency and bmark.sh on PATH (normally ~/.config/vifm/scripts).
# Loaded from ~/.bashrc:
#     source ~/.config/frecency/frecency.bash
#
# Provides:
#   j             z-like jump: directories cd, files open the parent directory
#   PROMPT_COMMAND hook
#                 record every directory change in the `file` topic

# --- j: z-like jump from frecency history ---
# A directory is cd'd into; a file copies its path to the clipboard and cd's to
# its parent (handled by the script's jump-handler branch).
j() {
    local cmd
    cmd=$(frecency file jump-handler "$*") || return
    [[ -n "$cmd" ]] && eval "$cmd"
}

# --- Automatically record directory changes ---
__frecency_pwd_handler() {
    case "$PWD" in
        /tmp/*|/run/*|/sys/*|/proc/*) return 0 ;;
    esac
    nohup frecency file add "$PWD" >/dev/null 2>&1 &
}

# Append after any existing PROMPT_COMMAND without replacing it.
case ";${PROMPT_COMMAND:-};" in
    *";__frecency_pwd_handler;"*) ;;
    *) PROMPT_COMMAND="__frecency_pwd_handler${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
esac

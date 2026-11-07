# ============================================================================
# frecency.fish - Fish integration for frecency
# ============================================================================
# #frecency for fish
#
# Requires frecency and bmark.sh on PATH (normally ~/.config/vifm/scripts).
# Loaded from config.fish:
#     source ~/.config/fish/frecency.fish
#
# Provides:
#   j             z-like jump: directories cd, files open the parent directory
#   Alt-T         pick a path from history and insert it at the command line
#   PWD hook      record every directory change in the `file` topic

# --- j: z-like jump from frecency history ---
# A directory is cd'd into; a file copies its path to the clipboard and cd's to
# its parent (handled by the script's jump-handler branch).
function j --description "z-like jump from frecency history"
    # "$argv" merges multiple words into one query (j foo bar -> "foo bar")
    set -l cmd (frecency file jump-handler "$argv")
    if test -n "$cmd"
        eval $cmd
    end
end

# --- Pick a path from history into the command line ---
# After selection the path is inserted at the cursor and copied to the clipboard
# (wl-copy first, xclip as fallback).
function __frecency_pick --description "Pick a path from frecency history into the command line"
    set -l selected (frecency file query)
    if test $status -eq 0 -a -n "$selected"
        commandline -i -- "$selected"
        if command -qv wl-copy
            printf '%s' "$selected" | wl-copy
        else if command -qv xclip
            printf '%s' "$selected" | xclip -selection clipboard
        end
        commandline -f repaint
    end
end

# --- Automatically record directory changes ---
# Keep directory paths in the same `file` database as visited files.
function __frecency_pwd_handler --on-variable PWD
    # Skip temporary and virtual directories
    if not string match -qr "^(/tmp/|/run/|/sys/|/proc/)" "$PWD"
        nohup frecency file add "$PWD" >/dev/null 2>&1 & disown
    end
end

if status is-interactive
    # Alt-T: frecency history path picker, complements fzf's Ctrl-T
    # (recursive search in the current directory)
    bind \et __frecency_pick
end

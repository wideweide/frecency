# ============================================================================
# frecency.fish - Fish integration for frecency
# ============================================================================
# #frecency for fish
#
# Requires `frecency` on PATH: install.sh creates a ~/.local/bin symlink for
# this (--register / --bin-link). vifm itself adds ~/.config/vifm/scripts to
# PATH automatically; bmark.sh is only ever called from vifm.
# Loaded from config.fish:
#     source ~/.config/fish/frecency.fish
#
# Provides:
#   o / j / J     unified history / directory history / file history
#   Alt-T         pick a path from history and insert it at the command line
#   PWD hook      record every directory change in the `file` topic

# --- j / J: type-specific jumps ---
function o --description "jump within unified frecency history"
    set -l cmd (frecency file jump-handler "$argv")
    if test -n "$cmd"
        eval $cmd
    end
end

function j --description "z-like jump from frecency history"
    set -l cmd (frecency file_dir jump-handler "$argv")
    if test -n "$cmd"
        eval $cmd
    end
end

function J --description "jump within file history"
    set -l cmd (frecency file_file jump-handler "$argv")
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
        nohup frecency file add --route unified,dir "$PWD" >/dev/null 2>&1 & disown
    end
end

if status is-interactive
    # Alt-T: frecency history path picker, complements fzf's Ctrl-T
    # (recursive search in the current directory)
    bind \et __frecency_pick
end

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
#   ji            interactive directory-history picker
#   jc / je       copy a selected file path / edit it with vim
#   Alt-T         pick a path from history and insert it at the command line
#   PWD hook      record every directory change in the `file` topic

# --- j / J: type-specific jumps ---
# Copy a path to the clipboard (wl-copy first, xclip fallback), used by Alt-T.
function __frecency_copy_path --description "copy a path to the clipboard"
    if command -qv wl-copy
        printf '%s' "$argv[1]" | wl-copy
    else if command -qv xclip
        printf '%s' "$argv[1]" | xclip -selection clipboard
    end
end

# Print an absolute path without changing directory or touching the clipboard.
function __frecency_emit_path --description "print an absolute path"
    set -l path $argv[1]
    if not string match -q '/*' -- "$path"
        set -l abs (readlink -f -- "$path" 2>/dev/null)
        test -n "$abs"; and set path $abs
    end
    printf '%s\n' "$path"
end

# cd-compat pre-branch: with a single argument, `-` and existing paths are
# honored before any history lookup (existing paths win over history
# matches), so `alias cd=j` behaves like cd for plain navigation. Multi-word
# arguments are always treated as history queries.
function o --description "jump within unified frecency history"
    if test (count $argv) -eq 1
        if test -d "$argv[1]"
            cd "$argv[1]"
            return
        end
        if test -f "$argv[1]"
            __frecency_emit_path "$argv[1]"
            return
        end
    end
    set -l sel (frecency file jump-handler --emit=path $argv)
    set -l rc $status
    test $rc -eq 0; or return $rc
    test -z "$sel"; and return 0
    if test -d "$sel"
        cd "$sel"
    else
        __frecency_emit_path "$sel"
    end
end

function j --description "z-like jump from frecency history"
    if test (count $argv) -eq 0
        cd "$HOME"
        return
    end
    if test (count $argv) -eq 1
        if test "$argv[1]" = "-"
            cd -
            return
        end
        if test -d "$argv[1]"
            cd "$argv[1]"
            return
        end
    end
    set -l cmd (frecency file_dir jump-handler $argv)
    set -l rc $status
    test $rc -eq 0; or return $rc
    # An fzf abort produces no output; return quietly instead of failing.
    test -z "$cmd"; and return 0
    eval $cmd
end

function ji --description "open the directory history picker"
    set -l cmd (frecency file_dir jump-handler --picker $argv)
    set -l rc $status
    test $rc -eq 0; or return $rc
    test -z "$cmd"; and return 0
    eval $cmd
end

function J --description "print a file path from frecency history"
    if test (count $argv) -eq 1; and test -f "$argv[1]"
        __frecency_emit_path "$argv[1]"
        return
    end
    set -l path (frecency file_file jump-handler --emit=path $argv)
    set -l rc $status
    test $rc -eq 0; or return $rc
    test -z "$path"; and return 0
    __frecency_emit_path "$path"
end

# Copy a selected file path to the clipboard (no trailing newline) or edit it
# with vim. Both reuse J, so they inherit its query/abort behavior and never
# change the working directory.
function jc --description "copy a selected file path to the clipboard"
    set -l f (J $argv)
    set -l rc $status
    test $rc -eq 0; or return $rc
    test -n "$f"; or return 0
    printf '%s' "$f" | wl-copy
end

function je --description "edit a selected file path with vim"
    set -l f (J $argv)
    set -l rc $status
    test $rc -eq 0; or return $rc
    test -n "$f"; or return 0
    vim -- "$f"
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

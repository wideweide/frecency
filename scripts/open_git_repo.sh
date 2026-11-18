#!/bin/bash
# open_git_repo.sh - open the git repository containing PATH in a TUI.
#
# Usage: open_git_repo.sh PATH [STATUS_FILE]
#
# STATUS_FILE is optional. When supplied, "ok" is written immediately before
# the TUI starts and "fail" for an unavailable repository/tool. The fzf caller
# uses it to decide whether to abort the picker after the TUI exits.
#
# Inside tmux the tool opens in a new window, mirroring the picker's `e`
# action; outside tmux it runs in the current terminal. Either way fzf aborts
# once the tool has been launched (new window) or has exited (current
# terminal).
set -u

path="${1:-}"
status_file="${2:-}"

write_status() {
    [[ -n "$status_file" ]] && printf '%s\n' "$1" > "$status_file"
}

if [[ -z "$path" ]]; then
    printf 'open_git_repo: no path selected\n' >&2
    write_status fail
    exit 2
fi

if ! command -v git >/dev/null 2>&1; then
    printf 'open_git_repo: git is not installed\n' >&2
    write_status fail
    exit 1
fi

# A file belongs to the repository of its parent; an existing directory is
# checked directly so a nested directory inside the repository also works.
# A missing entry falls back to its parent, matching the picker's history.
candidate="$path"
if [[ -f "$path" ]]; then
    candidate=$(dirname -- "$path")
elif [[ ! -d "$path" ]]; then
    candidate=$(dirname -- "$path")
fi

if ! repo=$(git -C "$candidate" rev-parse --show-toplevel 2>/dev/null); then
    printf 'open_git_repo: not inside a git repository: %s\n' "$path" >&2
    write_status fail
    exit 1
fi

# Priority is intentional: the first installed tool wins.
tool=""
for candidate_tool in gitui ziggity lazygit; do
    if command -v "$candidate_tool" >/dev/null 2>&1; then
        tool="$candidate_tool"
        break
    fi
done
if [[ -z "$tool" ]]; then
    printf 'open_git_repo: no supported git tool found (tried gitui, ziggity, lazygit)\n' >&2
    write_status fail
    exit 1
fi

write_status ok
if [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1; then
    tmux new-window "cd $(printf '%q' "$repo") && exec $(printf '%q' "$tool")" \
        >/dev/null 2>&1 || { write_status fail; exit 1; }
    exit 0
fi
cd -- "$repo" || { write_status fail; exit 1; }
exec "$tool"

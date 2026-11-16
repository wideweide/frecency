# Tasks

Status legend: `[ ]` pending, `[~]` in progress, `[x]` done, `[!]` blocked.

The first `[ ]`/`[~]` item is the default next task. Put task-specific
acceptance under the task; project-wide gates live in
[`ACCEPTANCE.md`](ACCEPTANCE.md). Completed work belongs in
[`STATE.md`](STATE.md) under "Recent changes" instead of a duplicate log here.

## Active

_None._

## Backlog

- [ ] Manual host integration checks for Bash, fish, vifm, and Neovim.
  - Context: `REGRESSION.md` lists host event behavior as not covered by
    automated end-to-end tests.
  - Acceptance: one recorded pass of each host's record/jump path using a
    disposable `HOME`, with results added to `STATE.md`.
  - Verification: follow the host sections in `REGRESSION.md`; never run
    migration experiments against a real user database.

- [ ] Manual interactive checks for `ji` and NORMAL-mode `c`/`v`/`e` actions.
  - Context: the picker and key bindings need a terminal and the supported fzf
    version; the automated run only verified flag parsing, bind syntax, and
    pty-driven key presses on one machine.
  - Acceptance: `ji` opens with an optional initial query; `c` copies the path
    and keeps fzf open with a `copied <path>` footer; `v` previews in the popup
    and returns to fzf with the query and scroll position intact (files and
    directories); `e` edits and exits fzf without emitting a path (new tmux
    window inside tmux, current terminal otherwise); `C`/`V`/`E` are unbound;
    `Enter` remains the only navigation exit. The viewer uses `view` first
    (syntax highlighting), degrading through `FRECENCY_VIEWER`/`PAGER`/`less`/
    `cat`.
  - Verification: open `file` and `file_file` pickers in NORMAL mode, then
    repeat in SEARCH mode to confirm those keys only filter there. See the
    "fzf action keys" section in `REGRESSION.md`.

## Task template

- [ ] `<task-id>` — `<one-line outcome>`
  - Context:
  - Scope:
  - Acceptance:
  - Verification:

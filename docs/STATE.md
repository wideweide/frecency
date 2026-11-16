# Project state

Last updated: 2026-11-16
Purpose: handoff snapshot for coding agents. Read this after `AGENTS.md`.

## Status at a glance

- Branch: `main`; last code commit `08f4778` (2026-11-16), pushed to
  `origin/main`. The untracked `2026-11-16/` review notes are intentionally not
  committed. DLT `docs/frecency.md` synced in `9be0ed7`.
- Active task: none.
- Last code change: added Bash/fish `jc`/`je` helpers and NORMAL-mode fzf
  `c`/`v`/`e` (exit, no navigation) plus `C`/`V`/`E` (stay, tmux window when
  available); removed the obsolete `C` cleanup binding.
- Next action: no queued task; see [`TASKS.md`](TASKS.md) for remaining manual
  host and interactive checks. Local runtime was refreshed with
  `install.sh --register` and installed files match the source. DLT
  `docs/frecency.md` was updated to match the current behavior.
- Blockers: none.

## What was verified

This is a snapshot, not a guarantee. Re-run the checks relevant to the next
change; record the actual commands and results here.

| Area | Check | Result |
|---|---|---|
| Syntax | `bash -n` on `scripts/frecency`, `scripts/frecency-test`, `scripts/bmark.sh`, `shell/frecency.bash`, `install.sh` | pass |
| Syntax | `fish -n shell/frecency.fish` | pass |
| Whitespace | `git diff --check` | pass |
| Capacity | disposable `HOME`, 1600 seeded rows: add reduced unbookmarked rows to 1351, protected the new entry, retained high scores | pass |
| Capacity | per-table `MAX_ENTRIES_UNIFIED=100`, `MAX_ENTRIES_DIR=200`, `MAX_ENTRIES_FILE=300`: counts became `91|181|271`; bookmark retained | pass |
| Capacity | `frecency file_dir cleanup` read `MAX_ENTRIES_DIR=10` from `file.config`; 50 rows became 9 | pass |
| Capacity | `MAX_ENTRIES=0` disabled pruning; a legacy wall-clock age setting no longer deleted old `last_access` rows | pass |
| Bash jumps | bare `j` → `$HOME`; existing directory wins over history; `j -`; `J`/`o` print paths without changing `$PWD`; `o` enters directories | pass |
| Fish jumps | same checks via `fish --no-config` | pass |
| CLI | `--emit=path` prints one path; vifm flavour prints `goto '...'`; no-match exits 1 with stderr | pass |
| Picker flag | `jump-handler --picker no-such` with a stub fzf exits 0, confirming the argument is an initial query | pass |
| fzf keys | `c`/`v`/`e` bind expressions parsed by fzf 0.72 in filter mode | pass |
| fzf keys | `frecency file fzf-action copy/edit/view/edit-stay` with stub `wl-copy`/`EDITOR`/`PAGER` and a path with spaces (copy verified byte-for-byte, no trailing newline) | pass |
| fzf keys | pty: `c` copies the path, fzf stays open, footer shows `copied <path>` including verbatim special characters (`)`, `,`, `+`, backslash); `q` then exits with no path emitted | pass (one machine, non-tmux) |
| fzf keys | pty: `v` shows program content then fzf resumes with query/list/scroll intact; `e` shows content then aborts with empty output and unchanged `$PWD` | pass (one machine, non-tmux) |
| fzf keys | viewer chain: `view` preferred (stub), `FRECENCY_VIEWER='less -R'` override honored; directory opens in netrw via `view` | pass |
| fzf keys | tmux 3.x `new-window` from `edit-stay` inherits `EDITOR`/`FRECENCY_VIEWER` and creates a new window | pass |
| Shell helpers | `jc`/`je` in Bash and fish with stub `wl-copy`/`vim`: path copied without newline, `vim -- <path>` called, `$PWD` unchanged | pass |
| Self-check | `HOME=<disposable> scripts/frecency-test` | pass; bundled 3.46.1 and system 3.45.1 |
| Installer | `./install.sh --dry-run --register`, `./install.sh --dry-run --uninstall` | pass |
| Interactive UI | `ji` picker keypresses on the maintainer's own terminal | not run (needs a terminal) |

## Recent changes

- 2026-11-16: added Bash/fish `jc` (copy selected file path via `wl-copy`,
  no trailing newline) and `je` (edit with `vim -- <path>`); `j`/`ji`/`J` now
  return 0 on an empty fzf result so aborts stay silent.
- 2026-11-16: fzf NORMAL-mode keys simplified to `c`/`v`/`e` only (uppercase
  `C`/`V`/`E` unbound). `c` copies the path and stays, with a `copied <path>`
  footer generated via a `transform` helper (fzf does not expand `{}` in
  `change-footer`); the path is shown verbatim, including special characters.
  `v` runs the viewer under `execute` and restores the picker untouched on exit
  (files and directories via `view`/netrw) for walk-through browsing. `e` runs
  the editor and aborts without emitting a path (new tmux window inside tmux,
  current terminal otherwise). The viewer prefers `view` (syntax highlighting),
  degrading through `FRECENCY_VIEWER`/`PAGER`/`less -R`/`cat`. Capacity cleanup
  is automatic; `Enter` is the only navigation exit and `x` clears the query.
- 2026-11-16: capacity cleanup now runs after each write, using
  `MAX_ENTRIES=1500` with per-table `MAX_ENTRIES_UNIFIED`/`_DIR`/`_FILE`
  overrides in `file.config`; pruning keeps 90% of the limit and protects the
  entry just written. Wall-clock age cleanup was removed.
- 2026-11-16: bare `j` goes to `$HOME`, `ji` opens the directory picker with an
  optional initial query, and `--emit=path` makes non-vifm file selection print
  only the path. Bash and fish integrations were kept symmetric.
- 2026-11-16: fzf NORMAL mode first added `v` (pager, `$PAGER` then `less -R`)
  and `e` (`$EDITOR`, fallback `vi`) binds; superseded later the same day by
  the `view`-first / `execute` behavior recorded above.
- 2026-11-16: README, `docs/REGRESSION.md`, and `docs/TASKS.md` were updated.
- 2026-11-13: `052821f` Bash records directory history only when `$PWD`
  changes; `45410a9` adds cd-style `j`/`J`/`o` paths and missing-match errors;
  `10bf355` sets unified `file` decay to `0.005` with per-table defaults.
- 2026-11-11: `193250d` added routed directory/file history with unified and
  typed tables in `file.db`.

## Handoff checklist

1. Read `AGENTS.md`, this file, and [`TASKS.md`](TASKS.md).
2. Run `git status -sb` and `git log --oneline -5`; reconcile this file if the
   branch, working tree, or commits disagree with it.
3. Pick the first pending task in `TASKS.md`, or confirm the scope with the
   user before starting.
4. Run the relevant gates in [`ACCEPTANCE.md`](ACCEPTANCE.md) and
   [`REGRESSION.md`](REGRESSION.md).
5. Update this file and `TASKS.md` at the end of the task, then commit code,
   docs, and state together.
6. Keep private decisions, local paths, and machine-specific commands in
   `.harness-local/WORKFLOW.md`.

## Known gaps

- Bash, fish, vifm, and Neovim host event behavior is not covered by automated
  end-to-end tests; see the "Not covered" section of `REGRESSION.md`.
- `ji` and the NORMAL-mode `c`/`v`/`e` actions (and uppercase variants) still
  need an interactive pass on the maintainer's own terminal/tmux setup; the
  recorded pty checks were run on one machine only.
- There is no supported CLI command to reset or list all entries for a topic.

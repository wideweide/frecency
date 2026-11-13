# Project state

Last updated: 2026-11-13
Purpose: handoff snapshot for coding agents. Read this after `AGENTS.md`.

## Status at a glance

- Branch: `main`; last code commit `10bf355` (2026-11-13). Use `git status`
  and `git log` for the authoritative current state.
- Active task: none.
- Last code change: 2026-11-13 behavior convergence — cd-style `j`/`J`/`o`
  pre-branches, missing-match errors, Bash prompt change detection, and the
  unified `file` decay constant.
- Handoff docs: 2026-11-13 added tracked `STATE.md`, `TASKS.md`, and
  `ACCEPTANCE.md`; `AGENTS.md` now defines the read order.
- Next action: none queued; see [`TASKS.md`](TASKS.md).
- Blockers: none.

## What was verified

This is a snapshot, not a guarantee. Re-run the checks relevant to the next
change; record the actual commands and results here.

| Area | Check | Result |
|---|---|---|
| Syntax | `bash -n` on `scripts/frecency`, `scripts/frecency-test`, `scripts/bmark.sh`, `shell/frecency.bash`, `install.sh` | pass |
| Syntax | `fish -n shell/frecency.fish` | pass |
| Whitespace | `git diff --check` | pass |
| Bash hook | first prompt records once; repeat prompt does not record; directory change records; `/tmp` subdirectory skipped; returning from it records | pass |
| Bash jumps | `j -`, existing directory, `J`/`o` existing file, multi-word query, no-match non-zero exit | pass |
| Fish jumps | same pre-branches and no-match status propagation | pass |
| CLI | `file`/`file_dir`/`file_file` no-match exits 1 with stderr; vifm variant exits 0 silently | pass |
| Scoring | unified `file` `LAMBDA=0.005`, split tables `0.01`, config override, typed topics | pass |
| Installer | `--dry-run --register`, `--dry-run --uninstall`; disposable-`HOME` `--register` install, self-check, and `file` database init | pass |

## Recent changes

- 2026-11-13: added tracked agent handoff docs (`STATE.md`, `TASKS.md`,
  `ACCEPTANCE.md`) and updated `AGENTS.md` with the read order and update
  protocol.
- 2026-11-13: `052821f` Bash records directory history only when `$PWD`
  changes; `45410a9` adds cd-style `j`/`J`/`o` paths and missing-match errors;
  `10bf355` sets unified `file` decay to `0.005` with per-table defaults.
  `README.md` and downstream documentation were updated.
- 2026-11-11: `193250d` added routed directory/file history with unified and
  typed tables in `file.db`.
- 2026-11-09: `f77aaae` added the quickstart and regression checklist.

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
- There is no supported CLI command to reset or list all entries for a topic.

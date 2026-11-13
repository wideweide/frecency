# Repository guide for coding agents

## Project

`frecency` is a Bash and SQLite navigation-history manager with an fzf UI. It tracks entries per topic and provides vifm, fish, bash, and Neovim integrations. Keep the standalone project self-contained; user and machine specific workflows belong in `.harness-local/` and must not be committed.

## Start here (session handoff)

Different models and tools may resume this repository. Read in this order:

1. `AGENTS.md` (this file) — project rules and constraints.
2. `docs/STATE.md` — current status, what was actually verified, and the next step.
3. `docs/TASKS.md` — queued work and task-specific acceptance criteria.
4. `docs/ACCEPTANCE.md` and `docs/REGRESSION.md` — done criteria and area checks.
5. `.harness-local/WORKFLOW.md` when present — private workstation workflow; never commit it.

`docs/STATE.md` is the single source of truth for progress. At the end of every
substantive task, update it with the status, files or commits, checks actually
run, blockers, and next action. Keep queued work in `docs/TASKS.md`; do not
duplicate the same status in both files. If a state file disagrees with the
code or `git status`, treat the code as authoritative and reconcile the file.

## Common commands

Run only the checks relevant to the change; `docs/ACCEPTANCE.md` defines the
full gates. Use a disposable `HOME` for database and CLI probes.

```bash
bash -n scripts/frecency scripts/frecency-test scripts/bmark.sh shell/frecency.bash install.sh
fish -n shell/frecency.fish
scripts/frecency-test                 # SQLite/fzf dependency self-check (writes the sqlite cache)
./install.sh --dry-run --register     # preview install and registration
./install.sh --register               # refresh the local runtime only when requested
git diff --check
```

## Source map

- `scripts/frecency`: CLI, database schema/migrations, scoring, querying, preview and fzf UI.
- `scripts/frecency-test`: SQLite capability checks and local binary selection.
- `scripts/bmark.sh`: vifm bookmark helper.
- `install.sh`: installation, registration, dry-run, and uninstall behavior.
- `frecency.vifm`, `shell/`, `nvim/`: integrations.
- `bundled/`: static SQLite fallback binaries; preserve executable bits.
- `README.md`: user-facing overview and supported commands/configuration.
- `docs/STATE.md`, `docs/TASKS.md`: agent handoff state and queued work.
- `docs/ACCEPTANCE.md`, `docs/REGRESSION.md`: quality gates and manual checks.

## Change conventions

- Read the affected implementation and its related documentation before editing.
- Preserve compatibility across the supported Bash, SQLite, fzf, vifm, fish, and Neovim interfaces. Avoid changing key mappings, CLI output, schema, or install paths without updating their callers and documentation.
- Database changes must be migration-safe and idempotent. Do not assume a user's database can be discarded.
- Keep machine-specific paths, credentials, remote URLs, and deployment procedures out of tracked files. Do not add private instructions to `README.md`, this file, or the tracked state/task files.
- When behavior, options, defaults, dependencies, installation, or integration details change, update `README.md` in the same change.
- Make focused changes and preserve the existing shell style and quoting discipline.
- Update `docs/STATE.md` and `docs/TASKS.md` as part of task completion; keep them concise and current.

## Verification

For a shell script change, run `bash -n` on each affected Bash script. For installer or CLI behavior, use its existing dry-run or self-check modes where suitable. For documentation-only changes, check links and command examples against the current implementation. Record the exact checks and results in `docs/STATE.md`; do not claim broader validation than performed.

## Local harness configuration

Read `.harness-local/WORKFLOW.md` when it exists. It contains private workstation workflow instructions and the decision log, and is intentionally ignored by Git. Keep its details local; tracked handoff state stays in `docs/STATE.md` and must not copy private workflow details.

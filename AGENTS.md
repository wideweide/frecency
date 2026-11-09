# Repository guide for coding agents

## Project

`frecency` is a Bash and SQLite navigation-history manager with an fzf UI. It tracks entries per topic and provides vifm, fish, bash, and Neovim integrations. Keep the standalone project self-contained; user and machine specific workflows belong in `.harness-local/` and must not be committed.

## Source map

- `scripts/frecency`: CLI, database schema/migrations, scoring, querying, preview and fzf UI.
- `scripts/frecency-test`: SQLite capability checks and local binary selection.
- `scripts/bmark.sh`: vifm bookmark helper.
- `install.sh`: installation, registration, dry-run, and uninstall behavior.
- `frecency.vifm`, `shell/`, `nvim/`: integrations.
- `bundled/`: static SQLite fallback binaries; preserve executable bits.
- `README.md`: user-facing overview and supported commands/configuration.

## Change conventions

- Read the affected implementation and its related documentation before editing.
- Preserve compatibility across the supported Bash, SQLite, fzf, vifm, fish, and Neovim interfaces. Avoid changing key mappings, CLI output, schema, or install paths without updating their callers and documentation.
- Database changes must be migration-safe and idempotent. Do not assume a user's database can be discarded.
- Keep machine-specific paths, credentials, personal remotes, and deployment procedures out of tracked files. Do not add private instructions to `README.md` or this file.
- When behavior, options, defaults, dependencies, installation, or integration details change, update `README.md` in the same change.
- Make focused changes and preserve the existing shell style and quoting discipline.

## Verification

For a shell script change, run `bash -n` on each affected Bash script. For installer or CLI behavior, use its existing dry-run or self-check modes where suitable. For documentation-only changes, check links and command examples against the current implementation. Report what was actually checked; do not claim broader validation than performed.

## Local harness configuration

Read `.harness-local/WORKFLOW.md` when it exists. It contains private workstation workflow instructions and is intentionally ignored by Git. Keep its details local.

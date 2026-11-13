# Acceptance and quality gates

This file defines what "done" means for this repository. Task-specific
acceptance criteria belong in [`TASKS.md`](TASKS.md); the detailed manual
checklist is [`REGRESSION.md`](REGRESSION.md).

## Every change

- [ ] The change is focused; unrelated edits, generated files, and private
      paths are excluded.
- [ ] Behavior, options, defaults, dependencies, installation, or integration
      details changed: update `README.md` in the same change.
- [ ] Shell changes: run `bash -n` on every affected Bash script and
      `fish -n` on the fish integration.
- [ ] CLI or installer changes: use the existing `--dry-run`, self-check, or a
      disposable-`HOME` probe. Do not test migrations on a real database.
- [ ] Run the relevant sections of `REGRESSION.md`, or report exactly which
      checks were not run and why.
- [ ] Database changes are migration-safe and idempotent.
- [ ] No machine-specific paths, credentials, or private workflow details are
      added to tracked files.
- [ ] `STATE.md` records status, actual verification, blockers, and the next
      step; `TASKS.md` reflects queued and completed work.
- [ ] `git diff --check` passes and each commit contains only intended changes.

## Area gates

| Area | Minimum verification |
|---|---|
| Shell integration (`shell/`) | `bash -n` / `fish -n`; disposable-`HOME` probes for changed functions; `install.sh --dry-run --register` |
| CLI, routing, scoring (`scripts/frecency`) | disposable-`HOME` probe; exact SQL/score checks for scoring; no-match and route behavior; `bash -n` |
| Installer (`install.sh`) | `--dry-run --register` and `--dry-run --uninstall`; run the real install only when requested, then verify installed files match the source |
| Documentation only | Check links and examples against the current implementation; `git diff --check` |
| Schema or migration | Initialize twice on a disposable `HOME`; use the old-schema fixtures in `REGRESSION.md` |

If a gate cannot be run, record the reason in `STATE.md`; do not claim it
passed.

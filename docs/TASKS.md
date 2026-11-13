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

## Task template

- [ ] `<task-id>` — `<one-line outcome>`
  - Context:
  - Scope:
  - Acceptance:
  - Verification:

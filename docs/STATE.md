# Project state

Last updated: 2026-11-18
Purpose: handoff snapshot for coding agents. Read this after `AGENTS.md`.

## Status at a glance

- Branch: `main`; last code commit `9262ab3` (2026-11-18). Use `git status`
  and `git log` for the authoritative current state.
- Active task: none.
- Last code change: fzf footer is now mode-aware and no longer overwritten by
  the startup transform. SEARCH shows only `Esc Normal  ? Help`; NORMAL shows
  the full action list on two lines (the right preview narrows the footer
  pane); multi-word SEARCH keeps `ORDERED/ANY ORDER · NORMAL s→…`; multi-word
  NORMAL adds the order line above the two NORMAL lines. `?` opens the full key
  map in a pager (`PAGER`, preferring `less -R` when `PAGER=cat`).
- Previous change: pre-commit review of the pending audit-remediation + H6/H7
  changeset found and fixed two bugs: (1) `_dec()` used `printf '%d' "10#N"`,
  which strtol-parses only up to `#` and returns 10 with stderr noise — every
  cleanup/auto-prune computed keep=1 and wiped tables with >10 entries to a
  single row (empirically 50 rows -> 1); now uses `$(( 10#... ))` arithmetic.
  (2) `do_jump_handler` still had 3 unquoted `$SELF` calls, so `j`/`ji`/`J`/`o`
  broke (rc 127) under a space-containing install path; now `"$SELF"`.
- Next action: none queued; see [`TASKS.md`](TASKS.md) for the remaining
  manual host and interactive checks.
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
| fzf keys | stub fzf: fzf 0.72 emits `--tmux 90%,80%,border-native` without `--border=rounded`; fzf 0.48 falls back to `--tmux 90%,80%` plus `--border=rounded` | pass |
| fzf keys | stub tmux: entering the UI sets `popup-border-lines rounded`; the RETURN trap restores the saved `single` value | pass |
| fzf footer | mock fzf: initial `--footer` is `Esc Normal  ? Help` in SEARCH, the two-line full list in NORMAL, `ORDERED/ANY ORDER · NORMAL s→…` for multi-word SEARCH, and order-line + two-line list for multi-word NORMAL | pass |
| fzf footer | generated footer handler with NORMAL/SEARCH, ordered/any-order, and 0/2-word query combinations | pass |
| fzf footer | real tmux 120x40, fzf 0.72: default SEARCH footer, Esc -> NORMAL two-line footer, `/` -> SEARCH footer, `s` switches `ORDERED`/`ANY ORDER` and refreshes the footer, multi-word SEARCH/NORMAL initial footers | pass |
| fzf help | real tmux: `?` in both modes opens the full key map in `less` even with `PAGER=cat`; `q` returns to the picker | pass |
| fzf keys | real tmux popup render: rounded border stays visible while `v` viewer owns the popup | pass (confirmed by the maintainer on their terminal) |
| fzf keys | tmux 3.x `new-window` from `edit-stay` inherits `EDITOR`/`FRECENCY_VIEWER` and creates a new window | pass |
| Shell helpers | `jc`/`je` in Bash and fish with stub `wl-copy`/`vim`: path copied without newline, `vim -- <path>` called, `$PWD` unchanged | pass |
| Self-check | `HOME=<disposable> scripts/frecency-test` | pass; bundled 3.46.1 and system 3.45.1 |
| vifm quoting | stub `SHELL` + argv-logging `frecency` on a path with spaces: old `"%d/%f"` produced `zz\ xy\ test.log`, fixed `%d/%f` produced `zz xy test.log` (source and installed copy) | pass |
| Installer | `./install.sh --dry-run --register` then `./install.sh --register` | pass; installed copy identical to source, self-check ok |
| Installer | `./install.sh --dry-run --register`, `./install.sh --dry-run --uninstall` | pass |
| Interactive UI | `ji` picker keypresses on the maintainer's own terminal | not run (needs a terminal) |
| Audit A-E | `bash -n scripts/frecency scripts/frecency-test scripts/bmark.sh shell/frecency.bash install.sh && fish -n shell/frecency.fish && git diff --check` | pass |
| Audit A-E | `HOME=<tmp> bash scripts/frecency-test -n -q` (SQLite/MATH/fzf self-check) | pass |
| Audit A-E | `XDG_DATA_HOME=<tmp> HOME=<tmp2> scripts/frecency file init` twice -> `<tmp>/frecency` exists; `MAX_ENTRIES=08` add/cleanup has no octal error; newline path rejected with rc 2 | pass |
| Audit A-E | `HOME=<tmp> ./install.sh --dry-run --register` (full preview incl. manifest); `--dry-run --uninstall` safe on fresh HOME; `--uninstall --unregister` exits 2 with clear message | pass |
| H6/H7 | stub fzf with `frecency` installed under a space-containing dir: all 9 binds receive `tools\ my/frecency` (escaped), 0 bare occurrences; `sh -c` resolves it to a single argv | pass |
| Review | `bash -n` (5 scripts) + `fish -n` + `git diff --check` | pass |
| Review | disposable HOME: add/jump-handler/recent/cleanup CLI probes; newline+SEP paths rejected rc 2; `MAX_ENTRIES=08` silently falls back to the 1500 default by design | pass |
| Review | capacity after `_dec` fix: 50 rows + default limit -> cleanup keeps 50; `MAX_ENTRIES=8` add -> 8 rows (keep 7 + protected new); unified seed auto-pruned to 1350 mid-seed then 1450, new entry protected | pass |
| Review | space-path script: `jump-handler --emit=path <term>`, no-term and `--picker` variants under `sp ace dir` all rc 0 (were rc 127 before the quoting fix) | pass |
| Review | installer: `--dry-run --register` full preview, manifest not written on dry-run; fresh-HOME `--dry-run --uninstall` rc 0; `--uninstall --unregister` rc 2; `--dry-run --no-register` preview has 0 register actions | pass |
| Review | installer round-trip in disposable HOME: `--register` writes the 8-key manifest, `--uninstall` removes 7 files + registrations + manifest, no leftovers in the vifm scripts dir | pass |

## Recent changes

- 2026-11-18: fixed the fzf footer mode handling. The startup transform no longer
  overwrites the initial mode-specific footer; the footer handler now reads the
  NORMAL/SEARCH state file separately from the ordered/any-order file. SEARCH
  shows `Esc Normal  ? Help`, NORMAL shows the full action list on two lines
  (the right preview limits footer width), and multi-word hints follow the
  actual mode. `?` opens the full key map in a pager, preferring `less -R` when
  `PAGER=cat`. `README.md` updated. (The `--border=none` tmux popup fix is also
  in this uncommitted changeset.)
- 2026-11-17: pre-commit review of the pending changeset fixed two bugs found
  during re-verification. (1) `_dec()` (audit batch A) used `printf '%d'
  "10#N"`; bash printf parses numeric args with strtol, so it stopped at `#`
  and returned 10 with stderr noise. keep then evaluated to 10*10/100=1: every
  `cleanup` and every automatic prune on a table with more than 10 entries
  wiped it to one row (verified 50 rows -> 1 before the fix). `_dec` now uses
  `$(( 10#${1:-0} ))` arithmetic. Capacity re-verified: default limit keeps 50
  rows; `MAX_ENTRIES=8` prunes to keep 7 + protected new entry; a 1600-row
  seed auto-pruned to 1350 mid-seed and ended at 1450 with the new entry kept.
  (2) `do_jump_handler` had 3 unquoted `$SELF` calls left (query picker,
  internal-query best-match, empty-term query), so the shell `j`/`ji`/`J`/`o`
  helpers failed under a space-containing install path despite the H6/H7 fix;
  all three now use `"$SELF"`, verified end-to-end from `sp ace dir/frecency`.
  A leading-zero `MAX_ENTRIES=08` is rejected by `_is_uint` and falls back to
  the default (designed octal guard, not an error).
- 2026-11-17: H6/H7 follow-up (code-verified, not assumed fixed). H7: `$SELF`
  was still bare in 9 fzf binds plus background cleanup and the query pipeline,
  so a space-containing install path broke every fzf action; all shell-bound
  sites now use a `printf '%q'`-quoted `$SELF`, direct calls use `"$SELF"`.
  H6: `bmark.sh:25` still passed the path/tag unquoted to `vifm --remote -c`;
  both operands are now `printf '%q'`-quoted (vifm cmdline accepts backslash
  escapes, matching the `bmark! path tag` documented form). Verified by
  capturing fzf argv under a space-containing path and by `sh -c` argv parsing.
- 2026-11-17: audit remediation (batches A-E) applied and verified.
  - A: `XDG_DATA_HOME` honored for the data dir (default path unchanged);
    `_is_uint`/`_dec` make capacity config octal-safe; init lock keyed by DB
    file (shared `file.db` topics serialize together); paths containing newline
    or SEP rejected at write time; `frecency-test` never deletes a bundled
    binary inside the source tree; `jc` reuses the xclip-capable copy helper.
  - B: docs/harness aligned — stale uppercase key hints removed, README/STATE
    key and border descriptions corrected, TASKS/ACCEPTANCE scopes unified,
    private details removed from tracked STATE.
  - C: IFS protected across config source; numeric config validated; delete
    failure restores table variables; preview commands pass `--` for dash-led
    paths; Bash helpers forward `"$@"`; README `o` description matches code.
  - D/E: `frecency-test` locale fallback/stale-cache cleanup/-a glob/dead code;
    installer strict prompts, mutual-exclusion check, standalone `--dry-run`,
    preflight, absolute `--vifm-dir` and an install manifest for reversible
    uninstall; nvim `//` fix; `_apply_highlight` hoisted.
  - Not applied: M12 (undo EMS fidelity needs a schema migration — deferred to
    avoid a data-risk change), deep E3 refactors (sql_like templates / grade
    CASE / version probe / jump-handler) as low benefit vs regression risk,
    and E1 full config sandboxing (IFS + numeric validation applied instead).
- 2026-11-17: fixed the vifm space-path bug. `trackPath`, `trackFile` and
  `removeRecord` now pass `%d`/`%d/%f` unquoted: vifm already escapes macros
  for `:!` commands, and the extra double quotes kept `\ ` literal, writing
  paths such as `/path/zz\ test.log` to the DB. Verified by capturing the
  expanded shell command and the exact `frecency` argv with a stub; DLT
  `docs/frecency.md` updated and the local runtime refreshed.
- 2026-11-17: fzf `v` preview keeps a rounded border in tmux popups. For fzf
  >= 0.58 the picker uses `--tmux 90%,80%,border-native`, temporarily sets
  `popup-border-lines rounded` for a fzf-like look, and restores the previous
  value on exit, so the border drawn by tmux stays while `view`/pager owns the
  popup. fzf < 0.58 keeps the prior self-drawn `--border=rounded`; non-tmux is
  unchanged. `README.md` updated.
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
- `ji` and the NORMAL-mode `c`/`v`/`e` actions still need an interactive pass on
  the maintainer's own terminal/tmux setup; the recorded pty checks were run on
  one machine only. (`C`/`V`/`E` are unbound and need no testing.)
- There is no supported CLI command to reset or list all entries for a topic.

# Project state

Last updated: 2026-11-20
Purpose: handoff snapshot for coding agents. Read this after `AGENTS.md`.

## Status at a glance

- Branch: `main`. Use `git status -sb` and `git log --oneline -5` for the
  authoritative commit and working-tree state; no commit hash is recorded here.
- Active task: none.
- Last code change: added a configurable picker query cap. `QUERY_LIMIT`
  defaults to 32: `_do_internal_query` still ranks all matches in SQL but
  formats and returns only the top N, appending `TOTAL n` to its own result.
  The UI strips that line before fzf and, with fzf >= 0.54, uses `--info-command`
  to render the native info line as `< 1/n ────` in both SEARCH and NORMAL,
  restoring the original prompt/info/separator style. A single combined transform
  updates footer and prompt, which keeps `Esc` switching back to NORMAL.
  `QUERY_LIMIT=0` keeps the old unlimited behavior. The manual
  bench compares unlimited vs capped broad queries: at 16000 rows a broad query
  dropped from ~271 ms to ~72 ms, at 1000 rows from ~44 ms to ~31 ms. A new CLI
  case checks the trailing TOTAL line and row counts; 28 cases pass.
- Previous code change: P2 follow-ups. Added `scripts/bench.sh`, a manual
  disposable-`HOME` baseline (not installed, not in CI) that seeds
  110/1000/16000 rows and reports `add`, typed `jump-handler`, full-list reload
  and query-limit timings. Reduced `SLEEP_DELAY` from 0.06 to 0.02 after a pty
  test confirmed fzf cancels superseded reloads; real-fzf measurements at
  1500/3000/5000 rows showed per-keystroke latency dropping from
  ~213/265/315 ms to ~130-168/168/214 ms. README now documents the
  sqlite-mode latency trade-offs and the bench script.
- Earlier change: P0/P1 from the jghub cleanup/performance feedback.
  `do_cleanup()` now counts first and trims only when the non-bookmarked count
  exceeds `MAX_ENTRIES` (a pass at the limit is a no-op). The trim target is
  public as `PRUNE_FILL_PERCENT` (50-100, default 95; `_PRUNE_FILL_PERCENT`
  remains a legacy alias) and is read from `file.config` for the shared
  file.db tables. `MAX_ENTRIES` now defaults to 1000. Performance:
  `jump-handler` calls `_do_internal_query` in-process with an optional SQL
  `LIMIT` (best match uses 1), and a write collects every destination's
  post-write count in the same sqlite3 invocation as the upsert. Stale
  score-floor comments were removed. README, REGRESSION, and the CLI suite were
  updated; 27 cases pass at that point.
- Earlier change: added `tests/run-tests.sh` (20 CLI regression cases:
  capacity math incl. leading-zero/`0`/fill-level, write-protocol rejection,
  no-score-threshold invariant, config validation, shared per-table limits,
  undo trim, unbook, remove+undo, recent validation, jump-handler, missing-path
  preview, LIKE escaping) plus `.github/workflows/ci.yml` (bash -n, fish -n,
  shellcheck `-S warning`, test suite on push/PR). Fixed every shellcheck
  warning (~29: SC2155 splits, SC2209 quoting, dead SC2034 vars, SC2164 cd
  guards); two intentional patterns carry disable directives (SC2053 config
  glob, SC1090 config source).
- Earlier change: NORMAL-mode keys are now `y` (copy, Vim yank habit) and
  `g` (open the selected entry's git repository in the first available
  `gitui`/`ziggity`/`lazygit` in a new tmux window, then exit fzf). `g:first`
  and `G:last` were removed, along with `h`/`l` (single-column list); only
  `j`/`k` move. The helper lives in `scripts/open_git_repo.sh` and is installed
  with the other scripts. Entries outside a git repository leave the picker
  open.
- Next action: none queued. The remaining backlog is the manual host
  integration and interactive picker checks in [`TASKS.md`](TASKS.md).
- Blockers: none. Real-data cleanup was explicitly requested and performed after
  a verified backup; see the 2026-11-18 real-data entry below.

## What was verified

This is a snapshot, not a guarantee. Re-run the checks relevant to the next
change; record the actual commands and results here.

| Area | Check | Result |
|---|---|---|
| P0 cleanup | `MAX_ENTRIES=10`: at 10 rows cleanup keeps 10, at 11 rows trims to 9; `PRUNE_FILL_PERCENT=50` keeps 5 + protected; `0`/`200` fall back to 95% | pass |
| P0 config | `file.config` `PRUNE_FILL_PERCENT=50` applies to `file_dir`; legacy `_PRUNE_FILL_PERCENT=50` works; `MAX_ENTRIES=08` falls back to the 1000 default | pass |
| P1 writes | one `--route unified,dir,file` write -> `6\|11\|16`; old vs new `unified,dir` add on a loaded host ~51-56 -> ~42-44 ms/op | pass |
| P1 jump | in-process best match with SQL `LIMIT 1`; output matches exact/multi-word/no-match/empty; stub-fzf picker rc 0; loaded host ~72-89 -> ~42-47 ms/op (idle: 39 -> 28) | pass |
| P2 bench | `BENCH_ROOT=/dev/shm scripts/bench.sh`: 110/1000/16000 rows -> add ~24-25 ms/op, typed jump ~26-28 ms/op, full reload ~17/25/174 ms/op | pass |
| P2 latency | real fzf in a pty at 1500/3000/5000 rows: `SLEEP_DELAY=0.06` ~213/265/315 ms -> `0.02` ~130-168/168/214 ms; a pty probe confirmed fzf cancels superseded reloads | pass |
| Query cap | `QUERY_LIMIT=32` + trailing `TOTAL n`: 16000-row broad query ~271 -> ~72 ms, 1000-row ~44 -> ~31 ms; fzf 0.72 pty showed ` < 1/120 ────` in both SEARCH and NORMAL, plus working `Esc` and footer | pass |
| Query cap test | `internal-query all seed 5 1` emits 5 candidates plus `TOTAL 50`; `sed '$d'` leaves 5 rows; limit `0` returns all 50 rows | pass |
| Tests | `bash -n` (7 scripts incl. `scripts/bench.sh`), `fish -n`, `tests/run-tests.sh` -> 28 passed, 0 failed | pass |
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
| fzf keys | stub fzf 0.72 argv capture: `y:` copy bind, `g:` git bind, nav bind is `j,k` (no `h`/`l`/`G`) | pass |
| Git TUI | `open_git_repo.sh` with stubs: file uses its parent repo, directory checked directly, missing path uses its parent; priority `gitui` → `ziggity` → `lazygit` and each runs with `$PWD` at the repo root; outside repo and no-tool cases exit 1 and write `fail` | pass |
| Git TUI | `TMUX` set + stub tmux: `tmux new-window 'cd <repo> && exec <tool>'` (space-containing repo path escaped) and `ok` status; without `TMUX` the tool runs in the current terminal | pass |
| Git TUI | generated abort transform: `ok` → `abort`, `fail`/missing → `nop` | pass |
| Installer | `./install.sh --dry-run --register` in a disposable HOME installs `open_git_repo.sh` | pass |
| Score cleanup | `bash -n` (6 scripts) + `fish -n shell/frecency.fish` + `git diff --check` | pass |
| Score cleanup | disposable HOME, 100 dead + 1 live + 1 bookmark, `file add --route unified` -> `0\|1\|1\|1` | pass |
| Score cleanup | floors from `file.config`, manual `file_dir`/`file_file`/`file cleanup` -> `0\|1\|1\|0\|1\|1\|0\|1\|1` | pass |
| Score cleanup | `MIN_SCORE_UNIFIED=0` then `abc`: dead rows stay `10\|10`, no SQL error | pass |
| Score cleanup | floor `2` protects the just-written row: `10\|0\|1\|1` | pass |
| Score cleanup | `MAX_ENTRIES_UNIFIED=100` after score prune: `91\|90\|1\|1` | pass |
| Score cleanup | multi-topic `file_dir,other`: file.db keeps `10` (floor 0), other.db has `0` (default) | pass |
| Installer | `./install.sh --dry-run --register` preview after the change | pass |
| Real data | sqlite `.backup` of all topic DBs + configs; backup `file.db` integrity ok and row counts match source | pass |
| Real data | before: unified `1265` nonbook / `1085` <0.01, dir `117` / `36` <0.05, file `63` / `14` <0.05 | pass |
| Real data | one `cleanup` pass per logical topic: nonbook -> `180`/`81`/`49`, below-floor -> `0`/`0`/`0`, bookmarks `13`/`11`/`2` unchanged | pass |
| Real data | backup vs live: 0 bookmarks lost, 0 unexpected rows, event clocks and undo tables unchanged, live `PRAGMA integrity_check` ok | pass |
| Background cleanup | source, pushed HEAD and installed copy all show `do_cleanup()` starting with `_prune_low_score()`; `RANDOM % 200 == 0` sampled `97/20000` (~0.5%) | pass |
| Floor removal | `grep -rn "MIN_SCORE\|min_score\|_prune_low_score"` over all scripts and README returns nothing; `bash -n` (6 scripts) + `fish -n` + `git diff --check` pass | pass |
| Floor removal | disposable HOME: rows at tick 1 with meta tick 1000000 (score ~0) plus live and bookmark rows all survive `frecency file cleanup` (rc 0, 3 rows) | pass |
| Test suite | `bash tests/run-tests.sh`: 20 CLI cases pass locally (incl. with `SHELLCHECK=<0.10.0 binary>`); 0 failed | pass |
| Shellcheck | shellcheck 0.10.0 `-S warning` clean on all 6 bash scripts after fixes | pass |
| CI workflow | `.github/workflows/ci.yml` syntax reviewed locally (YAML + step commands executed by hand); first run happens on push | pass (manual equivalence) |
| CI run | run for `a7ebf6e` on GitHub Actions: bash -n + fish -n + shellcheck + test suite all green | pass |
| dir.db repair | readonly `integrity_check` before: `row 6 missing from index sqlite_autoindex_entries_1`; verified `.backup` taken; after `REINDEX entries`: `ok`, counts identical to backup | pass |

## Recent changes

- 2026-11-20 (query cap): added `QUERY_LIMIT` (default 32, `0` = unlimited).
  `internal-query` still computes and orders every match in SQL, but formats
  and outputs only the top N, appending `TOTAL n` to its own result when asked.
  The UI strips that line before fzf (`reload(sed '$d' ...)`), and on fzf >= 0.54
  a generated `--info-command` renders the native info line as `< 1/n ────`,
  keeping the original prompt/info/separator style in both modes. No side-channel
  count file is used. `jump-handler` keeps its separate `LIMIT 1` and emits no
  TOTAL line. The query is run synchronously into one candidate file before
  reload so the info line is fresh on every keystroke. `scripts/bench.sh`
  compares unlimited vs capped queries: at 16000 rows ~271 -> ~72 ms, at 1000
  rows ~44 -> ~31 ms. A real-fzf pty check showed ` < 1/120 ────` in SEARCH and
  NORMAL, no `32/32`, no visible `TOTAL`, and `Esc` switching SEARCH -> NORMAL.
  The footer and prompt are updated by one combined transform, which fixed the
  Esc regression. Added one CLI case for the TOTAL line/row counts (28 pass).
  README and REGRESSION updated.
- 2026-11-20 (P2): finished the two deferred performance follow-ups. Added
  `scripts/bench.sh` (manual, not installed and not in CI) with a disposable
  `HOME`, seeded 110/1000/16000 rows and timings for `add`, typed
  `jump-handler` and `internal-query all`; default run on tmpfs: add ~24-25
  ms/op, jump ~26-28 ms/op, full reload ~17/25/174 ms/op. Verified with a pty
  that fzf cancels superseded `reload` processes, then lowered `SLEEP_DELAY`
  from 0.06 to 0.02 s (and its invalid-config fallback); a real-fzf pty probe
  at 1500/3000/5000 rows measured ~213/265/315 ms -> ~130-168/168/214 ms per
  keystroke. README documents the sqlite-mode soft ceiling, the
  `SEARCH_MODE=fzf` trade-off and how to run the bench script. CI and the
  local shellcheck list now cover `scripts/bench.sh` too. P2 items were removed
  from `TASKS.md`; no regression tests changed (27 still pass).
- 2026-11-20: applied P0/P1 from the jghub cleanup/performance feedback.
  (1) `do_cleanup()` now counts the non-bookmarked rows first and trims only
  when the count exceeds `MAX_ENTRIES`; previously a manual or 1-in-200
  background pass trimmed to the fill level even below capacity (10 rows at
  limit 10 became 9; 1400 at limit 1500 became 1350). The fill percentage is
  hysteresis, not a second cap.
  (2) The trim target is public as `PRUNE_FILL_PERCENT` (valid 50-100, default
  95; outside the range falls back to 95). It is loaded from the topic config
  and, for `file_dir`/`file_file`, from `file.config` through
  `_load_shared_file_limits()`; `_PRUNE_FILL_PERCENT` remains a deprecated
  alias. `PRUNE_FILL_PERCENT=0` can no longer collapse a table to two rows.
  (3) `MAX_ENTRIES` defaults to 1000 instead of 1500, keeping the sqlite-mode
  full-list reload short; README explains the trade-off and points at
  `SEARCH_MODE=fzf` for very large tables.
  (4) `do_jump_handler` calls `_do_internal_query` directly instead of
  re-executing the script, and passes `LIMIT 1` for the no-fzf best-match path;
  measured 39 -> 28 ms/op on an idle host and ~72-89 -> ~42-47 ms/op on a
  loaded one.
  (5) `_do_upsert_route` now requests each destination's post-write `COUNT(*)`
  inside the same sqlite3 invocation as the upsert (the counts sit before
  `COMMIT`), removing one process per table; `add --route unified,dir` measured
  ~51-56 -> ~42-44 ms/op on the same loaded host.
  (6) Removed the three stale score-floor comments and extended the
  `docs/REGRESSION.md` grep invariant to catch them. Tests grew from 20 to 27
  CLI cases (cleanup guard, public/legacy fill settings, shared fill, and
  per-destination counts); all pass. No real-data migration is needed: the
  current topic tables are well below the new 1000 default.
- 2026-11-19: repaired the legacy `dir.db` index corruption: `PRAGMA
  integrity_check` reported `row 6 missing from index
  sqlite_autoindex_entries_1` (pre-existing, first noted during the 2026-11-18
  backup verification). Took a verified sqlite `.backup` first, then
  `REINDEX entries` on the live database: integrity_check now returns `ok`,
  and row counts, bookmark counts, trash counts, and the event clock are
  identical to the backup (669/16/46/1051). Local data maintenance only; no
  code change. The same day, CI was made green: the shellcheck step failed on
  the first run because a plain YAML scalar folded the backslash-newline
  continuations into an escaped space, handing shellcheck a path with a
  leading space; the step now uses a block scalar and passes.
- 2026-11-18: removed the score-floor cleanup mechanism introduced earlier the
  same day. Rationale (from the jghub fzf#4789 discussion, recorded as a
  decision in the private workflow log): a score is an ordinal — its absolute
  size has no meaning across usage patterns, so a score threshold is an
  implicit, unpredictable stand-in for the real decision variable
  (`MAX_ENTRIES`); low-score entries ("rarely visited", e.g. an important
  rarely-touched config file) must stay reachable. `_prune_low_score()`,
  `_min_score_for_dest()`, and the `MIN_SCORE_*` config keys were deleted;
  the shared-limits loader and both cleanup call sites were reduced to the
  capacity prune. Note the floor had already run once on the real database
  before this removal (see the real-data entry below; the removed rows are in
  that verified backup). `README.md` and `docs/REGRESSION.md` were rewritten
  (the score-floor checks became a "no score-threshold cleanup" invariant),
  and DLT `docs/frecency.md` was synced.
- 2026-11-18: raised the low-frequency background cleanup chance from `1/1000`
  to `1/200` (~0.5%, roughly once every few days of normal use) and updated its
  comment. Verified against source, pushed HEAD and the installed copy that
  `do_cleanup()` already starts with `_prune_low_score()`, so the background
  path is already score-then-capacity; no duplicate call was added. `README.md`
  and DLT `docs/frecency.md` were synced, and the local runtime was refreshed
  with `./install.sh --register` (copy identical, self-check ok).
- 2026-11-18 (real data): with explicit user request, took a verified sqlite
  `.backup` of every topic DB plus configs (location in the private workflow),
  measured before/after score distributions, then ran one `cleanup` pass per
  logical topic on `file.db`. Unified nonbookmarked rows went `1265 -> 180`
  (`1085` removed below 0.01), dir `117 -> 81` (`36` below 0.05), file `63 -> 49`
  (`14` below 0.05); all `26` bookmarks survived, no capacity prune fired (all
  tables are far below 1500), event clocks and undo tables are unchanged, and
  both backup and live DB pass `PRAGMA integrity_check`. The changeset was
  committed and pushed to `origin/main`; the DLT doc was committed and pushed
  to `origin/master`; the local runtime was refreshed with
  `./install.sh --register` and passed its self-check.
- 2026-11-18: added per-destination score-floor maintenance. Source facts were
  checked first: capacity falls back to `MAX_ENTRIES`=1500 with a 90% fill, and
  there was no score floor. `scripts/frecency` now reads
  `MIN_SCORE_UNIFIED=0.01` / `_DIR=0.05` / `_FILE=0.05` (`0` disables, invalid
  becomes `0`); new `_prune_low_score()` deletes only `keyword=''` rows whose
  current aligned score is below the floor, using each table's tick key and λ.
  `_do_upsert_route()` and `do_cleanup()` run it before the existing capacity
  prune and re-count before that prune. Defaults live in `_min_score_for_dest()`
  so `file_dir`/`file_file` can share `file.config` values without config
  leaking across topics; λ remains static and the background cleanup path is
  unchanged. `README.md`, `docs/REGRESSION.md`, and DLT `docs/frecency.md` were
  updated. Completion notes: DLT doc updated = yes; local runtime refreshed =
  yes (`./install.sh --register` + self-check); commit/push = yes, code and
  state together to `origin/main`.
- 2026-11-18: NORMAL-mode key changes. `c` is now `y` for copying the path
  (Vim yank habit). `g` now opens the git repository containing the focused
  entry in a new tmux window (like `e`; the current terminal without tmux) and
  exits the picker; outside a repository it leaves the picker open. `g:first`
  and `G:last` were removed, as were `h`/`l`: the list is a single vertical
  column, so only `j`/`k` move. The new `scripts/open_git_repo.sh` resolves a
  file to its parent directory, accepts a directory directly, and opens the
  repository with the first installed `gitui` → `ziggity` → `lazygit`; it
  writes a status file so the picker aborts only when a TUI actually started.
  `install.sh`, `README.md`, `docs/REGRESSION.md`, and `docs/TASKS.md` were
  updated.
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
   docs, and state together. Do not record commit hashes in this file: a hash
   can only name the previous commit, which forces an extra docs-only commit
   to keep it current.
6. Keep private decisions, local paths, and machine-specific commands in
   `.harness-local/WORKFLOW.md`.

## Known gaps

- Bash, fish, vifm, and Neovim host event behavior is not covered by automated
  end-to-end tests; see the "Not covered" section of `REGRESSION.md`.
- `ji` and the NORMAL-mode `y`/`v`/`e`/`g` actions still need an interactive pass
  on the maintainer's own terminal/tmux setup; the recorded pty checks were run
  on one machine only. (`C`/`V`/`E` are unbound and need no testing.)
- There is no supported CLI command to reset or list all entries for a topic.

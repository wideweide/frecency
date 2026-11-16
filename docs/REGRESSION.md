# Maintainer regression checklist

Project-wide acceptance gates are in [`ACCEPTANCE.md`](ACCEPTANCE.md); record
the checks you actually ran in [`STATE.md`](STATE.md).

Run these checks after changes to the matching area. Interactive UI checks need
the supported fzf version and a terminal. Use a disposable home for database
checks so the examples do not touch your normal history.
Run the search and curation examples in one shell session so they share
`test_home`; they disable the default `/tmp` ignore pattern for that test topic.

## Search and scoring

1. Create two paths and add them to a temporary topic:

   ```bash
   test_home=$(mktemp -d)
   mkdir -p "$test_home/alpha/src" "$test_home/beta/src"
   mkdir -p "$test_home/.local/share/frecency"
   printf '%s\n' 'IGNORE_PATTERNS=()' > "$test_home/.local/share/frecency/check.config"
   touch "$test_home/alpha/src/parser.c" "$test_home/beta/src/other.c"
   HOME="$test_home" scripts/frecency check add "$test_home/alpha/src/parser.c"
   HOME="$test_home" scripts/frecency check add "$test_home/beta/src/other.c"
   HOME="$test_home" scripts/frecency check query 'alpha parser'
   ```

   Expected: the SQLite search mode finds `alpha/src/parser.c` for the ordered
   multi-word query. In the UI, toggle `s` and confirm the footer reports the
   selected ordered/any-order mode. Remove the temporary directory when done.

2. Add an entry with a keyword, then remove only the keyword:

   ```bash
   HOME="$test_home" scripts/frecency check add "$test_home/alpha/src/parser.c" parser-tag
   HOME="$test_home" scripts/frecency check unbook "$test_home/alpha/src/parser.c"
   ```

   Expected: `unbook` reports that the bookmark was removed and EMS history
   retained. Confirm the path still appears in
   `HOME="$test_home" scripts/frecency check query` and `parser-tag` no longer acts as its keyword
   match. The UI `r` action should have the same keep-history behavior.

## Capacity cleanup

Use a disposable home and seed more rows than the default limit.

```bash
test_home=$(mktemp -d)
mkdir -p "$test_home/.local/share/frecency"
printf '%s\n' 'IGNORE_PATTERNS=()' > "$test_home/.local/share/frecency/file.config"
HOME="$test_home" scripts/frecency file init
sqlite_bin=$(cat "$test_home/.local/share/frecency/.sqlite3.bin")
"$sqlite_bin" "$test_home/.local/share/frecency/file.db" <<'SQL'
WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i < 1600)
INSERT INTO entries (content, keyword, score, visits, tick, last_access)
SELECT '/seed/' || i, '', i, 1, i,
       datetime('now', '-' || (2000 - i) || ' seconds') FROM n;
UPDATE meta SET v = '1600' WHERE k = 'tick';
SQL
HOME="$test_home" scripts/frecency file add --route unified "$test_home/alpha"
"$sqlite_bin" "$test_home/.local/share/frecency/file.db" \
  "SELECT count(*) FROM entries WHERE keyword='';
   SELECT count(*) FROM entries WHERE content='$test_home/alpha';
   SELECT min(score), max(score) FROM entries WHERE keyword='';"
```

Expected: the unbookmarked count is about 1351 (1350 target plus the protected
new entry), `alpha` is present, and the retained scores are the higher ones.
Bookmarks are exempt from both the limit and deletion.

To check independent per-table limits, put them in `file.config` and repeat:

```bash
cat > "$test_home/.local/share/frecency/file.config" <<'EOF'
IGNORE_PATTERNS=()
MAX_ENTRIES_UNIFIED=100
MAX_ENTRIES_DIR=200
MAX_ENTRIES_FILE=300
EOF
"$sqlite_bin" "$test_home/.local/share/frecency/file.db" <<'SQL'
WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i < 400)
INSERT INTO dir_entries SELECT '/d/'||i, '', i, 1, i, CURRENT_TIMESTAMP FROM n;
WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i < 400)
INSERT INTO file_entries SELECT '/f/'||i, '', i, 1, i, CURRENT_TIMESTAMP FROM n;
INSERT INTO entries VALUES ('/bookmark/path', 'tag', 1.0, 1, 1601, CURRENT_TIMESTAMP);
UPDATE meta SET v='400' WHERE k IN ('dir_tick', 'file_tick');
SQL
HOME="$test_home" scripts/frecency file add --route unified,dir,file "$test_home/beta"
"$sqlite_bin" "$test_home/.local/share/frecency/file.db" \
  "SELECT (SELECT count(*) FROM entries WHERE keyword=''),
          (SELECT count(*) FROM dir_entries WHERE keyword=''),
          (SELECT count(*) FROM file_entries WHERE keyword=''),
          (SELECT count(*) FROM entries WHERE content='/bookmark/path');"
```

Expected: each non-empty table is at or below its configured limit after
pruning (with the seeded rows above, the counts should be `91|181|271|1`:
entries, directories, files, and the surviving bookmark), and the newly written
entry survives. `MAX_ENTRIES=0` disables automatic pruning for that table.

## UI curation and missing paths

1. In the temporary topic UI, press `/`, search for the seeded path, press `d`,
   then `u`.

   Expected: the row is removed to the undo table, and `u` restores the most
   recently deleted row. Reopen the UI to confirm it is present.

2. Add a path, remove the file from disk, and open the history UI:

   ```bash
   touch "$test_home/alpha/src/gone.txt"
   HOME="$test_home" scripts/frecency check add "$test_home/alpha/src/gone.txt"
   rm "$test_home/alpha/src/gone.txt"
   HOME="$test_home" scripts/frecency check query
   ```

   Expected: preview identifies the missing path and offers the `d` cleanup
   action. Delete the row with `d`; the record should no longer appear. The
   `c`/`C` keys copy the selected path and do not remove missing paths; capacity
   cleanup is automatic after writes and can also be run with
   `frecency <topic> cleanup`.

## Shell navigation (Bash and fish)

Use a disposable home. The existing path must win over a history entry with the
same name.

1. Prepare paths and history:

   ```bash
   test_home=$(mktemp -d)
   mkdir -p "$test_home/live" "$test_home/hist/deep/live"
   mkdir -p "$test_home/.local/share/frecency"
   printf '%s\n' 'IGNORE_PATTERNS=()' > "$test_home/.local/share/frecency/file.config"
   HOME="$test_home" scripts/frecency file add --route unified,dir "$test_home/hist/deep/live"
   ```

2. Bash: an existing directory wins over history:

   ```bash
   HOME="$test_home" bash --noprofile --norc -c '
     source "$1/shell/frecency.bash"
     cd "$HOME"
     j live
     test "$PWD" = "$HOME/live" && echo PASS
   ' _ "$PWD"
   ```

   Expected: `PASS`; `j live` must not jump to `hist/deep/live`.

3. Bash: bare `j` goes to `$HOME`, and `j -` behaves like `cd -`:

   ```bash
   HOME="$test_home" bash --noprofile --norc -c '
     source "$1/shell/frecency.bash"
     cd /
     j
     test "$PWD" = "$HOME" && echo HOME_PASS
     cd "$HOME/live"
     j -
     test "$PWD" = "$HOME" && echo DASH_PASS
   ' _ "$PWD"
   ```

4. Bash: multi-word queries stay history lookups, and no match exits non-zero:

   ```bash
   HOME="$test_home" scripts/frecency file_dir jump-handler deep live
   HOME="$test_home" scripts/frecency file_dir jump-handler definitely-no-such-entry
   test $? -ne 0 && echo NO_MATCH_PASS
   ```

5. Bash: file selection prints only the path and keeps `$PWD`:

   ```bash
   touch "$test_home/a.txt"
   HOME="$test_home" bash --noprofile --norc -c '
     source "$1/shell/frecency.bash"
     cd "$HOME"
     before=$PWD
     out=$(J "$HOME/a.txt")
     test "$out" = "$HOME/a.txt" && echo PATH_PASS
     test "$PWD" = "$before" && echo PWD_PASS
     out=$(o "$HOME/a.txt")
     test "$out" = "$HOME/a.txt" && echo O_FILE_PASS
     o "$HOME/live"
     test "$PWD" = "$HOME/live" && echo O_DIR_PASS
   ' _ "$PWD"
   ```

6. Bash: `jc` copies a selected file path without a newline and `je` opens it
   with vim; neither changes `$PWD`. Use stubs on `PATH` for the side effects:

   ```bash
   mkdir -p "$test_home/bin"
   printf '#!/bin/sh\ncat > "$HOME/clipboard"\n' > "$test_home/bin/wl-copy"
   printf '#!/bin/sh\nprintf "%%s\\n" "$*" > "$HOME/vim_args"\n' > "$test_home/bin/vim"
   chmod +x "$test_home/bin/wl-copy" "$test_home/bin/vim"
   HOME="$test_home" PATH="$test_home/bin:$PATH" bash --noprofile --norc -c '
     source "$1/shell/frecency.bash"
     cd /
     before=$PWD
     jc a.txt
     test "$(cat "$HOME/clipboard")" = "$HOME/a.txt" && echo JC_PASS
     test "$PWD" = "$before" && echo JC_PWD_PASS
     je a.txt
     grep -q -- "-- $HOME/a.txt" "$HOME/vim_args" && echo JE_PASS
     test "$PWD" = "$before" && echo JE_PWD_PASS
   ' _ "$PWD"
   ```

   Expected: all four checks pass. The clipboard file contains the raw path
   with no trailing newline (`wc -c` matches the path length).

7. Fish: repeat steps 2–6 with `fish --no-config` and the fish integration.

8. Manual: `ji` opens the picker; an argument becomes the initial query;
   `Esc` returns to NORMAL.

## fzf action keys (NORMAL mode)

Use a disposable `HOME` with `START_MODE=normal` in both `file.config` and
`file_file.config`, and stubs for `wl-copy`, `$EDITOR`, and the viewer. Open a
picker and check:

1. `Enter` is the only key that emits a path. `c`, `v`, and `e` must never
   print a path or change the shell's `$PWD`.
2. `c` copies the raw selected path to the clipboard (no trailing newline) and
   fzf **stays open**. The footer shows `copied <path>`; switching entries and
   copying again updates the footer, so each copy is unambiguous. Verify with a
   path containing `)`, `,`, `+`, and backslashes — the footer must show the
   verbatim path.
3. `v` runs the viewer under fzf `execute`: the picker is suspended so the
   program owns the terminal/popup and renders its content (verify the file
   text appears on screen). On viewer exit fzf resumes **untouched** — same
   query, list, and scroll position — for another selection. A directory opens
   in `view`'s netrw browser (or `eza -la` / `ls -la` fallback).
4. The viewer command for `v` is `FRECENCY_VIEWER` if set and its binary
   exists, otherwise `view`, then `$PAGER`, then `less -R`, then `cat`. `view`
   is preferred for syntax highlighting. Confirm the chain with stubs on an
   isolated `PATH`.
5. `e` runs `$EDITOR` and then aborts fzf **without emitting a path**: inside
   tmux it opens a new fullscreen window (a tmux popup would cover it); without
   tmux it runs in the current terminal. In both cases `:q` returns to the
   shell, not to fzf.
6. `C`, `V`, and `E` are no longer bound and must do nothing.
7. In SEARCH mode the characters `c`, `v`, `e` only filter text and must not
   trigger any of the actions.


## Installer behavior

From the repository root, inspect the install and uninstall plans:

```bash
./install.sh --dry-run --register
./install.sh --dry-run --uninstall
```

Expected: output describes the files and registrations that would be changed;
the dry-run does not create the install, registration, or symlink targets.
Check that the register plan includes integrations supported by the current
machine and the bin link, and the uninstall plan removes registrations before
installed files.

## Database initialization and migration

Use a fresh temporary home and initialize twice:

```bash
test_home=$(mktemp -d)
HOME="$test_home" scripts/frecency check init
HOME="$test_home" scripts/frecency check init
```

Expected: both commands succeed. The second run leaves the database usable and
does not fail on already existing columns or indexes.

For old-schema coverage, prepare a disposable `check.db` under
`$test_home/.local/share/frecency/`. This v1 fixture lacks `visits`, `tick`,
and `meta`; invoke frecency once first so its selected SQLite binary is
available, then create and migrate the fixture:

```bash
test_home=$(mktemp -d)
mkdir -p "$test_home/.local/share/frecency"
HOME="$test_home" scripts/frecency probe init
sqlite_bin=$(cat "$test_home/.local/share/frecency/.sqlite3.bin")
"$sqlite_bin" "$test_home/.local/share/frecency/check.db" <<'SQL'
CREATE TABLE entries (
  content TEXT PRIMARY KEY, keyword TEXT DEFAULT '', score REAL DEFAULT 1.0,
  last_access DATETIME DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO entries (content, keyword, score) VALUES ('/kept/path', '', 4.0);
SQL
HOME="$test_home" scripts/frecency check init
HOME="$test_home" scripts/frecency check init
"$sqlite_bin" "$test_home/.local/share/frecency/check.db" \
  "SELECT (SELECT v FROM meta WHERE k='schema_version'), content, visits, tick FROM entries;"
```

Expected: the query reports schema version `4`, preserves `/kept/path`, and
shows the migrated `visits` and `tick` values. The second init succeeds without
changing the row. To exercise v2's bookmark-score migration, create a separate
temporary home and fixture with the current columns but a v2 meta version:

```bash
test_home=$(mktemp -d)
mkdir -p "$test_home/.local/share/frecency"
HOME="$test_home" scripts/frecency probe init
sqlite_bin=$(cat "$test_home/.local/share/frecency/.sqlite3.bin")
"$sqlite_bin" "$test_home/.local/share/frecency/check.db" <<'SQL'
CREATE TABLE entries (
  content TEXT PRIMARY KEY, keyword TEXT DEFAULT '', score REAL DEFAULT 1.0,
  visits INTEGER DEFAULT 1, tick INTEGER DEFAULT 0,
  last_access DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE meta (k TEXT PRIMARY KEY, v TEXT);
INSERT INTO meta VALUES ('schema_version', '2'), ('tick', '1');
INSERT INTO entries (content, keyword, score, visits, tick)
  VALUES ('/bookmarked/path', 'tag', 1200.0, 10, 0);
SQL
HOME="$test_home" scripts/frecency check init
HOME="$test_home" scripts/frecency check init
"$sqlite_bin" "$test_home/.local/share/frecency/check.db" \
  "SELECT (SELECT v FROM meta WHERE k='schema_version'), score FROM entries WHERE content='/bookmarked/path';"
```

Expected: the result is `4|1.0`, and the second init succeeds. Keep fixtures
disposable and never run migration experiments on a user's database.

For routing coverage, use a fresh disposable home with an existing directory
and file. Record a directory and a file to both unified and typed histories:

```bash
HOME="$test_home" scripts/frecency file add --route unified,dir "$test_home/alpha"
HOME="$test_home" scripts/frecency file add --route unified,file "$test_home/alpha/src/parser.c"
sqlite_bin=$(cat "$test_home/.local/share/frecency/.sqlite3.bin")
"$sqlite_bin" "$test_home/.local/share/frecency/file.db" \
  "SELECT (SELECT count(*) FROM entries), (SELECT count(*) FROM dir_entries), (SELECT count(*) FROM file_entries), (SELECT v FROM meta WHERE k='tick'), (SELECT v FROM meta WHERE k='dir_tick'), (SELECT v FROM meta WHERE k='file_tick');"
```

Expected: counts are `2|1|1` and the clocks are `2|1|1` (unified, directory,
file). Set
`RECORD_UNIFIED=0` in `file.config`, add another path with `--route
unified,dir`, and confirm only `dir_entries` changes. Restore the default for
later checks. UI and host integration behavior still requires manual testing.

## Not covered by this checklist

- Automated end-to-end checks for Bash, fish, Vifm, and Neovim host event
  behavior are not currently provided; those integrations need manual host
  testing.
- The interactive `ji` picker and NORMAL-mode `c`/`v`/`e` actions (and their
  uppercase variants) need a real terminal and are not exercised by the
  automated capacity/CLI commands.
- There is no supported command to reset a topic database or list its entries
  without the interactive query UI.

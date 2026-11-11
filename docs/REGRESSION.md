# Maintainer regression checklist

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
   `C` key runs age/count cleanup and does not specifically remove missing
   paths, so do not treat it as the missing-path cleanup action.

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
- There is no supported command to reset a topic database or list its entries
  without the interactive query UI.

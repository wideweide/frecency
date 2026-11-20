#!/usr/bin/env bash
# Assertion-based regression tests for frecency CLI behavior.
#
# Every case runs against a disposable HOME and XDG_DATA_HOME, so nothing here
# can touch a real database. Rows are seeded directly with sqlite3 (fast), and
# the product script is exercised through its public CLI only. The suite needs:
#   bash 4+, sqlite3 (any build; no math functions required for seeding)
# Run from anywhere:  tests/run-tests.sh
# Exit code: 0 all pass, 1 at least one failure.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FRECENCY="$ROOT/scripts/frecency"
SHELLCHECK_BIN="${SHELLCHECK:-shellcheck}"

PASS=0
FAIL=0
CURRENT_TD=""
CURRENT_NAME=""

cleanup_case() {
    [[ -n "$CURRENT_TD" ]] && rm -rf "$CURRENT_TD"
    CURRENT_TD=""
}
trap cleanup_case EXIT

# --- assertions -------------------------------------------------------------
fail() { printf '  ✗ %s: %s\n' "$CURRENT_NAME" "$1"; FAIL=$((FAIL + 1)); }
ok()   { printf '  ✓ %s\n' "$CURRENT_NAME"; PASS=$((PASS + 1)); }

assert_eq() { # assert_eq <desc> <expected> <actual>
    if [[ "$2" == "$3" ]]; then return 0; fi
    fail "$1: expected [$2], got [$3]"
    return 1
}
assert_rc() { # assert_rc <desc> <expected-rc> <command...>
    local desc="$1" want="$2"; shift 2
    "$@" >/dev/null 2>&1
    if [[ $? -eq $want ]]; then return 0; fi
    fail "$desc: expected rc $want"
    return 1
}
assert_contains() { # assert_contains <desc> <needle> <haystack>
    if [[ "$3" == *"$2"* ]]; then return 0; fi
    fail "$1: missing [$2]"
    return 1
}
assert_quiet_stderr() { # assert_quiet_stderr <desc> <command...>
    local desc="$1"; shift
    local out
    out=$("$@" 2>&1 >/dev/null)
    if [[ -z "$out" ]]; then return 0; fi
    fail "$desc: unexpected stderr: $out"
    return 1
}

# --- case scaffolding -------------------------------------------------------
case_begin() { # case_begin <name>
    CURRENT_NAME="$1"
    cleanup_case
    CURRENT_TD=$(mktemp -d)
    export HOME="$CURRENT_TD/home"
    export XDG_DATA_HOME="$CURRENT_TD/home/.local/share"
    mkdir -p "$HOME"
    DATA="$XDG_DATA_HOME/frecency"
    DB="$DATA/file.db"
}

# init a topic and neutralize the built-in ignore patterns (the suite seeds
# rows under /tmp, which the defaults would silently skip)
init_topic() { # init_topic <topic> [extra config lines...]
    local t="$1"; shift
    "$FRECENCY" "$t" init >/dev/null 2>&1 || return 1
    { printf 'IGNORE_PATTERNS=()\n'; printf '%s\n' "$@"; } > "$DATA/$t.config"
}

# stub fzf: consume stdin, emit nothing, exit 0 (the picker must exit quietly)
stub_fzf() {
    mkdir -p "$CURRENT_TD/bin"
    printf '#!/bin/bash\ncat > /dev/null\nexit 0\n' > "$CURRENT_TD/bin/fzf"
    chmod +x "$CURRENT_TD/bin/fzf"
    PATH="$CURRENT_TD/bin:$PATH"
}

# seed <count> rows into <table> at ticks 1..N (keyword-free), set the meta
# clock to <now_tick>, and optionally add one bookmarked row
seed_rows() { # seed_rows <db> <table> <tick_key> <count> [bookmark]
    local db="$1" table="$2" tick_key="$3" count="$4" bookmark="${5:-}"
    local sql="WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i < $count)
INSERT INTO $table (content, keyword, score, visits, tick, last_access)
SELECT '/seed/' || printf('%03d', i), '', 1.0, 1, i, datetime('now', '-' || (1000 - i) || ' minutes') FROM n;
UPDATE meta SET v = '1000' WHERE k = '$tick_key';"
    if [[ -n "$bookmark" ]]; then
        sql+="
INSERT INTO $table (content, keyword, score, visits, tick, last_access)
VALUES ('/bm', 'tag', 5.0, 1, 999, '2026-01-01 00:00:00');"
    fi
    sqlite3 "$db" "$sql"
}
count_rows() { # count_rows <db> <table> [where]
    sqlite3 "$1" "SELECT count(*) FROM $2 ${3:+WHERE $3};"
}

# ===========================================================================
# Cases
# ===========================================================================

case_begin "init is idempotent"
assert_rc "first init" 0 "$FRECENCY" file init
assert_rc "second init" 0 "$FRECENCY" file init
ok

case_begin "XDG_DATA_HOME is honored"
"$FRECENCY" file init >/dev/null 2>&1
assert_eq "db under XDG_DATA_HOME" "$DATA/file.db" "$(readlink -f "$DB")"
[[ -e "$DB" ]] || fail "file.db does not exist"
ok

case_begin "init lock is keyed by database file"
"$FRECENCY" file init >/dev/null 2>&1
assert_eq "shared lock name" "$DATA/.file.db.init.lock" "$DATA/.$(basename "$DB").init.lock"
ok

case_begin "add rejects a path containing a newline"
init_topic file
assert_rc "newline path" 2 "$FRECENCY" file add "$(printf '/bad\npath')"
assert_eq "nothing stored" "0" "$(count_rows "$DB" entries)"
ok

case_begin "add rejects a path containing the field separator"
init_topic file
assert_rc "SEP path" 2 "$FRECENCY" file add "$(printf '/bad\037path')"
assert_eq "nothing stored" "0" "$(count_rows "$DB" entries)"
ok

case_begin "add honors built-in ignore patterns"
"$FRECENCY" file init >/dev/null 2>&1   # no config: built-in */tmp/* applies
assert_eq "tmp path skipped" "0" "$(count_rows "$DB" entries)"
ok

case_begin "cleanup is a no-op at or below the capacity limit"
init_topic file "MAX_ENTRIES=10"
seed_rows "$DB" entries tick 10
assert_rc "cleanup at the limit" 0 "$FRECENCY" file cleanup
assert_eq "all rows kept at the limit" "10" "$(count_rows "$DB" entries)"
printf 'IGNORE_PATTERNS=()\nMAX_ENTRIES=100\n' > "$DATA/file.config"
sqlite3 "$DB" "DELETE FROM entries;"
seed_rows "$DB" entries tick 50
assert_rc "cleanup below the limit" 0 "$FRECENCY" file cleanup
assert_eq "all rows kept below the limit" "50" "$(count_rows "$DB" entries)"
ok

case_begin "cleanup prunes only when the table exceeds the capacity limit"
init_topic file "MAX_ENTRIES=10"
seed_rows "$DB" entries tick 11
assert_rc "cleanup above the limit" 0 "$FRECENCY" file cleanup
assert_eq "trimmed to the 95% fill" "9" "$(count_rows "$DB" entries)"
ok

case_begin "PRUNE_FILL_PERCENT controls the trim target"
init_topic file "MAX_ENTRIES=10" "PRUNE_FILL_PERCENT=50"
seed_rows "$DB" entries tick 50
assert_rc "add with a 50% fill" 0 "$FRECENCY" file add "$HOME/newdir"
assert_eq "5 kept + protected new" "6" "$(count_rows "$DB" entries)"
ok

case_begin "out-of-range PRUNE_FILL_PERCENT falls back to 95"
init_topic file "MAX_ENTRIES=10" "PRUNE_FILL_PERCENT=0"
seed_rows "$DB" entries tick 50
assert_rc "add with an invalid fill" 0 "$FRECENCY" file add "$HOME/newdir"
assert_eq "95% fill: 9 kept + protected new" "10" "$(count_rows "$DB" entries)"
ok

case_begin "legacy _PRUNE_FILL_PERCENT is still accepted"
init_topic file "MAX_ENTRIES=10" "_PRUNE_FILL_PERCENT=50"
seed_rows "$DB" entries tick 50
assert_rc "add with the legacy alias" 0 "$FRECENCY" file add "$HOME/newdir"
assert_eq "5 kept + protected new" "6" "$(count_rows "$DB" entries)"
ok

case_begin "capacity prune keeps the fill level and protects the new entry"
init_topic file "MAX_ENTRIES=8"
seed_rows "$DB" entries tick 50 bookmark
mkdir -p "$HOME/newdir"
"$FRECENCY" file add "$HOME/newdir" >/dev/null 2>&1
assert_eq "7 pruned + protected new + bookmark" "9" "$(count_rows "$DB" entries)"
assert_eq "nonbookmarked kept" "8" "$(count_rows "$DB" entries "keyword = ''")"
assert_eq "bookmark survives" "1" "$(sqlite3 "$DB" "SELECT count(*) FROM entries WHERE keyword != '';")"
assert_eq "new entry present" "1" "$(sqlite3 "$DB" "SELECT count(*) FROM entries WHERE content = '$HOME/newdir';")"
ok

case_begin "MAX_ENTRIES=0 disables pruning"
init_topic file "MAX_ENTRIES=0"
seed_rows "$DB" entries tick 12
assert_rc "add with pruning disabled" 0 "$FRECENCY" file add "$HOME/kept"
assert_eq "all rows kept" "13" "$(count_rows "$DB" entries)"
ok

case_begin "leading-zero MAX_ENTRIES falls back without an octal error"
init_topic file "MAX_ENTRIES=08"
seed_rows "$DB" entries tick 12
assert_rc "add" 0 "$FRECENCY" file add "$HOME/kept"
assert_quiet_stderr "no printf/arithmetic noise" "$FRECENCY" file cleanup
assert_eq "fell back to the 1000 default" "13" "$(count_rows "$DB" entries)"
ok

case_begin "no score-threshold cleanup: near-zero rows survive"
init_topic file
seed_rows "$DB" entries tick 3
sqlite3 "$DB" "UPDATE meta SET v = '1000000' WHERE k = 'tick';"
assert_rc "cleanup" 0 "$FRECENCY" file cleanup
assert_eq "dying rows survive under the limit" "3" "$(count_rows "$DB" entries)"
ok

case_begin "invalid numeric config falls back to defaults"
init_topic file "LAMBDA=abc" "SLEEP_DELAY=bad" "UNDO_KEEP=x" "LAST_LIMIT=bad" \
    "MAX_PATH_CHARS=bad" "PRUNE_FILL_PERCENT=200"
assert_rc "add with garbage config" 0 "$FRECENCY" file add "$HOME/x"
assert_rc "internal-query with garbage config" 0 "$FRECENCY" file internal-query all
assert_rc "start_data=last path with garbage config" 0 "$FRECENCY" file internal-query all last
ok

case_begin "split topics share per-table limits from file.config"
"$FRECENCY" file_dir init >/dev/null 2>&1
printf 'IGNORE_PATTERNS=()\n' > "$DATA/file_dir.config"
printf 'MAX_ENTRIES_DIR=10\n' > "$DATA/file.config"
seed_rows "$DB" dir_entries dir_tick 50
assert_rc "file_dir add" 0 "$FRECENCY" file_dir add "$HOME/newdir"
assert_eq "pruned to 9 + protected new" "10" "$(count_rows "$DB" dir_entries)"
ok

case_begin "split topics share PRUNE_FILL_PERCENT from file.config"
"$FRECENCY" file_dir init >/dev/null 2>&1
printf 'IGNORE_PATTERNS=()\n' > "$DATA/file_dir.config"
printf 'MAX_ENTRIES_DIR=10\nPRUNE_FILL_PERCENT=50\n' > "$DATA/file.config"
seed_rows "$DB" dir_entries dir_tick 50
assert_rc "file_dir add" 0 "$FRECENCY" file_dir add "$HOME/newdir"
assert_eq "shared 50% fill: 5 + protected new" "6" "$(count_rows "$DB" dir_entries)"
ok

case_begin "one write counts every destination for capacity"
init_topic file
printf 'IGNORE_PATTERNS=()\nMAX_ENTRIES_UNIFIED=10\nMAX_ENTRIES_DIR=20\nMAX_ENTRIES_FILE=30\nPRUNE_FILL_PERCENT=50\n' > "$DATA/file.config"
seed_rows "$DB" entries tick 50
seed_rows "$DB" dir_entries dir_tick 50
seed_rows "$DB" file_entries file_tick 50
assert_rc "three-destination add" 0 "$FRECENCY" file add --route unified,dir,file "$HOME/newboth"
assert_eq "unified 5 + protected" "6" "$(count_rows "$DB" entries)"
assert_eq "dir 10 + protected" "11" "$(count_rows "$DB" dir_entries)"
assert_eq "file 15 + protected" "16" "$(count_rows "$DB" file_entries)"
ok

case_begin "the undo table is trimmed to UNDO_KEEP"
init_topic file "UNDO_KEEP=20"
seed_rows "$DB" entries tick 5
sqlite3 "$DB" "WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i < 30)
INSERT INTO deleted_entries (content, keyword, score, deleted_at)
SELECT '/old/' || i, '', 1.0, datetime('now') FROM n;"
mkdir -p "$HOME/gone"
assert_rc "remove" 0 "$FRECENCY" file remove "$HOME/gone"
assert_rc "cleanup trims the trash table" 0 "$FRECENCY" file cleanup
assert_eq "trash trimmed to UNDO_KEEP" "20" "$(count_rows "$DB" deleted_entries)"
ok

case_begin "unbook drops the keyword but keeps the entry"
init_topic file
mkdir -p "$HOME/keepme"
"$FRECENCY" file add "$HOME/keepme" tag >/dev/null 2>&1
assert_rc "unbook" 0 "$FRECENCY" file unbook "$HOME/keepme"
assert_eq "row survives" "1" "$(count_rows "$DB" entries)"
assert_eq "keyword cleared" "0" "$(sqlite3 "$DB" "SELECT count(*) FROM entries WHERE keyword != '';")"
ok

case_begin "remove then undo restores the row"
init_topic file
mkdir -p "$HOME/undo-me"
"$FRECENCY" file add "$HOME/undo-me" >/dev/null 2>&1
assert_rc "remove" 0 "$FRECENCY" file remove "$HOME/undo-me"
assert_eq "row deleted" "0" "$(count_rows "$DB" entries)"
assert_rc "undo" 0 "$FRECENCY" file internal-op undo
assert_eq "row restored" "1" "$(count_rows "$DB" entries)"
ok

case_begin "recent validates seconds and accepts fresh paths"
init_topic file
mkdir -p "$HOME/fresh"
assert_rc "recent with non-numeric seconds" 2 "$FRECENCY" file recent abc
"$FRECENCY" file add "$HOME/fresh" >/dev/null 2>&1
assert_rc "recent 5 on a just-written path" 0 "$FRECENCY" file recent 5 "$HOME/fresh"
ok

case_begin "jump-handler: best match, multi-word, no-match, empty term"
init_topic file_dir
mkdir -p "$HOME/work/sub" "$HOME/work/other"
"$FRECENCY" file_dir add "$HOME/work/sub" >/dev/null 2>&1
"$FRECENCY" file_dir add "$HOME/work/other" >/dev/null 2>&1
assert_eq "best match" "$HOME/work/sub" \
    "$("$FRECENCY" file_dir jump-handler --emit=path sub | awk -F'\x1f' '{print $NF}')"
assert_eq "multi-word joined as one query" "$HOME/work/sub" \
    "$("$FRECENCY" file_dir jump-handler --emit=path wo su | awk -F'\x1f' '{print $NF}')"
assert_rc "no match reports and exits 1" 1 "$FRECENCY" file_dir jump-handler --emit=path nosuchthing
stub_fzf
assert_rc "empty term with stub fzf" 0 "$FRECENCY" file_dir jump-handler --emit=path
ok

case_begin "preview handles a missing path"
init_topic file
mkdir -p "$HOME/vanish"
"$FRECENCY" file add "$HOME/vanish" >/dev/null 2>&1
rmdir "$HOME/vanish"
local_out=$("$FRECENCY" file preview "$(printf '1\x1f2\x1f%s' "$HOME/vanish")" 2>&1)
assert_rc "preview rc" 0 "$FRECENCY" file preview "$(printf '1\x1f2\x1f%s' "$HOME/vanish")"
assert_contains "missing-path warning" "MISSING PATH" "$local_out"
ok

case_begin "internal-query caps rows and reports the total"
init_topic file_dir
seed_rows "$DB" dir_entries dir_tick 50
out=$("$FRECENCY" file_dir internal-query all seed 5 1)
assert_eq "header shows returned and total" "5/50 matches" "$(printf '%s\n' "$out" | head -1)"
assert_eq "five rows plus the header" "6" "$(printf '%s\n' "$out" | wc -l)"
assert_eq "limit 0 returns every match" "50" \
    "$("$FRECENCY" file_dir internal-query all seed 0 | wc -l)"
ok

case_begin "LIKE patterns are escaped in queries"
init_topic file
mkdir -p "$HOME/p"
printf 'x\n' > "$HOME/p/100%_done.txt"
printf 'x\n' > "$HOME/p/100X_done.txt"
"$FRECENCY" file add "$HOME/p/100%_done.txt" >/dev/null 2>&1
"$FRECENCY" file add "$HOME/p/100X_done.txt" >/dev/null 2>&1
assert_contains "literal percent matches only itself" "100%_done.txt" \
    "$("$FRECENCY" file internal-query all '100%')"
assert_contains "literal underscore matches only itself" "100%_done.txt" \
    "$("$FRECENCY" file internal-query all '100%_done')"
ok

case_begin "shellcheck (when available)"
if command -v "$SHELLCHECK_BIN" >/dev/null 2>&1; then
    assert_rc "shellcheck -S warning" 0 "$SHELLCHECK_BIN" -S warning \
        "$ROOT/scripts/frecency" "$ROOT/scripts/frecency-test" "$ROOT/scripts/bmark.sh" \
        "$ROOT/scripts/open_git_repo.sh" "$ROOT/scripts/bench.sh" "$ROOT/install.sh" \
        "$ROOT/shell/frecency.bash"
else
    printf '  - %s: shellcheck not installed, skipping\n' "$CURRENT_NAME"
fi
ok

# --- summary ----------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if (( FAIL > 0 )); then exit 1; fi
exit 0

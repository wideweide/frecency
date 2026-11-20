#!/bin/bash
# ============================================================================
# bench.sh - manual performance baseline for frecency (not installed, not CI)
# ============================================================================
# Usage:
#   scripts/bench.sh [ROWS ...]                 default: 110 1000 16000
#   BENCH_ROOT=/dev/shm scripts/bench.sh        use tmpfs instead of /tmp
#
# Uses a disposable HOME/XDG_DATA_HOME, seeds the directory-history table with
# the requested row counts, and times three hot paths: a write (`add`), a typed
# jump (`jump-handler --emit=path`) and a full-list reload (`internal-query`).
# Capacity pruning is disabled while measuring so the row count stays fixed.
#
# Absolute numbers are host-dependent: shell startup, filesystem fsync, CPU
# load and warm caches all matter. Use them for relative comparisons before and
# after a code change on the same machine, not as fixed targets.
# ============================================================================
set -u

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
FRECENCY="$ROOT_DIR/scripts/frecency"
ROWS_LIST=("$@")
if (( $# == 0 )); then
    ROWS_LIST=(110 1000 16000)
fi

SCRATCH=$(mktemp -d "${BENCH_ROOT:-/tmp}/frecency-bench.XXXXXX") || exit 1
trap 'rm -rf "$SCRATCH"' EXIT
export HOME="$SCRATCH/home" XDG_DATA_HOME="$SCRATCH/data"
mkdir -p "$HOME" "$XDG_DATA_HOME"
DATA="$XDG_DATA_HOME/frecency"
DB="$DATA/file.db"

"$FRECENCY" file_dir init >/dev/null 2>&1 || exit 1
SQLITE3=$( { cat "$DATA/.sqlite3.bin" 2>/dev/null || printf 'sqlite3'; } )
printf 'IGNORE_PATTERNS=()\nMAX_ENTRIES=0\n' > "$DATA/file.config"

now_ns() { date +%s%N; }

bench() { # bench <label> <iterations> <command...>
    local label=$1 iterations=$2
    shift 2
    local i start end total
    "$@" >/dev/null 2>&1          # warm up caches and the sqlite3 selector
    start=$(now_ns)
    for (( i = 0; i < iterations; i++ )); do
        "$@" >/dev/null 2>&1
    done
    end=$(now_ns)
    total=$(( (end - start) / 1000000 ))
    awk -v label="$label" -v total="$total" -v n="$iterations" \
        'BEGIN { printf "  %-36s %6d ms total  %7.1f ms/op\n", label, total, total / n }'
}

seed() { # seed <rows>
    local n=$1
    "$SQLITE3" "$DB" "
DELETE FROM dir_entries;
WITH RECURSIVE c(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM c WHERE i < $n)
INSERT INTO dir_entries (content, keyword, score, visits, tick, last_access)
SELECT '/bench/dir' || i, '', 1.0 + (i % 50) / 10.0, 1 + i % 7, i,
       datetime('now', '-' || (i % 1000) || ' days') FROM c;
UPDATE meta SET v = '$n' WHERE k = 'dir_tick';"
}

printf 'frecency bench: bash %s | sqlite3 %s | fzf %s\n' \
    "$(bash --version | head -1 | awk '{print $4}')" \
    "$("$SQLITE3" --version | awk '{print $1}')" \
    "$(fzf --version 2>/dev/null | awk '{print $1}')"
printf 'scratch: %s (override with BENCH_ROOT)\n' "$SCRATCH"

for n in "${ROWS_LIST[@]}"; do
    printf '\n== %s rows ==\n' "$n"
    seed "$n"
    bench "add: new path" 20 "$FRECENCY" file_dir add "/bench/new/$RANDOM-$n"
    bench "add: existing path" 20 "$FRECENCY" file_dir add "/bench/dir$(( n / 2 ))"
    bench "jump-handler --emit=path <term>" 20 "$FRECENCY" \
        file_dir jump-handler --emit=path "dir$(( n / 2 ))"
    bench "internal-query all (UI: 32 + header)" 20 "$FRECENCY" \
        file_dir internal-query all "" 32 1
    bench "query 'dir' unlimited" 20 "$FRECENCY" \
        file_dir internal-query all dir 0
    bench "query 'dir' limit 32" 20 "$FRECENCY" \
        file_dir internal-query all dir 32
    bench "query 'dir' limit 32 + header" 20 "$FRECENCY" \
        file_dir internal-query all dir 32 1
    printf '  rows returned: unlimited=%s, limit32=%s\n' \
        "$("$FRECENCY" file_dir internal-query all dir 0 | wc -l)" \
        "$("$FRECENCY" file_dir internal-query all dir 32 | wc -l)"
done

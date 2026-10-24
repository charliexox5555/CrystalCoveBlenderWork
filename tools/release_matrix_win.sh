#!/bin/bash
# Windows/Git Bash version of release_matrix.sh: all shards in parallel, then the merged report.
#   tools/release_matrix_win.sh [rounds per pair=8] [mode=equal] [ids] [out dir] [focus ids]
set -e
cd "$(dirname "$0")/.."
ROUNDS="${1:-8}"; MODE="${2:-equal}"; IDS="${3:-}"; OUT="${4:-${TEMP:-/tmp}/glassclash_matrix_$MODE}"; FOCUS="${5:-}"
SHARDS="${SHARDS:-$(nproc)}"
rm -rf "$OUT" && mkdir -p "$OUT"
for i in $(seq 0 $((SHARDS - 1))); do
	lune run tools/release_matrix "$i" "$SHARDS" "$ROUNDS" "$MODE" "$OUT/shard_$i.json" "$IDS" "$FOCUS" &
done
wait
lune run tools/release_matrix_report "$OUT" "$FOCUS"

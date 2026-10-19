#!/bin/zsh
# Real-swing release matrix across all cores, then the merged report.
#   tools/release_matrix.sh [rounds per pair=8] [mode=equal] [ids comma list] [out dir] [focus ids]
# Modes: equal, rarity, stars5, cast (see tools/release_matrix.luau).
set -e
cd "${0:A:h}/.."
LUNE="${LUNE:-$(command -v lune || echo $HOME/.rokit/bin/lune)}"
ROUNDS="${1:-8}"
MODE="${2:-equal}"
IDS="${3:-}"
OUT="${4:-${TMPDIR:-/tmp}/glassclash_matrix_$MODE}"
FOCUS="${5:-}"
SHARDS="${SHARDS:-$(sysctl -n hw.ncpu 2>/dev/null || nproc)}"
rm -rf "$OUT" && mkdir -p "$OUT"
for i in $(seq 0 $((SHARDS - 1))); do
	"$LUNE" run tools/release_matrix "$i" "$SHARDS" "$ROUNDS" "$MODE" "$OUT/shard_$i.json" "$IDS" "$FOCUS" &
done
wait
"$LUNE" run tools/release_matrix_report "$OUT" "$FOCUS"

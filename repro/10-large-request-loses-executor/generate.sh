#!/usr/bin/env bash
# Generates one bulk-seed SurrealQL request matching the shape that loses the
# 128 MB Earth executor (default: 200 rows per table + 600 RELATE edges in a FOR loop).
# Usage: bash generate.sh [rows] [edges]

set -euo pipefail

ROWS="${1:-200}"
EDGES="${2:-600}"

printf 'OPTION IMPORT;\n\n'

# 1. Batch INSERT into 4 tables (ROWS rows each).
printf 'INSERT INTO artist [\n'
i=1
while [ "$i" -le "$ROWS" ]; do
  sep=","
  [ "$i" -eq "$ROWS" ] && sep=""
  printf "  { id: artist:%d, name: 'Artist %d' }%s\n" "$i" "$i" "$sep"
  i=$((i + 1))
done
printf '];\n\n'

printf 'INSERT INTO album [\n'
i=1
while [ "$i" -le "$ROWS" ]; do
  sep=","
  [ "$i" -eq "$ROWS" ] && sep=""
  printf "  { id: album:%d, title: 'Album %d' }%s\n" "$i" "$i" "$sep"
  i=$((i + 1))
done
printf '];\n\n'

printf 'INSERT INTO genre [\n'
i=1
while [ "$i" -le "$ROWS" ]; do
  sep=","
  [ "$i" -eq "$ROWS" ] && sep=""
  printf "  { id: genre:%d, label: 'Genre %d' }%s\n" "$i" "$i" "$sep"
  i=$((i + 1))
done
printf '];\n\n'

printf 'INSERT INTO track [\n'
i=1
while [ "$i" -le "$ROWS" ]; do
  sep=","
  [ "$i" -eq "$ROWS" ] && sep=""
  printf "  { id: track:%d, title: 'Track Title %d', duration_s: %d }%s\n" "$i" "$i" $((180 + (i % 120))) "$sep"
  i=$((i + 1))
done
printf '];\n\n'

# 2. ~600 RELATE statements inside a single FOR loop.
printf 'FOR $edge IN [\n'
e=1
while [ "$e" -le "$EDGES" ]; do
  sep=","
  [ "$e" -eq "$EDGES" ] && sep=""
  t=$(((e - 1) % ROWS + 1))
  a=$(((e * 7 - 1) % ROWS + 1))
  ord=$(((e - 1) / ROWS + 1))
  printf "  { from_id: track:%d, to_id: artist:%d, ord: %d }%s\n" "$t" "$a" "$ord" "$sep"
  e=$((e + 1))
done
printf '] {\n'
printf '  LET $f = $edge.from_id;\n'
printf '  LET $t = $edge.to_id;\n'
printf '  RELATE $f->performed->$t SET ord = $edge.ord;\n'
printf '};\n'

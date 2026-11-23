#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/engine.sh"

echo "== 03: Replaying a RELATION table's INFO FOR TABLE fields fails on in/out =="
echo "Engine: $(engine_version)"

engine_start
engine_sql "USE NS ${ENGINE_NS}; DEFINE DATABASE fresh;" >/dev/null

echo ""
echo "--- 1. Define TYPE RELATION table on '${ENGINE_DB}' and read INFO ---"
RESP="$(engine_sql < "$SCRIPT_DIR/define.surql")"
if command -v jq >/dev/null 2>&1; then
  printf '%s\n' "$RESP" | jq '.[-1].result'
else
  printf '%s\n' "$RESP"
fi

if command -v jq >/dev/null 2>&1; then
  REPLAY_SQL="$(engine_sql "
    LET \$db = INFO FOR DB;
    LET \$tb = INFO FOR TABLE performed;
    RETURN [
      \$db.tables.track,
      \$db.tables.artist,
      \$db.tables.performed,
      \$tb.fields.in,
      \$tb.fields.out,
      \$tb.fields.role
    ];
  " | jq -r '.[-1].result | map(. + ";") | join("\n")')"
else
  REPLAY_SQL="$(cat "$SCRIPT_DIR/replay_from_info.surql")"
fi

echo ""
echo "--- 2. Replay INFO definitions verbatim onto empty database 'fresh' ---"
printf '%s\n' "$REPLAY_SQL"

echo ""
echo "--- 3. Result of replay ---"
SURREAL_DB="fresh" engine_sql "$REPLAY_SQL" | pretty_json '[.[] | select(.status == "ERR") | {status, kind, result}]'

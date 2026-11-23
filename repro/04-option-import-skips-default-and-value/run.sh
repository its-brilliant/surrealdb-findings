#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/engine.sh"

echo "== 04: OPTION IMPORT skips field DEFAULT and VALUE on a SCHEMAFULL table =="
echo "Engine: $(engine_version)"

engine_start
engine_sql < "$SCRIPT_DIR/setup.surql" >/dev/null
engine_sql < "$SCRIPT_DIR/import.surql" >/dev/null

echo ""
echo "--- Stored rows and event outbox after normal INSERT vs OPTION IMPORT ---"
engine_sql "
  RETURN {
    rows:   (SELECT * FROM ticket ORDER BY id),
    outbox: (SELECT ticket FROM outbox)
  };
" | pretty_json '.[-1].result'

echo ""
echo "--- Later ordinary UPDATE on ticket:imported (fails because created_at was left NONE) ---"
engine_sql "UPDATE ticket:imported SET subject = 'Edited Later';" | pretty_json '.[0] | {status, kind, result}'

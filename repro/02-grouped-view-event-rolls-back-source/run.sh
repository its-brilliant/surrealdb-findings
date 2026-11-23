#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/engine.sh"

echo "== 02: Event on GROUP BY view fires with NONE ids and rolls back source writes =="
echo "Engine: $(engine_version)"

engine_start

echo ""
echo "--- Part 1: What SELECT on the view returns vs what \$event / \$before / \$after hold ---"
RESP1="$(engine_sql < "$SCRIPT_DIR/inspect_payload.surql")"
if command -v jq >/dev/null 2>&1; then
  printf '%s\n' "$RESP1" | jq '.[-1].result'
else
  printf '%s\n' "$RESP1"
fi

engine_sql < "$SCRIPT_DIR/install_outbox_event.surql" >/dev/null

echo ""
echo "--- Part 2: Event calling record::id(\$after.id ?? \$before.id) rolls back CREATE / UPDATE / DELETE on source ---"
echo "CREATE on source:"
engine_sql "CREATE order_item:2 CONTENT { category: 'books', qty: 3 };" | pretty_json '.[0] | {status, kind, result}'
echo "UPDATE on source:"
engine_sql "UPDATE order_item:existing SET qty = 10;" | pretty_json '.[0] | {status, kind, result}'
echo "DELETE on source:"
engine_sql "DELETE order_item:existing;" | pretty_json '.[0] | {status, kind, result}'
echo "Source table rows afterwards (all three writes rolled back):"
engine_sql "SELECT * FROM order_item;" | pretty_json '.[0].result'

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/engine.sh
. "$SCRIPT_DIR/../lib/engine.sh"

echo "== 01: Redefining a computed view wipes its events =="
echo "Engine: $(engine_version)"

engine_start
RESP="$(engine_sql < "$SCRIPT_DIR/repro.surql")"

if command -v jq >/dev/null 2>&1; then
  printf '%s\n' "$RESP" | jq '[.[] | select(.result != null) | .result]'
else
  printf '%s\n' "$RESP"
fi

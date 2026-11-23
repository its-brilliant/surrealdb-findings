#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/engine.sh"

echo "== 05: Permission predicates (WHERE owner = \$auth.id) do not use indexes =="
echo "Engine: $(engine_version)"

engine_start
engine_sql < "$SCRIPT_DIR/setup.surql" >/dev/null
engine_sql < "$SCRIPT_DIR/seed.surql" >/dev/null

SIGNIN_RESP="$(curl -sS -X POST "${ENGINE_URL}/signin" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d "{\"ns\":\"${ENGINE_NS}\",\"db\":\"${ENGINE_DB}\",\"ac\":\"app\",\"email\":\"alice@example.com\"}")"

if command -v jq >/dev/null 2>&1; then
  RECORD_JWT="$(printf '%s\n' "$SIGNIN_RESP" | jq -r '.token')"
else
  RECORD_JWT="$(printf '%s\n' "$SIGNIN_RESP" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
fi

if [ -z "$RECORD_JWT" ] || [ "$RECORD_JWT" = "null" ]; then
  echo "error: record-user signin failed: $SIGNIN_RESP" >&2
  exit 1
fi

echo "Signed in via HTTP /signin as record user user:alice"

echo ""
echo "--- 1. EXPLAIN: SELECT * FROM note ---"
engine_sql_bearer "$RECORD_JWT" "SELECT * FROM note EXPLAIN;" | pretty_json '.[-1].result'

echo ""
echo "--- 2. EXPLAIN: SELECT * FROM note WHERE owner = \$auth ---"
engine_sql_bearer "$RECORD_JWT" "SELECT * FROM note WHERE owner = \$auth EXPLAIN;" | pretty_json '.[-1].result'

echo ""
echo "--- 3. EXPLAIN: SELECT * FROM note WHERE owner = \$auth.id ---"
engine_sql_bearer "$RECORD_JWT" "SELECT * FROM note WHERE owner = \$auth.id EXPLAIN;" | pretty_json '.[-1].result'

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/engine.sh"

echo "== 06: DEFINE INDEX ... UNIQUE CONCURRENTLY on duplicate data =="
echo "Engine: $(engine_version)"

engine_start

echo ""
echo "--- 1. Without CONCURRENTLY: DEFINE INDEX statement fails immediately with a clear error ---"
engine_sql < "$SCRIPT_DIR/sync_unique.surql" | pretty_json '.[-1] | {status, kind, result}'

echo ""
echo "--- 2. With CONCURRENTLY: DEFINE INDEX statement returns OK ---"
engine_sql < "$SCRIPT_DIR/concurrent_unique.surql" | pretty_json '.[-1] | {status, result}'

# Wait briefly for the background index build on the 2 rows to finish.
sleep 0.3

echo ""
echo "--- 3. INFO FOR TABLE contact_conc (shows index as ordinary UNIQUE, no error visible) ---"
engine_sql "INFO FOR TABLE contact_conc;" | pretty_json '.[0].result.indexes'

echo ""
echo "--- 4. INFO FOR INDEX email_uniq ON contact_conc (building.status = 'error') ---"
engine_sql "INFO FOR INDEX email_uniq ON contact_conc;" | pretty_json '.[0].result'

echo ""
echo "--- 5. Later CREATE of a brand-new unique row is refused ---"
engine_sql "CREATE contact_conc:3 CONTENT { email: 'fresh@example.com' };" | pretty_json '.[0] | {status, kind, result}'

echo ""
echo "--- 6. Even UPDATE contact_conc:2 to fix the duplicate is refused ---"
engine_sql "UPDATE contact_conc:2 SET email = 'fixed@example.com';" | pretty_json '.[0] | {status, kind, result}'

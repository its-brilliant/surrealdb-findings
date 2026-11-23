#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/engine.sh"

ROWS="${ROWS:-200}"
EDGES="${EDGES:-600}"

echo "== 10: One large request (${ROWS} rows x 4 tables + ${EDGES} RELATEs in a FOR loop) =="

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/surreal-batch-10.XXXXXX")"
engine_register_tmpdir "$WORK_DIR"
BATCH_FILE="$WORK_DIR/batch.surql"

bash "$SCRIPT_DIR/generate.sh" "$ROWS" "$EDGES" > "$BATCH_FILE"
BYTES="$(wc -c < "$BATCH_FILE" | tr -d ' ')"
echo "Generated SurrealQL payload: ${BYTES} bytes (${ROWS} rows/table, ${EDGES} RELATEs)"

echo ""
echo "--- Self-hosted contrast on local $(engine_version) ---"
engine_start
engine_sql < "$SCRIPT_DIR/schema.surql" >/dev/null
engine_sql < "$BATCH_FILE" >/dev/null
engine_sql "
  RETURN {
    tracks:  (SELECT count() FROM ONLY track GROUP ALL).count,
    artists: (SELECT count() FROM ONLY artist GROUP ALL).count,
    edges:   (SELECT count() FROM ONLY performed GROUP ALL).count
  };
" | pretty_json '.[-1].result'
engine_stop

if [ -z "${EARTH_HOST:-}" ] || [ -z "${EARTH_TOKEN:-}" ]; then
  echo ""
  echo "skip Earth request: needs EARTH_HOST and EARTH_TOKEN (succeeded on self-hosted above)"
  exit 0
fi

EARTH_NS="${EARTH_NS:-app}"
EARTH_DB="${EARTH_DB:-repro_10}"

echo ""
echo "--- Sending same single request to Earth (${EARTH_HOST}, ns=${EARTH_NS}, db=${EARTH_DB}) ---"
curl -sS -X POST "https://${EARTH_HOST}/sql" \
  -H "Authorization: Bearer ${EARTH_TOKEN}" \
  -H "Accept: application/json" \
  -H "surreal-ns: ${EARTH_NS}" \
  -H "surreal-db: ${EARTH_DB}" \
  --data-binary @"$SCRIPT_DIR/schema.surql" >/dev/null

curl -i -sS -X POST "https://${EARTH_HOST}/sql" \
  -H "Authorization: Bearer ${EARTH_TOKEN}" \
  -H "Accept: application/json" \
  -H "surreal-ns: ${EARTH_NS}" \
  -H "surreal-db: ${EARTH_DB}" \
  --data-binary @"$BATCH_FILE"
echo ""

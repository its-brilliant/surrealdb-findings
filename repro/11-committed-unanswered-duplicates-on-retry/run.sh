#!/usr/bin/env bash
# Shows how a retry after `502 committed_unanswered` on Earth duplicates RELATE edges.
# Reads EARTH_HOST and EARTH_TOKEN from the environment; does nothing when unset.

set -euo pipefail

if [ -z "${EARTH_HOST:-}" ] || [ -z "${EARTH_TOKEN:-}" ]; then
  echo "skip: needs EARTH_HOST and EARTH_TOKEN (observed on Earth; not run locally)"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EARTH_NS="${EARTH_NS:-app}"
EARTH_DB="${EARTH_DB:-repro_11}"

# When the first POST commits on the executor but the gateway loses the reply
# (`502 committed_unanswered`), a naive HTTP retry runs the same batch a second
# time and writes a duplicate `performed` edge.
curl -i -sS -X POST "https://${EARTH_HOST}/sql" \
  -H "Authorization: Bearer ${EARTH_TOKEN}" \
  -H "Accept: application/json" \
  -H "surreal-ns: ${EARTH_NS}" \
  -H "surreal-db: ${EARTH_DB}" \
  --data-binary @"$SCRIPT_DIR/batch.surql"
echo ""

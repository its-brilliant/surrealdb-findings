#!/usr/bin/env bash
# Reproduces Cloudflare Error 1010 on Earth when User-Agent is empty / default urllib.
# Reads EARTH_HOST and EARTH_TOKEN from the environment; does nothing when unset.

set -euo pipefail

if [ -z "${EARTH_HOST:-}" ] || [ -z "${EARTH_TOKEN:-}" ]; then
  echo "skip: needs EARTH_HOST and EARTH_TOKEN (observed on Earth; not run locally)"
  exit 0
fi

EARTH_NS="${EARTH_NS:-app}"
EARTH_DB="${EARTH_DB:-main}"

echo "--- 1. Without User-Agent (-A ''): blocked with 403 Error 1010 ---"
curl -i -sS -A '' -X POST "https://${EARTH_HOST}/sql" \
  -H "Authorization: Bearer ${EARTH_TOKEN}" \
  -H "Accept: application/json" \
  -H "surreal-ns: ${EARTH_NS}" \
  -H "surreal-db: ${EARTH_DB}" \
  --data-binary "RETURN 1;"
echo ""

echo "--- 2. With User-Agent set: succeeds with 200 OK ---"
curl -i -sS -A 'surreal-repro/1.0' -X POST "https://${EARTH_HOST}/sql" \
  -H "Authorization: Bearer ${EARTH_TOKEN}" \
  -H "Accept: application/json" \
  -H "surreal-ns: ${EARTH_NS}" \
  -H "surreal-db: ${EARTH_DB}" \
  --data-binary "RETURN 1;"
echo ""

#!/usr/bin/env bash
# Inspect cluster states and disabled_cause across an organisation via the Cloud API.
# Reads CLOUD_TOKEN and ORG_ID from the environment; does nothing when unset.

set -euo pipefail

if [ -z "${CLOUD_TOKEN:-}" ] || [ -z "${ORG_ID:-}" ]; then
  echo "skip: needs EARTH_HOST / CLOUD_TOKEN and ORG_ID (observed on Earth; not run locally)"
  exit 0
fi

RESP="$(curl -sS \
  -H "Authorization: Bearer ${CLOUD_TOKEN}" \
  -H "Accept: application/json" \
  "https://api.surrealdb.com/api/cloud/v0/organizations/${ORG_ID}/clusters")"

if command -v jq >/dev/null 2>&1; then
  printf '%s\n' "$RESP" | jq '.items | map({id, name, state, disabled_cause})'
else
  printf '%s\n' "$RESP"
fi

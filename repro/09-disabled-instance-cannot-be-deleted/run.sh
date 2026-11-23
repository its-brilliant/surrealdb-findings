#!/usr/bin/env bash
# Attempt DELETE on a disabled Earth cluster via the Cloud API.
# Reads CLOUD_TOKEN, ORG_ID, and CLUSTER_ID from the environment; does nothing when unset.

set -euo pipefail

if [ -z "${CLOUD_TOKEN:-}" ] || [ -z "${ORG_ID:-}" ] || [ -z "${CLUSTER_ID:-}" ]; then
  echo "skip: needs EARTH_HOST / CLOUD_TOKEN, ORG_ID, and CLUSTER_ID (observed on Earth; not run locally)"
  exit 0
fi

curl -i -sS -X DELETE \
  -H "Authorization: Bearer ${CLOUD_TOKEN}" \
  -H "Accept: application/json" \
  "https://api.surrealdb.com/api/cloud/v0/organizations/${ORG_ID}/clusters/${CLUSTER_ID}"
echo ""

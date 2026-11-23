#!/usr/bin/env bash
# Inspects the replica count of a Cloud API-created Earth cluster and shows the
# PATCH .../clusters/{id}/resources/{rid} payload used to enable autoscaling (100).
# Reads CLOUD_TOKEN, ORG_ID, and CLUSTER_ID from the environment; does nothing when unset.

set -euo pipefail

if [ -z "${CLOUD_TOKEN:-}" ] || [ -z "${ORG_ID:-}" ] || [ -z "${CLUSTER_ID:-}" ]; then
  echo "skip: needs EARTH_HOST / CLOUD_TOKEN, ORG_ID, and CLUSTER_ID (observed on Earth; not run locally)"
  exit 0
fi

echo "--- Current cluster resources ---"
RESP="$(curl -sS \
  -H "Authorization: Bearer ${CLOUD_TOKEN}" \
  -H "Accept: application/json" \
  "https://api.surrealdb.com/api/cloud/v0/organizations/${ORG_ID}/clusters/${CLUSTER_ID}")"

if command -v jq >/dev/null 2>&1; then
  printf '%s\n' "$RESP" | jq '{id, name, state, resources}'
else
  printf '%s\n' "$RESP"
fi

if [ -n "${RESOURCE_ID:-}" ] && [ -n "${TARGET_REPLICAS:-}" ]; then
  echo "--- Resizing resource ${RESOURCE_ID} to replicas=${TARGET_REPLICAS} ---"
  curl -sS -X PATCH \
    -H "Authorization: Bearer ${CLOUD_TOKEN}" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "{\"replicas\": ${TARGET_REPLICAS}}" \
    "https://api.surrealdb.com/api/cloud/v0/organizations/${ORG_ID}/clusters/${CLUSTER_ID}/resources/${RESOURCE_ID}"
  echo ""
fi

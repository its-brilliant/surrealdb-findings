#!/usr/bin/env bash
# Sends a write request to the Cloud API with $CLOUD_TOKEN to show scope handling.
# Without `write:cloud-instances`, every non-GET route returns `403 Insufficient scopes`
# even before validating the payload, without naming the missing scope.
# Reads CLOUD_TOKEN and ORG_ID from the environment; does nothing when unset.

set -euo pipefail

if [ -z "${CLOUD_TOKEN:-}" ] || [ -z "${ORG_ID:-}" ]; then
  echo "skip: needs EARTH_HOST / CLOUD_TOKEN and ORG_ID (observed on Earth; not run locally)"
  exit 0
fi

# Deliberately send an empty JSON body so an authorized token gets 400 invalid_argument
# (without creating a cluster), while a token missing `write:cloud-instances` gets 403.
curl -i -sS -X POST \
  -H "Authorization: Bearer ${CLOUD_TOKEN}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{}' \
  "https://api.surrealdb.com/api/cloud/v0/organizations/${ORG_ID}/clusters"
echo ""

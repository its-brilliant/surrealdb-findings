#!/usr/bin/env bash
# Compares the local SurrealDB engine version against an Earth instance's /version.
# Reads EARTH_HOST from the environment; does nothing against Earth when unset.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/engine.sh"

echo "Local engine version: $(engine_version)"

if [ -z "${EARTH_HOST:-}" ]; then
  echo "skip: needs EARTH_HOST (observed surrealdb-4.0.0 on Earth; not run remotely)"
  exit 0
fi

printf 'Earth /version (%s): ' "$EARTH_HOST"
curl -sS "https://${EARTH_HOST}/version"
echo ""

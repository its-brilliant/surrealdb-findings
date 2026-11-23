#!/usr/bin/env bash
# Tests WebSocket upgrade reachability to wss://$EARTH_HOST/rpc.
# Reads EARTH_HOST from the environment; does nothing when unset.

set -euo pipefail

if [ -z "${EARTH_HOST:-}" ]; then
  echo "skip: needs EARTH_HOST (observed on Earth from customer corporate networks; not run locally)"
  exit 0
fi

# Perform an HTTP/1.1 WebSocket upgrade handshake check against /rpc.
# On affected corporate networks / DNS filters, *.surrealdb.earth is dropped or refused.
KEY="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n' | cut -c1-24)"
curl -i -sS --http1.1 --max-time 10 \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: ${KEY}" \
  "https://${EARTH_HOST}/rpc" | head -n 20

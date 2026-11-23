#!/usr/bin/env bash
# Throwaway in-memory SurrealDB helper for local reproductions.
# Needs only `surreal`, `curl`, and optionally `jq`.

set -euo pipefail

if [ -z "${SURREAL_BIN:-}" ]; then
  if command -v surreal >/dev/null 2>&1; then
    SURREAL_BIN="surreal"
  elif [ -x "$HOME/.surrealdb/surreal" ]; then
    SURREAL_BIN="$HOME/.surrealdb/surreal"
  else
    echo "error: surreal binary not found; set SURREAL_BIN=/path/to/surreal" >&2
    exit 1
  fi
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "error: curl is required" >&2
  exit 1
fi

ENGINE_PID=""
ENGINE_TMPDIR=""
ENGINE_PORT=""
ENGINE_URL=""
ENGINE_USER="root"
ENGINE_PASS=""
ENGINE_NS="test"
ENGINE_DB="test"
ENGINE_EXTRA_DIRS=""

engine_register_tmpdir() {
  if [ -z "$ENGINE_EXTRA_DIRS" ]; then
    ENGINE_EXTRA_DIRS="$1"
  else
    ENGINE_EXTRA_DIRS="$ENGINE_EXTRA_DIRS:$1"
  fi
}

engine_stop() {
  if [ -n "${ENGINE_PID:-}" ] && kill -0 "$ENGINE_PID" 2>/dev/null; then
    kill "$ENGINE_PID" 2>/dev/null || true
    wait "$ENGINE_PID" 2>/dev/null || true
  fi
  ENGINE_PID=""
}

engine_cleanup() {
  engine_stop
  if [ -n "${ENGINE_TMPDIR:-}" ] && [ -d "$ENGINE_TMPDIR" ]; then
    rm -rf "$ENGINE_TMPDIR"
  fi
  if [ -n "${ENGINE_EXTRA_DIRS:-}" ]; then
    OLD_IFS="$IFS"
    IFS=":"
    for d in $ENGINE_EXTRA_DIRS; do
      if [ -n "$d" ] && [ -d "$d" ]; then
        rm -rf "$d"
      fi
    done
    IFS="$OLD_IFS"
  fi
}

trap engine_cleanup EXIT INT TERM

engine_random_hex() {
  od -An -N16 -tx1 /dev/urandom | tr -d ' \n'
}

engine_start() {
  engine_stop
  if [ -z "${ENGINE_TMPDIR:-}" ] || [ ! -d "$ENGINE_TMPDIR" ]; then
    ENGINE_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/surreal-repro.XXXXXX")"
  fi
  ENGINE_PASS="$(engine_random_hex)"

  local attempt=0
  while [ "$attempt" -lt 25 ]; do
    attempt=$((attempt + 1))
    local rand
    rand="$(od -An -N2 -tu2 /dev/urandom | tr -d ' \n')"
    ENGINE_PORT=$((20000 + (rand % 40000)))
    ENGINE_URL="http://127.0.0.1:${ENGINE_PORT}"

    "$SURREAL_BIN" start memory \
      --bind "127.0.0.1:${ENGINE_PORT}" \
      --user "$ENGINE_USER" \
      --pass "$ENGINE_PASS" \
      --log warn \
      "$@" >"$ENGINE_TMPDIR/surreal.log" 2>&1 &
    ENGINE_PID=$!

    local ticks=0
    while [ "$ticks" -lt 100 ]; do
      if ! kill -0 "$ENGINE_PID" 2>/dev/null; then
        wait "$ENGINE_PID" 2>/dev/null || true
        ENGINE_PID=""
        break
      fi
      if curl -fsS "${ENGINE_URL}/health" >/dev/null 2>&1; then
        engine_sql "DEFINE NAMESPACE IF NOT EXISTS ${ENGINE_NS}; USE NS ${ENGINE_NS}; DEFINE DATABASE IF NOT EXISTS ${ENGINE_DB};" >/dev/null
        return 0
      fi
      sleep 0.05
      ticks=$((ticks + 1))
    done
    engine_stop
  done

  echo "error: failed to start surreal on a free port" >&2
  if [ -f "$ENGINE_TMPDIR/surreal.log" ]; then
    cat "$ENGINE_TMPDIR/surreal.log" >&2
  fi
  return 1
}

engine_version() {
  "$SURREAL_BIN" db version 2>/dev/null || "$SURREAL_BIN" version 2>/dev/null
}

engine_sql() {
  local ns="${SURREAL_NS:-$ENGINE_NS}"
  local db="${SURREAL_DB:-$ENGINE_DB}"
  if [ "$#" -gt 0 ]; then
    printf '%s\n' "$1" | curl -sS -X POST "${ENGINE_URL}/sql" \
      -u "${ENGINE_USER}:${ENGINE_PASS}" \
      -H "Accept: application/json" \
      -H "surreal-ns: ${ns}" \
      -H "surreal-db: ${db}" \
      --data-binary @-
  else
    curl -sS -X POST "${ENGINE_URL}/sql" \
      -u "${ENGINE_USER}:${ENGINE_PASS}" \
      -H "Accept: application/json" \
      -H "surreal-ns: ${ns}" \
      -H "surreal-db: ${db}" \
      --data-binary @-
  fi
}

engine_sql_bearer() {
  local token="$1"
  shift
  local ns="${SURREAL_NS:-$ENGINE_NS}"
  local db="${SURREAL_DB:-$ENGINE_DB}"
  if [ "$#" -gt 0 ]; then
    printf '%s\n' "$1" | curl -sS -X POST "${ENGINE_URL}/sql" \
      -H "Authorization: Bearer ${token}" \
      -H "Accept: application/json" \
      -H "surreal-ns: ${ns}" \
      -H "surreal-db: ${db}" \
      --data-binary @-
  else
    curl -sS -X POST "${ENGINE_URL}/sql" \
      -H "Authorization: Bearer ${token}" \
      -H "Accept: application/json" \
      -H "surreal-ns: ${ns}" \
      -H "surreal-db: ${db}" \
      --data-binary @-
  fi
}

pretty_json() {
  if command -v jq >/dev/null 2>&1; then
    jq "$@"
  else
    cat
  fi
}

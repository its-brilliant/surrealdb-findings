#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/engine.sh"

echo "== 07: surreal kit sync applies database/schema/*.surql in filename order =="
echo "Engine:     $(engine_version)"
echo "SurrealKit: $("$SURREAL_BIN" kit --version)"

engine_start
engine_sql "USE NS ${ENGINE_NS}; DEFINE DATABASE db_alpha; DEFINE DATABASE db_renamed;" >/dev/null

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/surrealkit-07.XXXXXX")"
engine_register_tmpdir "$WORK_DIR"
cp -R "$SCRIPT_DIR/surrealkit.toml" "$SCRIPT_DIR/database" "$WORK_DIR/"

echo ""
echo "--- 1. Sync with a_view.surql + b_source.surql (view sorts alphabetically before source) ---"
set +e
(
  cd "$WORK_DIR"
  "$SURREAL_BIN" kit sync \
    --host "$ENGINE_URL" \
    --ns "$ENGINE_NS" \
    --db "db_alpha" \
    --user "$ENGINE_USER" \
    --pass "$ENGINE_PASS" \
    --auth-level root 2>&1
)
STATUS=$?
set -e
echo "(exit code: $STATUS)"
if [ "$STATUS" -eq 0 ]; then
  echo "error: expected surreal kit sync to fail when a_view.surql precedes b_source.surql" >&2
  exit 1
fi

echo ""
echo "--- 2. Rename a_view.surql -> z_view.surql (identical contents) and sync again ---"
mv "$WORK_DIR/database/schema/a_view.surql" "$WORK_DIR/database/schema/z_view.surql"
(
  cd "$WORK_DIR"
  "$SURREAL_BIN" kit sync \
    --host "$ENGINE_URL" \
    --ns "$ENGINE_NS" \
    --db "db_renamed" \
    --user "$ENGINE_USER" \
    --pass "$ENGINE_PASS" \
    --auth-level root 2>&1
)

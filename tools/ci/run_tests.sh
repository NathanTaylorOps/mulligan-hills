#!/usr/bin/env bash
# Run gdUnit4 headless. Env: TEST_PATH (default res://tests), GAME_PATH, GODOT_BIN.
# Produces $OUT_DIR/tests/{test.log,junit/**/results.xml,hashes.txt}. Exit 1 on any
# failure, on zero tests, or on a gdUnit4 exit code other than 0 / 101 (101 = warnings).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
TEST_PATH="${TEST_PATH:-res://}"
T="$OUT_DIR/tests"; mkdir -p "$T"
rm -rf "$GAME_DIR/reports"
log "running gdUnit4 on $TEST_PATH"
set +e
"$GODOT_BIN" --headless --path "$GAME_DIR" -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode -a "$TEST_PATH" -rd res://reports -rc 3 -c 2>&1 | tee "$T/test.log"
rc="${PIPESTATUS[0]}"
set -e
log "gdUnit4 exit code: $rc"
mkdir -p "$T/junit"
if [ -d "$GAME_DIR/reports" ]; then cp -R "$GAME_DIR/reports/." "$T/junit/"; fi

# Deterministic-sim hash lines printed by tests: MH_HASH:<label>=<hex>
grep -aoE 'MH_HASH:[A-Za-z0-9_.:-]+=[0-9A-Fa-f]+' "$T/test.log" | sort -u > "$T/hashes.txt" || true
log "hash lines captured: $(wc -l < "$T/hashes.txt" | tr -d ' ')"

set +e
"$CI_DIR/junit_summary.sh" "$T/junit"
sc=$?
set -e
if [ "$sc" -ne 0 ]; then exit "$sc"; fi
case "$rc" in
  0|101) exit 0 ;;
  *) echo "gdUnit4 exited with code $rc but JUnit shows no failures: treating as failure" | summary; exit 1 ;;
esac

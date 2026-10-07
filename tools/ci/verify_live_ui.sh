#!/usr/bin/env bash
# Run the isolated saved-course probe after import. Requires GNU timeout (CI: Ubuntu).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
mkdir -p "$OUT_DIR"
log "verifying EDIT -> BUILD -> PLAY -> SAVE -> RELOAD"
set +e
timeout 240s "$GODOT_BIN" --headless --path "$GAME_DIR" \
  --script res://tests/manual_verify_live_ui.gd 2>&1 | tee "$OUT_DIR/live-ui.log"
rc="${PIPESTATUS[0]}"
set -e
[ "$rc" -eq 0 ] || die "live UI probe exited with code $rc (124 means timeout)"
if grep -Eq 'SCRIPT ERROR|Parse Error|LIVE_UI_PROBE FAIL:' "$OUT_DIR/live-ui.log"; then
  die "live UI probe reported an engine or assertion error"
fi
grep -q '^LIVE_UI_PROBE PASS:' "$OUT_DIR/live-ui.log" || die "live UI probe did not report PASS"

#!/usr/bin/env bash
# Headless import so .godot/ caches, class names and resources exist before tests/exports.
# Godot's first import often exits non-zero for benign reasons, so run it twice and judge
# the second run by scanning the log for parse/script errors instead of the exit code.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
mkdir -p "$OUT_DIR"
"$CI_DIR/ensure_icon.sh"
[ -f "$GAME_DIR/project.godot" ] || die "no project.godot in $GAME_DIR"
logf="$OUT_DIR/import.log"
set +e
"$GODOT_BIN" --headless --path "$GAME_DIR" --import > "$OUT_DIR/import-1.log" 2>&1
"$GODOT_BIN" --headless --path "$GAME_DIR" --import > "$logf" 2>&1
rc=$?
set -e
cat "$OUT_DIR/import-1.log" "$logf" | tail -n 80 >&2
log "second import exit code: $rc"
if grep -E "SCRIPT ERROR|Parse Error|Failed to load script|Could not parse global class" "$logf" > "$OUT_DIR/import-errors.txt"; then
  {
    echo "### Import errors"
    echo '```'
    head -n 40 "$OUT_DIR/import-errors.txt"
    echo '```'
  } | summary
  die "GDScript/import errors found (see import.log)"
fi
[ "$rc" -eq 0 ] || log "WARNING: non-zero exit but no script errors detected; continuing"

# --import does not guarantee that every GDScript file is parsed. One extra Godot process loads every first-party
# script resource, which catches untouched parse/type-load failures without starting hundreds of engine processes.
check_errors="$OUT_DIR/gdscript-check-errors.txt"
check_log="$OUT_DIR/gdscript-check.log"
set +e
"$GODOT_BIN" --headless --path "$GAME_DIR" --script res://tests/ci/check_project_scripts.gd > "$check_log" 2>&1
script_rc=$?
set -e
if [ "$script_rc" -ne 0 ] || grep -Eq "SCRIPT_CHECK FAIL:|SCRIPT ERROR|Parse Error|Failed to load script|Could not parse global class" "$check_log"; then
  cp "$check_log" "$check_errors"
  {
    echo "### GDScript parse/load errors"
    head -n 80 "$check_errors"
  } | summary
  die "GDScript check failed (see gdscript-check-errors.txt)"
fi

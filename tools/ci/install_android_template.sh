#!/usr/bin/env bash
# Install the Godot Android gradle build template into <game>/android/build, the same
# thing the editor does for "Project > Install Android Build Template".
# UNVERIFIED for 4.7.x: relies on templates/android_source.zip and android/.build_version.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
troot="$(template_root)/$GODOT_TEMPLATE_DIRNAME"
zip="$troot/android_source.zip"
[ -f "$zip" ] || die "android_source.zip not found in $troot (run setup_templates.sh with android)"
rm -rf "$GAME_DIR/android/build"
mkdir -p "$GAME_DIR/android/build"
extract_zip "$zip" "$GAME_DIR/android/build"
touch "$GAME_DIR/android/build/.gdignore"
printf '%s' "$GODOT_TEMPLATE_DIRNAME" > "$GAME_DIR/android/.build_version"
log "android build template installed at $GAME_DIR/android/build"
ls "$GAME_DIR/android/build" >&2

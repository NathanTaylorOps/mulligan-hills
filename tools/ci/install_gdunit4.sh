#!/usr/bin/env bash
# Download the pinned gdUnit4 release and install addons/gdUnit4 into the game project.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
target="$GAME_DIR/addons/gdUnit4"
if [ -f "$target/plugin.cfg" ]; then log "gdUnit4 already present in $target"; exit 0; fi
mkdir -p "$GODOT_CACHE_DIR/dl"
zip="$GODOT_CACHE_DIR/dl/gdunit4-$GDUNIT4_VERSION.zip"
[ -f "$zip" ] || download "https://github.com/$GDUNIT4_REPO/archive/refs/tags/$GDUNIT4_VERSION.zip" "$zip"
tmp="$(mktemp -d)"
extract_zip "$zip" "$tmp" "*/addons/gdUnit4/*"
src="$(find "$tmp" -type d -path '*/addons/gdUnit4' | head -n1)"
[ -n "$src" ] || die "addons/gdUnit4 not found inside $zip"
mkdir -p "$GAME_DIR/addons"
cp -R "$src" "$GAME_DIR/addons/"
rm -rf "$tmp"
[ -f "$target/plugin.cfg" ] || die "gdUnit4 install failed"
log "gdUnit4 $GDUNIT4_VERSION installed"
grep -E '^version' "$target/plugin.cfg" >&2 || true

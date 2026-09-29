#!/usr/bin/env bash
# Download + checksum-verify the pinned Godot editor binary for this runner OS.
# Exports GODOT_BIN via $GITHUB_ENV (and prints it). Idempotent (cache friendly).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
mkdir -p "$OUT_DIR"

os="$(detect_os)"
dest="$GODOT_CACHE_DIR/editor-$GODOT_FULL-$os"
case "$os" in
  linux)   asset="Godot_v${GODOT_FULL}_linux.x86_64.zip";  bin_rel="Godot_v${GODOT_FULL}_linux.x86_64"; pin="$GODOT_SHA512_LINUX" ;;
  macos)   asset="Godot_v${GODOT_FULL}_macos.universal.zip"; bin_rel="Godot.app/Contents/MacOS/Godot"; pin="$GODOT_SHA512_MACOS" ;;
  windows) asset="Godot_v${GODOT_FULL}_win64.exe.zip";     bin_rel="Godot_v${GODOT_FULL}_win64_console.exe"; pin="$GODOT_SHA512_WINDOWS" ;;
esac

if [ ! -e "$dest/$bin_rel" ]; then
  mkdir -p "$dest" "$GODOT_CACHE_DIR/dl"
  download "$GODOT_RELEASE_URL/SHA512-SUMS.txt" "$GODOT_CACHE_DIR/dl/SHA512-SUMS.txt"
  download "$GODOT_RELEASE_URL/$asset" "$GODOT_CACHE_DIR/dl/$asset"
  verify_sha512 "$GODOT_CACHE_DIR/dl/$asset" "$asset" "$GODOT_CACHE_DIR/dl/SHA512-SUMS.txt" "$pin"
  extract_zip "$GODOT_CACHE_DIR/dl/$asset" "$dest"
  rm -f "$GODOT_CACHE_DIR/dl/$asset"
else
  log "Godot editor cache hit: $dest"
fi

GODOT_BIN="$dest/$bin_rel"
chmod +x "$GODOT_BIN" 2>/dev/null || true
[ -e "$GODOT_BIN" ] || die "binary missing after extraction: $GODOT_BIN"
if [ -n "${GITHUB_ENV:-}" ]; then echo "GODOT_BIN=$GODOT_BIN" >> "$GITHUB_ENV"; fi
echo "$GODOT_BIN"
"$GODOT_BIN" --headless --version || die "Godot failed to start"

#!/usr/bin/env bash
# Download + verify export templates and install them where the editor looks.
# TEMPLATE_PLATFORMS (space separated, default "android linux windows ios macos")
# limits what is extracted: the full .tpz is large.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
mkdir -p "$OUT_DIR"
plats="${TEMPLATE_PLATFORMS:-android linux windows ios macos}"

sig="$(echo "$plats" | tr ' ' '_')"
stage="$GODOT_CACHE_DIR/templates-$GODOT_FULL-$sig"
asset="Godot_v${GODOT_FULL}_export_templates.tpz"

if [ ! -f "$stage/.ok" ]; then
  rm -rf "$stage"; mkdir -p "$stage" "$GODOT_CACHE_DIR/dl"
  download "$GODOT_RELEASE_URL/SHA512-SUMS.txt" "$GODOT_CACHE_DIR/dl/SHA512-SUMS.txt"
  download "$GODOT_RELEASE_URL/$asset" "$GODOT_CACHE_DIR/dl/$asset"
  verify_sha512 "$GODOT_CACHE_DIR/dl/$asset" "$asset" "$GODOT_CACHE_DIR/dl/SHA512-SUMS.txt" "$GODOT_SHA512_TEMPLATES"
  globs="templates/version.txt templates/*.md templates/LICENSE*"
  for p in $plats; do
    case "$p" in
      android) globs="$globs templates/android_*" ;;
      linux)   globs="$globs templates/linux_*" ;;
      windows) globs="$globs templates/windows_*" ;;
      ios)     globs="$globs templates/ios.zip" ;;
      macos)   globs="$globs templates/macos.zip" ;;
      web)     globs="$globs templates/web_*" ;;
      *) die "unknown template platform $p" ;;
    esac
  done
  # shellcheck disable=SC2086
  extract_zip "$GODOT_CACHE_DIR/dl/$asset" "$stage" $globs
  rm -f "$GODOT_CACHE_DIR/dl/$asset"
  [ -f "$stage/templates/version.txt" ] || die "templates/version.txt missing in tpz (layout changed?)"
  touch "$stage/.ok"
else
  log "template cache hit: $stage"
fi

ver="$(tr -d '\r\n' < "$stage/templates/version.txt")"
[ "$ver" = "$GODOT_TEMPLATE_DIRNAME" ] || log "WARNING: version.txt says '$ver' but versions.env says '$GODOT_TEMPLATE_DIRNAME'; using version.txt"
target="$(template_root)/$ver"
mkdir -p "$target"
cp -R "$stage/templates/." "$target/"
log "templates installed to: $target"
ls -la "$target" >&2
echo "$target"

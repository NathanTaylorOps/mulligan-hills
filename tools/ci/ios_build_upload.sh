#!/usr/bin/env bash
# macOS only. Export the project as an Xcode project with Godot, archive it with
# xcodebuild using cloud-managed signing through an App Store Connect API key, and upload
# the result to TestFlight (exportOptions destination=upload).
# Env (all required): GODOT_BIN, APPLE_TEAM_ID, ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8_B64
# Optional: MH_PACKAGE_ID, MH_VERSION_CODE, MH_VERSION_NAME, DRY_RUN=1 (skip the upload:
#           only archive and export locally, useful to test signing without publishing).
# UNVERIFIED: never run. The iOS path is the most likely to need a fix on first run.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
[ "$(detect_os)" = macos ] || die "iOS build needs a macOS runner"
: "${APPLE_TEAM_ID:?}" "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_P8_B64:?}"
export MH_APPLE_TEAM_ID="$APPLE_TEAM_ID"

W="$OUT_DIR/ios"; rm -rf "$W"; mkdir -p "$W"
keydir="${RUNNER_TEMP:-/tmp}/asc"; mkdir -p "$keydir"
key="$keydir/AuthKey_${ASC_KEY_ID}.p8"
umask 077
echo "$ASC_KEY_P8_B64" | base64 --decode > "$key"
[ -s "$key" ] || die "API key decoded to an empty file: check the ASC_KEY_P8_B64 secret"
umask 022

"$CI_DIR/ensure_icon.sh"
"$CI_DIR/render_export_presets.sh"
xcodebuild -version | tee "$W/xcode-version.txt" >&2

log "godot export (Xcode project only)"
set +e
"$GODOT_BIN" --headless --path "$GAME_DIR" --export-release "iOS" "$W/MulliganHills.ipa" 2>&1 | tee "$W/godot-export.log"
set -e
proj="$(find "$W" -maxdepth 2 -name '*.xcodeproj' -type d | head -n1)"
[ -n "$proj" ] || die "Godot produced no .xcodeproj (see godot-export.log)"
scheme="$(basename "$proj" .xcodeproj)"
log "project=$proj scheme=$scheme"

auth=(-allowProvisioningUpdates -authenticationKeyPath "$key" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")

xcodebuild archive -project "$proj" -scheme "$scheme" -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$W/app.xcarchive" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" CODE_SIGN_STYLE=Automatic "${auth[@]}" 2>&1 | tee "$W/archive.log" | tail -n 60 >&2
[ -d "$W/app.xcarchive" ] || die "archive failed (see archive.log artifact)"

dest=upload; [ "${DRY_RUN:-0}" = 1 ] && dest=export
cat > "$W/ExportOptions.plist" <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>$dest</string>
  <key>teamID</key><string>$APPLE_TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><true/>
</dict></plist>
EOT
xcodebuild -exportArchive -archivePath "$W/app.xcarchive" -exportPath "$W/export" \
  -exportOptionsPlist "$W/ExportOptions.plist" "${auth[@]}" 2>&1 | tee "$W/export.log" | tail -n 60 >&2
rm -f "$key"
if [ "$dest" = upload ]; then
  echo "### iOS upload finished. Build should appear in TestFlight after Apple processing (usually 5 to 30 minutes)." | summary
else
  echo "### iOS dry run finished (nothing uploaded)." | summary
fi

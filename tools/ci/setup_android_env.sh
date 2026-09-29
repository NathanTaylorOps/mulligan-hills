#!/usr/bin/env bash
# Prepare a runner for Godot Android exports (Linux). Requires JAVA_HOME (setup-java).
#  1. installs Android SDK packages listed in versions.env via sdkmanager
#  2. writes Godot editor settings pointing at the SDK and JDK
#  3. provides a debug keystore (from secret ANDROID_DEBUG_KEYSTORE_B64 if set, else a
#     freshly generated one) and exports the GODOT_ANDROID_KEYSTORE_DEBUG_* variables
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
[ -n "${JAVA_HOME:-}" ] || die "JAVA_HOME not set (use actions/setup-java)"
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}}"
[ -d "$sdk" ] || die "Android SDK not found at $sdk"
sm="$sdk/cmdline-tools/latest/bin/sdkmanager"
if [ ! -x "$sm" ]; then sm="$(find "$sdk/cmdline-tools" -name sdkmanager -type f 2>/dev/null | head -n1)"; fi
[ -x "$sm" ] || die "sdkmanager not found under $sdk/cmdline-tools"

log "accepting licenses"
yes | "$sm" --sdk_root="$sdk" --licenses >/dev/null 2>&1 || true
log "installing: $ANDROID_SDK_PACKAGES"
# shellcheck disable=SC2086
"$sm" --sdk_root="$sdk" $ANDROID_SDK_PACKAGES >&2 || die "sdkmanager failed"
"$sm" --sdk_root="$sdk" --list_installed >&2 || true

es="$(editor_settings_dir)"; mkdir -p "$es"
for f in editor_settings-4.tres "editor_settings-${GODOT_VERSION%.*}.tres"; do
  cat > "$es/$f" <<EOT
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$sdk"
export/android/java_sdk_path = "$JAVA_HOME"
EOT
done
log "editor settings written to $es"

ks_dir="${RUNNER_TEMP:-/tmp}/mh-keystore"; mkdir -p "$ks_dir"
ks="$ks_dir/debug.keystore"
if [ -n "${ANDROID_DEBUG_KEYSTORE_B64:-}" ]; then
  echo "$ANDROID_DEBUG_KEYSTORE_B64" | base64 --decode > "$ks"
  log "using debug keystore from secret (stable signature: updates install over old builds)"
else
  "$JAVA_HOME/bin/keytool" -genkeypair -v -keystore "$ks" -alias androiddebugkey -keyalg RSA \
    -keysize 2048 -validity 10000 -storepass android -keypass android \
    -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1 || die "keytool failed"
  log "generated a throwaway debug keystore (uninstall the old build before installing a new one)"
fi
if [ -n "${GITHUB_ENV:-}" ]; then
  {
    echo "ANDROID_HOME=$sdk"
    echo "ANDROID_SDK_ROOT=$sdk"
    echo "GODOT_ANDROID_KEYSTORE_DEBUG_PATH=$ks"
    echo "GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey"
    echo "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android"
  } >> "$GITHUB_ENV"
fi

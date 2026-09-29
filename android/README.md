# android/ : Mulligan Hills Android platform notes

Status: SOURCE AND NOTES ONLY. Nothing here has been compiled or run. See `docs/phase0/platform.md`.

## Contents
- `plugin/` : Kotlin Godot plugin (`MHPlayIntegrity`) for Play Integrity standard requests, plus `addon_template/`.
- `manifest/AndroidManifest_additions.xml` : what the merged manifest must contain.
- `proguard-rules.pro` : R8 keep rules if minification is enabled.

## 1. Gradle notes (Godot custom build)
1. Play Billing, Play Games Services and our plugin are AARs. They need Godot's **Gradle (custom) build**:
   Godot editor > Project > Install Android Build Template. This creates `game/android/build/`.
   (Do not confuse it with this repo-level `android/` folder, which holds our plugin source.)
2. Export preset (Android) settings that matter (names as in Godot 4.x, exact labels UNVERIFIED for the pinned version):
   - Gradle Build > Use Gradle Build: ON
   - Gradle Build > Export Format: **Android App Bundle (.aab)** for Play uploads; APK only for local device installs
   - Architectures: arm64-v8a ON (armeabi-v7a optional; needed only if you support very old 32-bit phones)
   - Gradle Build > Min SDK / Target SDK: **Target SDK must be 36** for any new app or update submitted from
     2026-08-31 (extension to 2026-11-01 possible). Source: https://support.google.com/googleplay/android-developer/answer/11926878
     The pinned Godot version (docs/GODOT_VERSION.md) must be able to target 36: UNVERIFIED, check its release notes.
   - Permissions: Internet ON; Post Notifications ON only if local notifications ship.
   - Package name (Unique Name): identical to `MHPlatformConfig.PACKAGE_NAME` and the Play Console app id. It cannot be changed after upload.
3. Plugins vendored under `game/addons/`: `GodotGooglePlayBilling` (3.x, must bundle Play Billing Library **8.0.0 or later**;
   3.3.0 lists 9.1.0), `GodotPlayGameServices`, `NotificationScheduler`, and our `MHPlayIntegrity`.
   Enable each in Project Settings > Plugins. Check the Billing library version inside the plugin release notes before shipping.
4. Signing: Godot reads the keystore from the export preset or from environment variables
   `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`
   (debug: `GODOT_ANDROID_KEYSTORE_DEBUG_*`). UNVERIFIED for the pinned version. This is how CI signs without a secret in the repo.
   The key you sign with is the **upload key**; with Play App Signing enabled (default and required for AAB) Google re-signs with the app signing key.
   Play Games Services and Play Integrity certificate fingerprints must include BOTH the upload key SHA-1 (for local testing) and the Play app signing SHA-1 (from Play Console > Setup > App signing).

## 2. Build our Play Integrity plugin
Prereqs: JDK 17, Android SDK (platform 36), Gradle 8.x (or `gradle wrapper` generated on first run).
```
cd android/plugin
# 1) put the Godot library matching docs/GODOT_VERSION.md into libs (see mhplayintegrity/build.gradle.kts, Option A)
mkdir -p mhplayintegrity/libs
cp /path/to/godot-lib.<version>.template_release.aar mhplayintegrity/libs/
# 2) build
gradle :mhplayintegrity:assembleDebug :mhplayintegrity:assembleRelease
# 3) install into the game as an addon
mkdir -p ../../game/addons/MHPlayIntegrity/bin/debug ../../game/addons/MHPlayIntegrity/bin/release
cp addon_template/plugin.cfg addon_template/export_plugin.gd ../../game/addons/MHPlayIntegrity/
cp mhplayintegrity/build/outputs/aar/mhplayintegrity-debug.aar   ../../game/addons/MHPlayIntegrity/bin/debug/MHPlayIntegrity-debug.aar
cp mhplayintegrity/build/outputs/aar/mhplayintegrity-release.aar ../../game/addons/MHPlayIntegrity/bin/release/MHPlayIntegrity-release.aar
```
Then enable the MHPlayIntegrity plugin in Project Settings > Plugins. Game code sees the singleton `MHPlayIntegrity`
only through `MHIntegrityServiceAndroid`.

## 3. Inspect the merged manifest (do this once on the first real build)
After exporting, unzip the APK/AAB or read `game/android/build/build/intermediates/merged_manifests/**/AndroidManifest.xml`
and confirm: INTERNET, `com.android.vending.BILLING`, (POST_NOTIFICATIONS), the Play Games APP_ID meta-data, and the
`org.godotengine.plugin.v2.MHPlayIntegrity` meta-data.

## 4. Play Integrity setup summary (details in docs/phase0/platform.md)
- Play Console > app > Release > App integrity: link a Google Cloud project; note its PROJECT NUMBER (digits).
- Cloud project: enable "Play Integrity API" and "Google Play Android Developer API".
- Server decodes tokens with a service account (see supabase/functions/README.md).

## 5. ProGuard/R8
See `proguard-rules.pro`. Default Godot templates do not minify; leave minification OFF for Phase 0.

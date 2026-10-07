# Android platform integration

Status: **implementation present; end-to-end device/store validation still required.**

This directory contains the Android-specific support needed for Mulligan Hills, including the custom Play Integrity plugin source, manifest additions and release-build rules.

## Contents

- **plugin/** — Kotlin Godot plugin source for Play Integrity plus addon/export support.
- **manifest/AndroidManifest_additions.xml** — additional manifest requirements.
- **proguard-rules.pro** — keep rules for minified release builds.

## Toolchain

The exact Godot, Java, Android SDK/NDK and export-template values are controlled by **tools/ci/versions.env** and the CI setup scripts.

Do not treat a configured target/API value as release-verified until the pinned toolchain successfully exports, installs and runs on a physical Android device.

## Play Integrity plugin

The Kotlin source must be validated in the real Godot Android build path:

1. compile against the pinned Godot Android library/toolchain;
2. install the addon/plugin into the exported project;
3. confirm plugin discovery and required methods/signals;
4. request a real test integrity token;
5. validate timeout/error/lifecycle behavior;
6. verify the token server-side in staging.

## Release-build checks

Before Android release acceptance:

- merged manifest inspected;
- release AAB exports with the pinned toolchain;
- Play App Signing/upload-key path verified;
- Billing purchase and restore exercised with test products;
- Play Integrity exercised on a real device;
- R8/minification behavior checked if enabled;
- offline/reconnect entitlement behavior tested.

Current verification state belongs in **docs/VERIFICATION.md**, not in this README.

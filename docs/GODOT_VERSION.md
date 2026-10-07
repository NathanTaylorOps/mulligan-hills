# Toolchain pin

The canonical toolchain values are maintained in **tools/ci/versions.env**. This document explains the policy rather than duplicating every value.

## Current engine

- **Godot:** 4.7.2 stable
- **Language:** GDScript
- **Renderer:** Compatibility for the current product baseline
- **Project:** game/project.godot

## Test tooling

gdUnit4 and related CI tooling are pinned through tools/ci/versions.env and the setup scripts under tools/ci/.

## Android

Android SDK/JDK/NDK/export-template values are considered verified only after a successful real export using the pinned versions. Configuration may exist before that point, but the release baseline should be frozen from a known-good build.

## Pinning policy

1. Update versions in one source of truth: tools/ci/versions.env.
2. Record checksum pins for trusted artifacts where supported.
3. Run import/tests/exports before calling a toolchain change accepted.
4. Do not infer compatibility from documentation alone.
5. Record the successful commit/build in VERIFICATION.md or release evidence.

Historical research about the original version selection is implementation history, not current toolchain authority.

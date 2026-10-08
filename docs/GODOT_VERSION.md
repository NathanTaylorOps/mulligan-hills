# Godot engine and toolchain baseline

Mulligan Hills uses a pinned Godot version to support repeatable development, testing and platform exports. The authoritative configuration is `tools/ci/versions.env`; this document explains the selection and verification approach.

## Current configuration

| Component | Configured version or setting |
| --- | --- |
| Godot editor | **4.7.2-stable**, standard GDScript build |
| Export templates | `4.7.2.stable` |
| gdUnit4 | `v6.2.1` |
| Java | `17` |
| Android target SDK | `36` |
| Android SDK/NDK packages | Defined in `ANDROID_SDK_PACKAGES` in `tools/ci/versions.env` |
| Project configuration | `game/project.godot` |

These values describe the repository configuration, not a guarantee of compatibility on every host or target device. The CI scripts read the pinned versions; any upgrade should be reviewed with its test and export results.

## Download and integrity checks

The CI download helpers obtain release assets from the configured Godot release and verify them against the accompanying `SHA512-SUMS.txt` manifest. Optional hard-coded SHA-512 pins are supported through `GODOT_SHA512_LINUX`, `GODOT_SHA512_MACOS`, `GODOT_SHA512_WINDOWS` and `GODOT_SHA512_TEMPLATES` in `tools/ci/versions.env`.

An empty hard-pin value means the asset is checked against the release manifest but not against a separately pinned digest. Manifest verification detects accidental corruption and mismatched downloads; because the manifest and asset share a distribution source, it is not independent proof of supply-chain integrity.

The helper implementation is in `tools/ci/lib.sh`. For the current status of downloads, imports, tests and exports, use [GitHub Actions](https://github.com/NathanTaylorOps/mulligan-hills/actions) rather than relying on historical environment notes.

## Platform exports

Export templates are installed by `tools/ci/setup_templates.sh` in the platform-specific Godot export-template directory. Android toolchain requirements and export behaviour should be verified against the configured SDK packages, the project's export presets and the relevant CI run.

- [Godot 4.7.2 release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable)
- [Godot release archive](https://godotengine.org/download/archive/4.7.2-stable/)
- [Godot Android export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)

## Updating the baseline

1. Review Godot release notes, gdUnit4 compatibility and Android/iOS export requirements.
2. Update `tools/ci/versions.env` and any corresponding project/export configuration together.
3. Run applicable import, unit, determinism and platform-build workflows.
4. Record any changed compatibility assumptions, failures and mitigation in the pull request.
5. Update this document to match the verified configuration.

Do not represent a proposed version upgrade or a configured workflow as validated until the relevant checks have completed successfully.

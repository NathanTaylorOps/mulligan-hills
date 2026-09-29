# Godot version pin

Owner: workstream A (ci). Researched 2026-09-29 with web search and page fetches only.
Nothing was downloaded or executed (sandbox network blocks the release hosts), so every
URL and file name below is unverified by download. CI verifies them on first run.

## Finding

- Godot **4.7 stable exists**. Maintenance releases 4.7.1 and 4.7.2 exist.
- Latest stable as of this date: **4.7.2-stable** (release article dated 18 August 2026,
  57 fixes, "no known incompatibilities with 4.7.1").
- Godot 4.8 is only at dev snapshots (4.8 dev 6 seen). Not stable, not used.
- Sources checked:
  - https://github.com/godotengine/godot/releases/tag/4.7.2-stable
  - https://godotengine.org/article/maintenance-release-godot-4-7-2/
  - https://godotengine.org/download/archive/4.7.2-stable/
  - https://godotengine.org/releases/4.7/
  - https://godotengine.org/download/archive/ (lists all releases)

## Pin

| item | value |
| --- | --- |
| Godot | **4.7.2-stable** (standard build, not .NET) |
| `config_version` in project.godot | `5` (all Godot 4.x use 5) and `config/features` = `"4.7"` |
| Template folder name | `4.7.2.stable` |
| gdUnit4 | `v6.2.1` (needs Godot 4.5+; its README compatibility table listed up to 4.7.1 when checked) |
| Where set | `tools/ci/versions.env` (one file; workflows and scripts read it) |

Why 4.7.2 and not 4.7.1: it is the newest stable and a bug-fix release. Risk: gdUnit4 v6.2.1
may not have officially listed 4.7.2. **Fallback (one edit):** in `tools/ci/versions.env` set
`GODOT_VERSION=4.7.1` and `GODOT_TEMPLATE_DIRNAME=4.7.1.stable`.

## Download URLs (pattern; replace nothing, versions.env drives the scripts)

Base: `https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/`

| file | purpose |
| --- | --- |
| `Godot_v4.7.2-stable_linux.x86_64.zip` | editor on ubuntu runners |
| `Godot_v4.7.2-stable_macos.universal.zip` | editor on macOS runners (binary at `Godot.app/Contents/MacOS/Godot`) |
| `Godot_v4.7.2-stable_win64.exe.zip` | editor on Windows runners (CI uses the `_console.exe` inside) |
| `Godot_v4.7.2-stable_export_templates.tpz` | export templates (a zip; contains `templates/`) |
| `SHA512-SUMS.txt` | checksums for every file in the release |

File names follow the long-standing godot-builds convention. The 4.7.2 release page lists 36
assets but the fetch did not show their names, so exact names are UNVERIFIED for 4.7.2. Also
mirrored on https://godotengine.org/download/archive/4.7.2-stable/ and
https://github.com/godotengine/godot/releases/tag/4.7.2-stable (source and release notes).

## Checksum method

1. Scripts download `SHA512-SUMS.txt` from the same release and compare the SHA-512 of each
   zip against it (`tools/ci/lib.sh: verify_sha512`). This catches corruption and a bad mirror.
   It does not protect against a compromised release, because both files come from one place.
2. Hard pin (recommended after first green run): the download log and the artifact
   `godot-checksums.txt` print each hash. Paste them into `GODOT_SHA512_LINUX`,
   `GODOT_SHA512_MACOS`, `GODOT_SHA512_WINDOWS`, `GODOT_SHA512_TEMPLATES` in
   `tools/ci/versions.env`. From then on any other file is refused.
3. Hashes could not be filled in now because downloads are blocked in the authoring sandbox.

## Export templates

Installed by `tools/ci/setup_templates.sh` into the editor's template folder
(`~/.local/share/godot/export_templates/4.7.2.stable/` on Linux,
`~/Library/Application Support/Godot/export_templates/4.7.2.stable/` on macOS,
`%APPDATA%\Godot\export_templates\4.7.2.stable\` on Windows). Only the platforms a job needs
are extracted, to keep caches small.

## Android requirements (UNVERIFIED for 4.7.x)

Docs page: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
(the fetch only confirmed "OpenJDK 17"). Build tools, platform and NDK versions in
`tools/ci/versions.env` are best guesses from 4.4 to 4.6 era requirements. If the Android
export fails, Godot's log names the versions it wants: edit `ANDROID_SDK_PACKAGES` there.
Target API 36 is set in the export preset (`gradle_build/target_sdk`).

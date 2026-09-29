# Workstream A: CI and project scaffolding

Purpose: once the repo is pushed to GitHub, Actions imports the project, runs the gdUnit4 tests,
exports Android/Windows/iOS builds, runs a software-rendered bench and checks cross-platform
determinism, then reports through job summaries and downloadable artifacts.

**Status: written, syntax-checked, NOT YET RUN on any real GitHub runner.** No Godot binary
was available here. Every workflow, every Godot CLI flag and every export option below is
unverified until the first run. Expect a few fix-up rounds, most likely on Android and iOS.

## 1. What was built

Workflows (`.github/workflows/`)

| file | trigger | what it does |
| --- | --- | --- |
| `ci.yml` | push, PR, manual | download pinned Godot, install gdUnit4, headless import, run tests, JUnit summary, upload results |
| `android-debug.yml` | push, manual | Android SDK + JDK 17, debug keystore, export debug APK (optional AAB), print size, upload |
| `screenshots.yml` | push, manual | xvfb + Mesa llvmpipe, Compatibility renderer, run bench scene, PNGs + bench JSON table |
| `determinism.yml` | push on core/tests/ci paths, manual | run sim tests on ubuntu-latest and macos-latest, compare hashes in a final job that fails on mismatch |
| `windows-dev.yml` | manual | Windows dev (debug template) build artifact |
| `ios-testflight.yml` | manual | macOS: export Xcode project, archive, sign via API key, upload to TestFlight (dry run by default) |

Manual runs accept inputs: `game_path` (project folder, default `game`), `scene` (bench or main
scene, `res://...tscn`), `renderer` (`compatibility` or `mobile`). All workflows cache the Godot
binary and templates (`~/.cache/mh-godot`, key = hash of `tools/ci/versions.env`) and Gradle.

Scripts (`tools/ci/`, bash, bash 3.2 safe): `versions.env` (single version pin), `lib.sh`,
`download_godot.sh`, `setup_templates.sh`, `install_gdunit4.sh`, `import_project.sh`,
`run_tests.sh`, `junit_summary.sh`, `run_bench.sh`, `bench_summary.sh`, `compare_hashes.sh`,
`set_project_options.sh`, `render_export_presets.sh`, `ensure_icon.sh`, `setup_android_env.sh`,
`install_android_template.sh`, `ios_build_upload.sh`.

Project files: `game/project.godot`, `game/export_presets.cfg.template`, `.gitignore`,
`.gitattributes` (LFS rules for images, audio, 3D, fonts, native libs), `docs/GODOT_VERSION.md`.

`project.godot` decisions: name "Mulligan Hills"; `config_version=5`, features `4.7`;
Compatibility renderer for desktop and mobile; typed-GDScript warnings on (untyped declaration,
unsafe property/method/cast/call argument, discarded return value all at Warn, not Error);
orientation 6 (sensor: portrait and landscape); `emulate_touch_from_mouse=false`;
stretch mode `canvas_items`, aspect `expand`, base 1280x720; ETC2/ASTC and S3TC/BPTC import on
(needed for mobile and desktop exports); gdUnit4 plugin enabled (CI downloads it into
`game/addons/gdUnit4/`, which is git-ignored).

Mobile-renderer build variants: `MH_RENDERER=mobile tools/ci/set_project_options.sh` rewrites
`renderer/rendering_method` and `.mobile` in the runner's checkout. In workflows use the
`renderer` input. The committed project stays Compatibility.

Export presets template: 0 Android Debug APK, 1 Android Debug AAB, 2 Android Release AAB,
3 Windows Desktop, 4 iOS. Android: gradle build, arm64-v8a only, min SDK 24, target SDK 36
(from `versions.env`), category Game. Placeholders (`@@NAME@@`) are filled from environment
by `render_export_presets.sh`; the rendered `game/export_presets.cfg` is git-ignored. Release
signing placeholders exist but there is no release workflow yet (Phase 0 needs debug builds).

## 2. How it is tested (and what has NOT been run)

Run here: `bash -n` on every script; YAML parsed with Python `yaml` for all six workflows;
`junit_summary.sh`, `bench_summary.sh`, `compare_hashes.sh`, `run_tests.sh` (with a fake
Godot stand-in), `render_export_presets.sh` and the INI editor exercised on synthetic data.

**NOT YET RUN:** anything involving Godot, GitHub Actions, Android SDK, xvfb, Xcode, Apple
services. That is everything that matters. No workflow has ever executed.

## 3. Gate 0 criteria covered and evidence CI must produce

| need | evidence |
| --- | --- |
| Project imports and all GDScript parses | `import.log`, job summary lists any parse errors |
| Unit tests pass | JUnit XML (`test-results` artifact), summary table with counts |
| Sim is cross-platform deterministic | `hashes-*` artifacts, comparison table, job fails on mismatch |
| Forest/terrain bench under software GL | `bench-N` artifact: `bench.json`, PNGs (xvfb screenshots), summary table |
| Android debug APK builds and its size | `android-debug-apk` artifact, size in summary |
| Windows dev build | `windows-dev` artifact |
| iOS builds and reaches TestFlight | `ios-logs` artifact, TestFlight build (manual, needs secrets) |

Important: software GL numbers (llvmpipe) prove the scene loads and renders, not phone
performance. Device performance evidence comes from the device runbook, not this CI.

## Conventions other workstreams must follow

1. **Determinism hashes.** Sim tests must `print("MH_HASH:<label>=<hex>")` (letters, digits,
   `_ . : -` in the label; hex value) for each result hash. `determinism.yml` collects those lines
   from the gdUnit4 log on both OS runners and fails if any label differs or if none appear.
   (Workstream B: no such print exists in `game/tests/core/` yet.)
2. **Tests** are `game/tests/<module>/test_*.gd` extending `GdUnitTestSuite`; CI runs the whole
   `res://tests`. Zero discovered tests is a failure.
3. **Bench scene.** Default `res://bench/bench_scene.tscn` with args
   `--autostart --mode=quick --tier=medium --quit-after-bench` (matches workstream D's current
   code). `bench.json` is read from `--out=<dir>` or `user://`. The runner also takes screenshots
   of the virtual display at 6, 12 and 20 seconds with ImageMagick, so PNGs exist even if the scene
   saves none. Bench must exit on its own inside 15 minutes.
4. **project.godot** is owned by A. Autoloads, input actions or layer names needed by others: ask
   the lead to route them to A.
5. The Android gradle template installs to `game/android/build` (git-ignored). Workstream F's
   root `android/` folder is separate; if F needs a custom gradle template, tell A.

## 4. Unverified assumptions

- Godot 4.7.2 exists and the release asset names in `docs/GODOT_VERSION.md` are right.
- gdUnit4 `v6.2.1` works on 4.7.2 and its CLI is
  `-s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a <path> -rd res://reports -rc 3 -c`;
  reports land at `game/reports/**/results.xml`; exit code 0 = pass, 101 = warnings (accepted).
- Godot reads Android SDK/JDK paths from `editor_settings-4.tres` or `editor_settings-4.7.tres`
  (both are written) and reads `GODOT_ANDROID_KEYSTORE_DEBUG_PATH/USER/PASSWORD` env vars.
- Godot 4.7 Android build versions (build-tools 36.0.0/35.0.1, platform 35/36, NDK 28.1.13356709,
  JDK 17) and that `gradle_build/target_sdk` accepts `36`.
- The gradle template can be installed by extracting `android_source.zip` to `android/build`
  and writing `android/.build_version` (this mimics the editor menu action).
- Export preset option names (see template header) are still valid in 4.7.
- `--export-debug "Preset name" <path>` works headless with these preset names.
- Windows runner has Python on PATH (workflow installs it); Git Bash `bash` runs the scripts.
- iOS: `application/export_project_only=true` emits an `.xcodeproj`; `xcodebuild archive` with
  `-allowProvisioningUpdates` and an App Store Connect API key can create signing assets in the
  cloud; `destination=upload` in ExportOptions uploads to App Store Connect. The API key role
  probably must be Admin for cloud signing (check Apple docs). Godot iOS exports may also need
  privacy manifest or icon fixes before App Store Connect accepts the build.
- Ubuntu package names `mesa-vulkan-drivers`, `libglx-mesa0`, `imagemagick` on `ubuntu-latest`.
- Mobile-renderer bench (Vulkan through lavapipe) may not work on a runner.
- `macos-latest` is Apple Silicon (arm64) and `ubuntu-latest` is x86_64: good for the determinism
  comparison but confirm which runner image GitHub currently maps them to.
- GitHub Actions minutes: macOS jobs cost 10x Linux minutes on private repos (check current billing).

## 5. Risks and follow-ups

- Android and iOS are the likeliest to fail first time. Failure logs upload as artifacts
  (`android-logs`, `ios-logs`) so the fix can be made without a human reading the runner.
  A failed run's log is also available to the lead with `gh run view <id> --log-failed`.
- Debug keystore: without the optional secret, each Android build gets a new throwaway key,
  so the phone needs the old app uninstalled first. Add the secret to get in-place updates.
- Package id `com.mulliganhills.game` is a placeholder; the real id is permanent once a store
  listing exists. Decision needed before any Play or TestFlight upload beyond testing.
- `game/icon.png` is a generated flat-green placeholder (git-ignored) so exports do not fail.
  When a real icon is committed, delete the `game/icon.png` line from `.gitignore`.
- No release/Play upload workflow yet (Phase 0 does not need it). No Windows or Mac desktop
  test matrix for gdUnit4 beyond determinism.
- Godot download hashes are only checked against the release's own SHA512-SUMS until pinned.
- Godot output that mentions `SCRIPT ERROR` or `Parse Error` during import fails the build even
  when the exit code is 0. Intentional, but may also trip on warnings promoted by other modules.

## 6. For Nathan

Do these once, in order. You need a GitHub account and the repo pushed (the lead pushes it).

### A. Enable Actions

1. Open the repo page on github.com.
2. Click the **Actions** tab.
3. If you see a green button "I understand my workflows, go ahead and enable them", click it.
4. Click **Settings** (top row of the repo) > **Actions** > **General**.
5. Under "Actions permissions" choose **Allow all actions and reusable workflows**. Under
   "Workflow permissions" leave **Read repository contents** selected. Click **Save**.
6. Click the **Actions** tab, then **CI (import and unit tests)** in the left list, then the
   grey **Run workflow** button on the right, leave defaults, click the green **Run workflow**.
7. Refresh after 20 seconds. Click the run. A green tick = passed; a red cross = failed.
   Click the run name, then the **Summary** page shows the test table. Send the run link to
   the lead if red.

### B. Add secrets (only what you need, when you need it)

Nothing is needed for the CI, Android debug, screenshots, determinism or Windows workflows.
Secrets are only for stable Android signing (optional) and iOS (required).

To add any secret: repo > **Settings** > **Secrets and variables** > **Actions** > **New
repository secret** > paste the name exactly > paste the value > **Add secret**. Or with the GitHub
CLI, from a terminal opened in any folder (replace OWNER/REPO):

    gh auth login
    gh secret set NAME -R OWNER/REPO

and paste the value when asked.

| name | needed for | value |
| --- | --- | --- |
| `ANDROID_DEBUG_KEYSTORE_B64` | optional, stable Android debug signature | base64 of a keystore file (step B1) |
| `APPLE_TEAM_ID` | iOS | 10-character Team ID |
| `ASC_KEY_ID` | iOS | App Store Connect API Key ID |
| `ASC_ISSUER_ID` | iOS | App Store Connect Issuer ID (a UUID) |
| `ASC_KEY_P8_B64` | iOS | base64 of the downloaded `.p8` key file |
| variable `IOS_BUNDLE_ID` (Variables tab, not Secrets) | iOS, optional | e.g. `com.yourname.mulliganhills`; default is the placeholder |

**B1. Optional stable Android debug key.** Needs Java installed on your computer (skip this
if you do not have it; builds work without it). In a terminal:

    keytool -genkeypair -v -keystore debug.keystore -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US"

macOS: `base64 -i debug.keystore | pbcopy` (copies the value). Linux: `base64 -w0 debug.keystore`.
Windows PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("debug.keystore")) | Set-Clipboard`.
Paste it into the secret `ANDROID_DEBUG_KEYSTORE_B64`. Keep `debug.keystore` somewhere safe;
never commit it (the `.gitignore` already blocks `*.keystore`).

**B2. iOS secrets.** Requires a paid Apple Developer Program membership (check the current
fee on developer.apple.com/programs) and takes some clicking. Do not start until the lead says
the iOS build is next.

1. Go to https://developer.apple.com/account and sign in. Click **Membership details**. Copy
   **Team ID** (10 characters). Add it as secret `APPLE_TEAM_ID`.
2. Choose the app's bundle id (permanent, reverse-domain style, lower case, e.g.
   `com.yourname.mulliganhills`). Go to **Certificates, Identifiers & Profiles** > **Identifiers**
   > **+** > **App IDs** > **App** > Continue. Enter a description and the bundle id. Register.
3. Go to https://appstoreconnect.apple.com > **Apps** > **+** > **New App**. Platform iOS, any
   name, primary language, choose the bundle id from step 2, any SKU (e.g. `mulliganhills01`).
   Create.
4. Still in App Store Connect: **Users and Access** > **Integrations** > **App Store Connect API**
   > **Team Keys** > **Generate API Key** (or **+**). Name `github-ci`, Access **Admin**
   (cloud signing probably needs it; unverified). Generate.
5. Copy **Issuer ID** (shown at the top of that page) into secret `ASC_ISSUER_ID`. Copy the new
   key's **Key ID** into secret `ASC_KEY_ID`.
6. Click **Download API Key**. Apple lets you download it exactly once. You get
   `AuthKey_XXXXXXXXXX.p8`. Move it to a safe folder. Never commit it (`*.p8` is git-ignored).
7. Base64 it (in the folder holding the file). macOS: `base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy`.
   Linux: `base64 -w0 AuthKey_XXXXXXXXXX.p8`. PowerShell:
   `[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXXXXXXXX.p8")) | Set-Clipboard`.
   Paste into secret `ASC_KEY_P8_B64`.
8. Repo > **Settings** > **Secrets and variables** > **Actions** > **Variables** tab > **New
   repository variable** > name `IOS_BUNDLE_ID`, value your bundle id from step 2.
9. Run it: **Actions** > **iOS TestFlight** > **Run workflow**. Leave **dry_run** ticked the first
   time (builds and signs, uploads nothing). If green, run again with dry_run unticked.
10. On the iPhone: install **TestFlight** from the App Store, sign in with the same Apple ID
    that you added as a tester in App Store Connect (**TestFlight** tab > **Internal Testing** >
    **+** to create a group and add yourself). The build appears after Apple finishes processing
    (often 5 to 30 minutes).

### C. Get a build onto your Android phone

1. Run the workflow: **Actions** > **Android debug APK** > **Run workflow** > green **Run workflow**
   (it also runs on every push). Wait for a green tick (10 to 25 minutes the first time).
2. On your **phone**, open the browser, go to github.com, log in, open the repo > **Actions** >
   **Android debug APK** > the top green run. Scroll to **Artifacts** at the bottom.
3. Tap **android-debug-apk**. It downloads a `.zip` (artifacts are always zipped).
4. Open the **Files** app (or **My Files**), go to **Downloads**, tap the zip, tap **Extract**.
5. Tap `mulligan-hills-debug.apk`. If Android says installs from this source are blocked, tap
   **Settings**, switch on **Allow from this source** for the app you opened it from (Files or
   Chrome), press back, tap **Install**. If Play Protect warns about an unknown app, tap
   **Install anyway**.
6. If it says the app conflicts with an existing one, uninstall the older Mulligan Hills first
   (long-press the icon > App info > Uninstall), then install again. This happens because
   throwaway debug keys change every build unless you added `ANDROID_DEBUG_KEYSTORE_B64`.
7. Artifacts are deleted after 90 days by default. Downloading needs you to be logged in to a
   GitHub account with access to the repo.

From a computer with the GitHub CLI instead: `gh run download -R OWNER/REPO -n android-debug-apk`
then copy the file across with USB or `adb install -r mulligan-hills-debug.apk`.

### D. Get screenshots and bench numbers

**Actions** > **Screenshots and bench (software GL)** > latest run. The **Summary** tab has the
bench table. The artifact `bench-N` at the bottom holds the PNGs and `bench.json`.

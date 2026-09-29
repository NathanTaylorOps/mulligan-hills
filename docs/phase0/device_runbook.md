# Device Runbook (Phase 0): testing builds on real phones

Owner: workstream I (device). Status: written, NOT YET RUN on any device. Nothing here has been tried on a physical phone. Updated 2026-09-29 with the real workflow, artifact and benchmark screen names from `ci.md`, `forest.md`, `gestures.md` and the code in `game/bench/`.

This document is for Nathan. It assumes no technical knowledge. Menu names differ between phone makers and Android versions. If you cannot find something, open Settings, tap the magnifier at the top and type the word.

Rule for this whole document: text in `code style` marks a name taken from the code or the CI files. Anything marked "NOT CONFIRMED" could not be verified from code and may differ on screen: photograph what you see and tell the lead.

Related docs: `soak_protocol.md` (the 20 minute test), `results_template.md` (the form), `ci.md` (builds), `forest.md` (benchmark), `gestures.md` (gesture test), `GATE0.md` (what each test proves).

## 0. Two phones, two jobs
| Phone | Use it for | Do not use it for |
| --- | --- | --- |
| Samsung Galaxy S22 Ultra (yours, flagship) | Part A: install check, gesture tests, thermal soak, 60 fps check, rehearsal of every procedure | Proving the 30 fps floor. It is far faster than the phones the game must run on. A pass here proves nothing about low-end phones. |
| Low-end Android (to be bought, see section 14) | Part B: everything that decides Gate 0 items 2, 4, 5 (fps part) and 9 | nothing else needed |

Targets (DEC-046, DEC-047; still placeholders until measured): on the low-end phone, at least 30 fps average, 95 percent of frames faster than 33 ms, and no single frame slower than 100 ms. On mid and high phones, 60 fps is the goal. The game will get a player setting with 30, 60 and Auto. That setting does not exist in the code yet; there is nothing to test for it.

What you need: the phone and its charger and cable; a GitHub account that can open the repo (signed in on the phone browser); 45 minutes for first setup and about 30 minutes per soak; a way to note the room temperature (wall thermometer, or write cool / warm / hot); a timer (a second phone or a watch); optional: a computer.

## 1. Note the phone details (once per phone)
1. Open Settings, scroll to the bottom, tap About phone.
2. On the S22 Ultra: tap Software information to see the Android version and Build number. Write down Model name, Model number, Android version, Build number. A photo of each screen is fine.
3. RAM: Settings > Battery and device care > Memory (Samsung). Other makers: search "RAM" in Settings. If not found write "not found".
4. Storage free: Settings > Battery and device care > Storage (Samsung) or Settings > Storage. Keep at least 1 GB free (estimate, not measured).
5. Fill the Device section of `results_template.md`.

## 2. Allow installs from outside the Play Store
Android calls this "install unknown apps". It is off by default.
1. Samsung: Settings > Apps > tap the three dots at the top right > Special access > Install unknown apps. Other makers: Settings > Apps > Special app access > Install unknown apps, or Settings > Security.
2. Tap Chrome (or the browser you use) and turn on Allow from this source.
3. Tap My Files (Samsung) or Files by Google, and turn on Allow from this source there too.
You do not need Developer options or USB debugging for this runbook.

## 3. Get a build from GitHub
A build artifact is the file the automated build produced. GitHub always delivers it as a zip file.

The build to use depends on the test. The project has no start scene set, so a build from a plain push may open to nothing (NOT CONFIRMED). For each test below, run the build yourself and pick the scene.

### 3A. Start a build for a given test (do this first)
1. On the phone, open Chrome and go to the repo page on github.com (the lead gives the exact link; repo name in DEC-033 is `golf-tycoon`).
2. Tap the Actions tab. If you see no tabs, open the Chrome menu (three dots) and tick Desktop site.
3. In the left list tap Android debug APK.
4. Tap Run workflow (a grey button on the right of the run list). A form opens with three boxes: `game_path` (leave as `game`), `scene` and `renderer`. The exact wording of these boxes is from `ci.md` and the workflow file; the layout on your screen is NOT CONFIRMED.
5. Fill in the form for the test you want:

| Test | scene | renderer |
| --- | --- | --- |
| Benchmark, Compatibility renderer | `res://bench/bench_scene.tscn` | `compatibility` |
| Benchmark, Mobile renderer | `res://bench/bench_scene.tscn` | `mobile` |
| Gesture test | `res://input/mh_gesture_sandbox.tscn` | `compatibility` |

6. Tap the green Run workflow button. Wait: the first run can take 10 to 25 minutes (`ci.md`). Refresh the page until the run at the top of the list has a green tick. A red cross means the build failed: do not use it, tell the lead.
7. Two benchmark runs are needed (one per renderer). Write down which run is which: each run has its own number.

### 3B. Download the APK
1. Open the green run. Scroll to the bottom to Artifacts. Tap `android-debug-apk`. You must be signed in to GitHub. If Artifacts is missing on the phone, use Desktop site.
2. A `.zip` downloads. If Chrome asks, tap Download.
3. Write down the run number and the commit id shown at the top of the run page. That is the Build id for the results form.
4. Artifacts are deleted after 90 days (`ci.md`; default GitHub setting).

### 3C. Unzip
1. Open My Files (Samsung) or Files by Google. Tap Downloads.
2. Tap the zip, then Extract (Samsung: tap Extract, then Done). A folder appears.
3. Open it. The file is `mulligan-hills-debug.apk`.
4. If your Files app cannot unzip, download the artifact on a computer (same Actions page), unzip it there, and move the .apk to the phone by USB cable (choose File transfer on the phone) or by uploading to Google Drive and downloading on the phone.
5. Rename nothing. If you keep two APKs (Compatibility and Mobile), install one, test it, uninstall it, then install the other; copies of the file share the same name, so keep them in separate folders.

## 4. Install
1. In My Files tap `mulligan-hills-debug.apk`.
2. If it says installs from this source are blocked, tap Settings, turn on Allow from this source (section 2), press Back, tap the file again.
3. Tap Install.
4. If Google Play Protect warns about an unknown app, tap More details, then Install anyway. This is expected for a test build.
5. Tap Open. The app name should be "Mulligan Hills" (from `project.godot`).
6. "App not installed" or "conflicts with an existing app": uninstall the old Mulligan Hills first (long-press the icon, App info, Uninstall), then install again. This happens because debug keys change every build unless the lead set up a fixed key (`ci.md`).
7. If a permission prompt appears, choose Don't allow (whether the app asks for any is NOT CONFIRMED).

## 5. Before every test: set up the phone
Do all of this before each run and record it on the form.
1. Case off.
2. Battery: read the percentage from the top of the screen. Start between 50 and 100 percent. Charge above 50 percent before benchmarking. Below 20 percent the phone may slow itself down.
3. Battery saver OFF. Samsung: Settings > Battery and device care > Battery > Power saving OFF.
4. Brightness about 50 percent, Adaptive brightness OFF (Settings > Display).
5. Screen timeout: Settings > Display > Screen timeout > 30 minutes. The benchmark asks the phone to keep the screen on (`DisplayServer.screen_set_keep_on(true)`), whether Android obeys is NOT CONFIRMED, so set the timeout as well.
6. Do Not Disturb ON: swipe down twice from the top and tap Do not disturb.
7. Close other apps: recent apps button, then Close all.
8. Restart the phone, wait 3 minutes, do not use it.
9. Charging: choose one mode per test and write it down. First soak: plugged in. Second soak: on battery. Never switch mid-test.
10. Airplane mode ON, Wi-Fi off, Bluetooth off (the benchmark needs no network).
11. Put the phone flat on a hard table, out of sunlight, no fan on it. Note the room temperature.
12. The phone must feel room temperature before starting. If warm, wait 15 minutes.

## 6. Part A: Samsung Galaxy S22 Ultra

### A1. Install check (Gate 0 item 1, device half)
1. Do 3A with the benchmark scene and `compatibility`, then 3B, 3C, 4.
2. When the app opens, you should see a 3D golf scene with trees, a text line at the top left, and a row of buttons along the bottom: `Low`, `Medium`, `High`, `Quick 60s`, `Soak 20min` (from `bench_scene.gd`).
3. Screenshot it (Power and Volume Down together, about 1 second).
4. Gate 0 item 1 wants the app to show the commit id. The code has no such display (NOT CONFIRMED that it will be added). Instead write down the run number and commit id from step 3B and tell the lead "installed and launched", with the screenshot.
5. Record the result on the form (Test type: quick, one row only about install).

### A2. Gesture test (Gate 0 item 6)
1. Do 3A with the gesture scene, then 3B, 3C, 4. Uninstall the benchmark build first.
2. Follow these 13 steps (from `gestures.md`; the screens described are from code, NOT YET RUN). Write the result of each on the Gesture section of the form.
   1. Open the app. You should see a green ground, one tall RED post, and three shorter grey posts.
   2. Tap the small square outline in the top-left corner of the screen. A black box with text should appear. If not, write "overlay failed" and stop.
   3. Put ONE finger on the ground and drag slowly. Yellow squares should appear under your finger. The box should say `state: painting` and `fingers: 1`.
   4. Lift your finger. The box should say `state: idle`. The `strokes started/ended/cancelled` counters should show 1 or more started and ended.
   5. Start a new drag with one finger. While still dragging, put a SECOND finger down. The yellow squares of that drag should disappear, `cancelled` should go up by 1, and the state should say `camera`. Write down if the squares did not disappear.
   6. Keep both fingers down and move them apart, then together. The view should zoom in and out and stop at a limit. Write down which direction felt right or wrong.
   7. Twist your two fingers like turning a dial. The world should turn with your fingers. Write down if it turns the wrong way. Twist through more than half a turn and note any jump.
   8. Slide both fingers together in one direction. The world should follow your fingers.
   9. Lift ONE finger and keep dragging with the other. Nothing should paint and the state should stay `camera`. Then lift the last finger.
   10. Ten times: put one finger down, and about a fifth of a second later put a second finger down. Count how many times a yellow square stays behind. Write the number.
   11. Put three fingers on the screen and move them. Nothing should paint and the camera should not move; the state says `ignored`.
   12. Twist the view so the red post is not at the top. Tap the round compass in the top-right. The view should ease back until the red post is at the top of the screen.
   13. Rest the side of your palm or thumb at the very edge of the screen while painting with another finger. Write down whether stray marks appear.
3. Also write one sentence: did painting feel delayed at the start of a stroke?
4. Screen-record the whole test (section 9).
5. Gate 0 item 6 lists 12 cases; the mapping between those 12 and the steps above is NOT CONFIRMED (for example, tilt limit, long press and the undo button have no step above). The lead will send the checklist `06_gesture_checklist.md` when the mapping is decided.

### A3. Rehearsal and 60 fps check
Purpose: learn the procedure and see how a flagship performs. It cannot pass Gate 0.
1. Do 3A (benchmark, `compatibility`), install, section 5.
2. Tap `Low`, then tap `Quick 60s`. Do not touch the screen for 60 seconds. The top-left text shows the tier, fps, scale, draws and prims while it runs, and a counter like `bench 12s/60s`.
3. The black results screen appears. Do section 8.
4. Repeat for `Medium` and `High`, resting 15 minutes between tiers if the phone feels warm.
5. Fill one form per tier.
6. Reading the result: `avg_fps` near 60 with a low `p95_ms` (about 17 ms or less) means the 60 fps target is met on this flagship. The verdict word on the screen (`PASS_30FPS` or `FAIL_30FPS`) only tests the 30 fps rule (see section 8).

### A4. Thermal soak on the S22 (learning run, not a gate pass)
1. Section 5, in full. Plugged in for the first run.
2. Start the screen recording (section 9) if this is the recorded run.
3. Tap the tier chosen by the lead (default: `Medium`), then tap `Soak 20min`. Start your timer at the same moment.
4. Do not touch the screen for 20 minutes. At 5, 10, 15 and 20 minutes touch only the back edges of the phone with a finger and write cool / warm / hot.
5. When the results screen appears, do section 8 before anything else.
6. Let the phone cool at least 15 minutes before another run.
7. Full rules, failure conditions and invalid runs are in `soak_protocol.md`. Note that the thresholds for a gate pass apply only to the low-end phone.

## 7. Part B: the low-end phone
Do this only when the low-end phone has arrived and section 14 details are recorded on the form. All of section 5 applies.

### B1. Quick tests (per renderer, per tier)
1. Install the Compatibility build (3A with `compatibility`, 3B, 3C, 4).
2. Tap `Low`, then `Quick 60s`. Do not touch the screen. Section 8. One form.
3. Rest 15 minutes. Repeat with `Medium`, then `High`. If the phone crashes or restarts on a tier, stop, note the tier, and tell the lead before trying a higher tier.
4. Uninstall, then install the Mobile build (3A with `mobile`). Repeat 2 and 3. If the Mobile build will not start on this phone, that is a recorded result, not a mistake: photograph any message and say so on the form (GATE0 item 2 allows this).
5. Six forms in total (3 tiers x 2 renderers).

### B2. The 20 minute soak
1. The lead chooses which renderer and tier (the one that passed Quick with the best margin).
2. Section 5, then section 6 step A4 exactly (same steps, same 5-minute touch notes).
3. Run 1 plugged in. Run 2 on battery, another day or after a 30 minute cool-down.
4. Pass, for Gate 0 (placeholders until measured, DEC-047): `avg_fps` 30 or more; `p95_ms` under 33; `min_fps` 10 or more (a frame slower than 100 ms shows as `min_fps` below 10, because min fps is 1000 divided by the slowest frame); `throttle_ratio` 0.85 or more (proposed in `forest.md`, not in GATE0); no crash, restart, freeze or shutdown.
5. Fill the form and the pass section.

### B3. Other Gate 0 items on this phone
Items 4, 5 and 9 need extra scenes or menus that are not confirmed to exist yet. The lead will tell you which build and scene to use when they do. Do not guess.

## 8. Reading and copying the results screen
When a test ends, the screen turns black with large white text (from `mh_results_screen.gd`). It shows these lines, in this order if present:
`verdict`, `tier`, `renderer_active`, `mode`, `duration_s`, `frames`, `avg_fps`, `p50_ms`, `p95_ms`, `p99_ms`, `min_fps`, `pct_over_33ms`, `draw_calls_avg`, `draw_calls_max`, `primitives_avg`, `static_mem_max_mb`, `video_mem_max_mb`, `render_scale`, `throttle_ratio`, `battery_start_pct`, `battery_pct`, `device`, `gpu`, `thermal`.
Two buttons sit below: `Copy JSON` and `Close`.

Plain-words meanings:
- `avg_fps`: average frames per second. Higher is better.
- `p95_ms`: 95 percent of frames took less than this many milliseconds. Lower is better. 33 ms is the 30 fps line.
- `min_fps`: fps of the single slowest frame. Under 10 means a stall over 100 ms.
- `pct_over_33ms`: percent of frames slower than 33 ms.
- `throttle_ratio`: fps in the last 5 seconds divided by fps in the first 5 seconds. Under 0.85 suggests the phone slowed down as it heated.
- `render_scale`: the game lowers its own picture resolution when frames are slow (adaptive scale, on by default). A low value means the phone was struggling. Write it on the form.
- `renderer_active`: which renderer really ran. Write it down and check it matches the build you meant to test.
- `verdict`: the code's own quick judgement. It uses average 30 fps and `p95_ms` of 34.0 or less. This is close to but not the same as the Gate 0 rule (33 ms, and no 100 ms stall). Use the numbers, not the word.
- `battery_start_pct` and `battery_pct` will show `-1`. That means "not measured". Godot has no battery reading, so type the battery percent from the phone's own status bar or Settings into the form yourself, at start and at end.
- `thermal` will say the value is not available. Use the "phone felt" notes instead.

Steps:
1. Screenshot immediately (Power and Volume Down together).
2. Tap `Copy JSON`. This puts the full numbers (including the slowest frame time, `max_ms`, which is not shown on screen) on the clipboard. Open a notes app, long-press, tap Paste, and save the note; or paste into an email to yourself. Whether Copy JSON works on Android is NOT CONFIRMED. If nothing pastes, say so on the form.
3. If the text is cut off at the bottom of the screen, that is a known risk (30 point text); rely on the Copy JSON note and tell the lead.
4. Type the numbers into the form as well as attaching the photos.
5. The app also saves the same numbers to a file named `bench.json` inside its private storage. You cannot normally reach it from the phone; a person with a computer and USB debugging can (the lead will say if needed). Nothing for you to do.
6. Tap `Close` only after the screenshot and copy are done. If the results screen did not appear, do not repeat the test: photograph whatever is on screen and tell the lead.

## 9. Screen recording (built in)
Recording costs a little performance. Do one recorded and one un-recorded soak.
1. Swipe down twice from the top to open Quick settings. Find Screen recorder (Samsung). If not there, tap the pencil or Edit icon and drag it in.
2. Tap Screen recorder, choose Sound: No sound, tap Start recording. A 3 second countdown runs. Then start the test.
3. To stop, swipe down and tap the stop button (or the red timer).
4. The video is in Gallery > Albums > Screen recordings.
5. Videos are big. Send them by cloud link (section 11).

## 10. Save-kill test
The kill-during-save test (Gate 0 item 10) is mostly run by a computer with USB debugging. The lead will give separate copy-paste commands when the scene and harness are confirmed. There is nothing for you to do from the phone yet.
Generic checks you can do once a build with saving exists (NOT CONFIRMED that one does): make a change; wait for the save; swipe the app away in recent apps; reopen; check the change is there. Press Home, wait 30 seconds, return. Lock and unlock the screen. Write Pass or Fail for each.

## 11. Send the results back
Name every file `YYYY-MM-DD_device_test.ext`, lowercase, no spaces. Suggested device names: `s22-ultra`, and the low-end model with dashes, for example `2026-10-14_s22-ultra_test.md`, `2026-10-14_galaxy-a15_test-2.png`. Use .md for forms, .png or .jpg for pictures, .mp4 for recordings, and .txt for the pasted JSON.

Option A: upload to GitHub (forms and photos)
1. On the phone (Desktop site helps) open the repo and go to the folder `docs/phase0/results/`. If it does not exist, tell the lead.
2. Tap Add file, then Upload files, choose files, type a message like "Add results 2026-10-14 s22-ultra", choose Create a new branch for this commit unless the lead said to commit to main, tap Commit changes.
3. The browser upload limit is believed to be 25 MB per file (unverified: https://docs.github.com/en/repositories/working-with-files/managing-files/adding-a-file-to-a-repository). A 20 minute recording is probably bigger.

Option B: email (best for video)
1. Email the form, screenshots, pasted JSON and recording to the address the lead gives you.
2. Subject: "Mulligan Hills device test, YYYY-MM-DD, phone name".
3. If a file is too large, upload it to Google Drive and share a link with view access.

Always send at least: the completed form, one screenshot of the results screen, the pasted JSON, and one photo of the About page.

## 12. If something goes wrong
- App will not install: section 4, step 6.
- The app opens to a blank or grey screen: you probably installed a build with no scene selected. Redo 3A with the scene box filled in.
- The phone is too hot to hold, or shows a temperature warning: stop, note the time, photograph it, let it cool. That is a result.
- The phone restarts: a thermal or crash failure. Note the time. Do not keep retrying.
- Unsure: stop and ask. A partial honest result is better than a guess. Never edit numbers.

## 13. iPhone plan (TestFlight)
Status: NOT YET RUN. Depends on an Apple Developer account, signing, and the `iOS TestFlight` workflow (`ci.md`, manual, dry run by default). What Nathan does once a build is uploaded:
1. Apple Developer Program membership (paid yearly; check the price at Apple).
2. Install TestFlight from the App Store on the iPhone.
3. In App Store Connect open the app > TestFlight > Internal Testing > add yourself with your Apple ID email (`ci.md` section B has the full walkthrough).
4. Open the invitation on the iPhone, tap View in TestFlight, then Install.
5. Model and version: Settings > General > About. Low Power Mode OFF (Settings > Battery). Auto-Brightness OFF (Settings > Accessibility > Display & Text Size).
6. Screenshot: side button and Volume Up together. Screen recording: add it in Settings > Control Center, then swipe down from the top right and tap record.
7. Send results as in section 11.
If TestFlight is not ready in Phase 0, iPhone results wait; the lead decides in `GATE0.md`.

## 14. Buying the low-end Android phone
Purpose: a deliberately weak phone. If the game runs at 30 fps here it runs on most phones we care about. Target from Nathan: a Galaxy A14 / A15 class phone, about US$100-150 used (price is Nathan's estimate, not checked by us).
Check before buying (all from the seller's listing or the maker's spec page; we could not verify specific models):
- Class: entry-level chip. The exact chip in a given "A14" or "A15" varies by variant and region (there are several versions); check the variant you are buying.
- RAM 3 to 4 GB is ideal. 2 GB is too small to be informative. 6 GB or more is not low end.
- GPU must support Vulkan and OpenGL ES 3.0 (look on the maker's or chip maker's spec page). The Mobile renderer needs Vulkan; Compatibility needs OpenGL ES 3.0 (https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html).
- Android 11 to 14. Screen 60 Hz. 32 to 64 GB storage. Battery at least 4000 mAh.
- Unlocked, not carrier-locked, with a returns option. Avoid unsupported-region or gray-market variants.
- Used phone: check battery health with the seller; a worn battery distorts a soak.
- The phone does not need a SIM.
- Record model, model number, chipset, GPU, RAM and Android version on the form.
Also useful, not required: one mid-range phone as a control.

## 15. Tablet plan
1. Same APK, same steps (sections 3 to 5), same form; write "tablet" and the screen size.
2. More pixels means more work; expect worse results than a phone with the same chip (general reasoning, not measured).
3. Run a Quick test at every tier and one soak. Test gestures (A2) with two hands, and landscape only if the lead asks.
4. No split-screen in Phase 0.

## Unverified
- The `Run workflow` form layout on the phone browser (only the input names `game_path`, `scene`, `renderer` come from the workflow).
- Whether a push-built APK shows anything without a start scene.
- Whether Copy JSON works on Android, and whether the results text fits the screen.
- Whether Android obeys the app's keep-screen-on request.
- Any Samsung menu name (written from general knowledge, not from the device).
- Whether the app asks for permissions and whether a debug APK triggers extra Play Protect prompts.
- Screen recording overhead.
- GitHub upload limits, artifact retention, TestFlight limits, Apple costs.
- The mapping between Gate 0 item 6's 12 gesture cases and the 13 sandbox steps.

## Follow-ups for the lead
- Create `docs/phase0/results/` with a `.gitkeep` and short README (the folder is not confirmed to exist).
- Decide how item 1 shows the commit id on screen (nothing in `game/` does), or accept run number plus commit id from the Actions page.
- `MHBenchStats.verdict` uses p95 <= 34.0 ms; DEC-047 says under 33 ms plus no 100 ms stall. Either update the code or keep reading the numbers.
- Battery percent and the slowest frame (`max_ms`) are not on the results screen; consider adding them.
- Decide item 3's on-phone hash run (no launchable scene confirmed) and items 4, 5, 9 device scenes.

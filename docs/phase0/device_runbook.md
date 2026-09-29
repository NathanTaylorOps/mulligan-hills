# Device Runbook (Phase 0): testing builds on real phones

Owner: workstream I (device). Status: written, NOT YET RUN on any device. Nothing here has been tried on a physical phone.

This document is for Nathan. It assumes no technical knowledge. Menu names differ between phone makers (Samsung, Xiaomi, Motorola, Google, and others). Where a name may differ, the alternatives are listed. If you cannot find something, search the Settings app using the magnifier at the top and type the word in bold.

Related docs: `soak_protocol.md` (the 20 minute test), `results_template.md` (the form you fill in), `ci.md` (workstream A: where builds come from), `forest.md` (workstream D: what the benchmark screen looks like).

## 0. What you need
- The Android phone, its charger and cable.
- A GitHub account that can open the Mulligan Hills repository (signed in on the phone browser).
- 45 minutes for a first setup, then about 30 minutes per soak test.
- A room-temperature reading (a wall thermometer, or note "cool / warm / hot" in your own words).
- Optional but very helpful: a computer, and a second phone or a timer.

## 1. Note the phone details (do this once per phone)
1. Open Settings.
2. Scroll to the bottom and tap About phone (may be called About device, or System, then About phone).
3. Write down: Model name, Model number, Android version, and (if shown) Build number. Photograph the screen instead if easier.
4. RAM: on many phones it is shown under About phone as Memory or RAM. If not shown, search "RAM" in Settings. Some phones show it in Settings > Battery and device care > Memory (Samsung). If you cannot find it, write "not found" and the model number; engineers can look it up (unverified: model lookups are done by us, not guaranteed).
5. Storage free: Settings > Storage. You need at least 1 GB free (unverified estimate; the build size is not known yet).
6. Fill in the Device section of `results_template.md`.

## 2. Allow installs from outside the Play Store
Android calls this "install unknown apps". It is off by default. Phase 0 builds are not on the Play Store, so this must be on for the app you use to open the file.

Generic steps (menu names vary):
1. Open Settings > Apps > Special app access > Install unknown apps (Samsung: Settings > Apps, then the three dots, then Special access; Xiaomi: Settings > Privacy > Special permissions > Install unknown apps; some phones: Settings > Security > Install unknown apps or Unknown sources).
2. Tap the app you will open the APK from. Most likely Files (also called My Files, Files by Google, or File Manager) and Chrome (or whichever browser you use).
3. Turn on Allow from this source.
4. If you later want to be safe again, come back and turn it off after testing. That is your choice; nothing depends on it.

Developer options (only needed for Section 9 extras and if a screen tool asks for it, otherwise you can skip):
1. Settings > About phone > Software information (Samsung) or just About phone.
2. Tap Build number 7 times quickly. Enter your screen lock PIN if asked. A message says you are now a developer.
3. Developer options now appears under Settings > System (or Settings > Additional settings on some makers, or at the bottom of Settings).
4. You do NOT need USB debugging for this runbook. Leave it off unless an engineer asks.

## 3. Get the build from GitHub Actions on the phone
A "build artifact" is the file the automated build produced. GitHub always gives artifacts as a zip file, even for one APK.

1. On the phone, open Chrome (or your browser). Go to the repository page. The address is `https://github.com/<owner>/<repo>` (Nathan: the lead will give the exact link; unverified until the repo is created).
2. Tap the Actions tab. If you do not see tabs, tap the menu (three lines or "..."), or switch the browser to Desktop site (Chrome menu, three dots, tick Desktop site). The GitHub mobile website hides some tabs.
3. Tap the workflow run at the top of the list with a green tick that has the name the lead told you (for example "android-debug" or similar; see `ci.md` for the real name, unverified). A red cross means the build failed: do not use it and tell the lead.
4. Scroll to the bottom of the run page to the section Artifacts.
5. Tap the artifact whose name contains "apk" (see `ci.md`). You must be signed in to GitHub or the download is refused.
6. The phone downloads a file ending in .zip. Chrome may ask "Download anyway?" Tap Download.
7. Write down the run number and the commit id (7 to 40 characters) shown at the top of the run page. This is the Build id for the results form. Photograph the run page if unsure.
8. Artifacts expire after a retention period (GitHub default is believed to be 90 days; unverified, see GitHub docs: https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-workflow-runs/removing-workflow-artifacts). Use recent runs.

Unzip on the phone:
1. Open the Files app (Files by Google, or My Files on Samsung).
2. Tap Downloads.
3. Tap the .zip file. Most Files apps offer Extract or Unzip. Tap it, then Extract again. A folder with the same name appears.
4. Open the folder. Inside is a file ending in .apk. If there is another zip inside, extract that too.
5. If your Files app cannot unzip: install a free unzip app from the Play Store (the store search for "zip extractor" will show options; choose a well-rated one; we cannot recommend one by name), or use the computer method below.

Alternative: download on a computer and transfer.
1. On a computer, sign in to GitHub and open the same Actions run page, scroll to Artifacts, and click the apk artifact. A zip downloads.
2. Unzip it (Windows: right-click, Extract All. Mac: double-click the zip).
3. Move the .apk to the phone by one of: USB cable (connect the phone, choose File transfer on the phone prompt, drag the file into the phone's Download folder); or email it to yourself and open the email on the phone (if the file is too large for email, use Google Drive or another cloud folder you already use and download it on the phone).

## 4. Install the APK
1. In the Files app, tap the .apk file.
2. If a message says "For your security, your phone is not allowed to install unknown apps from this source", tap Settings and turn on Allow from this source (Section 2), then press Back and tap the file again.
3. Tap Install.
4. If Google Play Protect shows "Blocked" or "App scan recommended", tap More details, then Install anyway (or Scan app, then Install). This is expected because the test build is not from the Play Store. If your phone has no Install anyway option, tell the lead and note the message exactly (photograph it).
5. Wait for "App installed", then tap Open. The app is named like the game (name unverified; see `platform.md`).
6. If it says "App not installed": most common causes are too little storage, or an older test build with a different signature still installed. Uninstall the old version first (long-press the app icon, App info, Uninstall), then try again. Photograph any message you see.
7. If a permission prompt appears (notifications, storage), choose Don't allow unless the lead said otherwise (unverified whether the app asks for any).

## 5. Before every test: set up the phone (consistency matters)
Results are only useful if each test is done the same way. Do all of this before each run and record it on the form.
1. Case off. Remove any thick or rubber case. Note "case off".
2. Battery level: record the percentage. For a soak, start between 50 and 100 percent. A phone below 20 percent may slow itself down; do not start there.
3. Battery saver / Power saving mode: OFF (Settings > Battery > Battery saver, or Power saving). Also turn off Adaptive battery only if the lead asks; otherwise leave it.
4. Screen brightness: set to about 50 percent, and turn Adaptive brightness OFF (Settings > Display > Brightness level, and Adaptive brightness). Same setting every test.
5. Screen timeout: set to the longest (or 30 minutes if available). Settings > Display > Screen timeout. Also turn off "Keep screen on while charging" changes if the lead has not said otherwise: simply confirm the screen stays on for the full test.
6. Do Not Disturb ON, so calls and notifications do not interrupt (swipe down from the top and tap Do not disturb).
7. Close other apps: open the recent apps button, tap Close all.
8. Restart the phone, then wait 3 minutes and do not use it. This gives a clean, cool start.
9. Charging: choose ONE mode per test and write it down. Standard is "plugged in" for the first soak because it removes battery level as a variable, but charging makes the phone warmer. Do a second soak "on battery" and compare. Never mix modes within one test. Use the phone's own charger and cable.
10. Airplane mode: standard is ON with Wi-Fi off (removes network activity). If the lead says the app needs a network, put airplane mode ON, then turn Wi-Fi back on. Write down what you chose. Bluetooth off.
11. Surface and place: put the phone flat on a hard table (not a bed, sofa, or in sunlight), not in your hand. Note the room temperature (thermometer, or "cool 20s / warm / hot"). No fan pointing at the phone for the standard test. Air conditioning should be constant.
12. Thermal starting state: the phone must feel at room temperature. If it feels warm, wait 15 minutes.

## 6. Run the benchmark
The benchmark scene and its buttons come from workstream D (`forest.md`). The names below are the intended ones; if the screen differs, photograph it and note the differences (unverified until CI builds exist).

Quick mode (about 1 to 2 minutes, a sanity check):
1. Open the app and go to the Benchmark screen (see `forest.md` for how; unverified).
2. Tap the Quick button (Quick mode).
3. Do not touch the screen until it finishes.
4. Take the results photo (Section 8) and copy the numbers to the form.

Soak mode (20 minutes; the real test, described fully in `soak_protocol.md`):
1. Do all of Section 5.
2. Start the screen recording (Section 7).
3. Tap the Soak button (Soak mode). Start a timer at the same moment.
4. Leave the phone alone for 20 minutes. Do not touch the screen, except if a warning appears.
5. At 10 minutes glance at the screen and write the time and the temperature feel (Section 9) without touching it.
6. When done, stop the recording, photograph the results screen (Section 8), record battery level, and fill in the form.

## 7. Quality tier buttons
There are quality tiers (names expected to be Low, Medium, High, and maybe Auto; unverified). Rules:
1. Test one tier at a time, and each tier gets its own results form.
2. Order: start with Low, then Medium, then High. Between tiers, let the phone cool for 15 minutes.
3. Tap the tier button before starting Quick or Soak. The chosen tier is normally highlighted or shown on screen. Write it on the form and make sure it is visible in your photo.
4. If the phone crashes or restarts on a tier, note the tier and stop; do not try the higher tiers until you tell the lead.

## 8. Reading and photographing the results screen
1. When a test finishes, the app shows numbers such as average FPS, p95 frame time (in milliseconds), minimum FPS, and maybe renderer name and build id. (Exact list unverified; see `forest.md`.)
2. Meanings in plain words: FPS is frames per second (higher is better; 30 is the target). p95 frame time is how long the slow frames took; 95 percent of frames were faster than this; lower is better; the pass line is under 50 milliseconds.
3. Take a phone screenshot for the exact numbers: press Power and Volume Down together for about 1 second (Samsung: Power and Volume Down, or swipe the palm across the screen if enabled). A preview flashes.
4. Also photograph the screen with a second device if you can, in case the screenshot is blocked. If the screen is not available for a screenshot, hold the camera steady and check the numbers are readable, no glare.
5. Screenshots are in Gallery or Photos > Screenshots, or Files > Pictures > Screenshots.
6. Type the numbers into the form as well. Photos alone are not enough, because numbers may be misread.
7. If results are not shown at the end, do not repeat the test yet. Photograph whatever is on the screen and tell the lead.

## 9. Screen recording (built-in recorder)
Recording uses some performance, so record only the soak's start and end when the lead asks for low overhead. Default for a soak: record the full 20 minutes only once (mark on the form that the recording was on), and run one un-recorded soak to compare (recorder overhead unverified).
1. Swipe down from the top of the screen twice to open Quick settings.
2. Look for Screen record (Samsung: Screen recorder). If it is not there, tap the pencil or Edit icon and drag it in.
3. Tap Screen record. On some phones a Start recording confirmation appears: tap Start. Choose Record audio: none.
4. A 3-second countdown begins. Then start the test.
5. To stop, swipe down and tap the red stop button or the red timer.
6. The video is saved in Gallery or Photos, or in Files > Movies > Screen recordings (Samsung: Files > DCIM > Screen recordings; Xiaomi: Files > DCIM > ScreenRecorder). If you cannot find it, open Gallery > Albums > Screen recordings.
7. Video files are large. See Section 11 for sending them.
8. Also record a short 10 to 20 second video of the phone case-off on the table with a timestamp visible if you saw shaking or heat, only if it is easy.

## 10. Gesture tests and save-kill tests
Exact steps depend on workstream E (`gestures.md`) and F (`platform.md`); these are the generic parts.
1. Gesture test: follow the list in `gestures.md` (unverified until it exists). For each gesture (tap, drag, pinch, two-finger rotate, and so on) write Pass, Fail, or Not tried, and a note. Record a short screen video of any failure.
2. Save-kill test: (a) start the app and make the change the lead names (for example move something or place an item); (b) trigger a save (or wait for auto save as directed); (c) kill the app: open recent apps and swipe the game away; (d) reopen the app; (e) check the change is still there. Record Pass or Fail. Repeat once with the kill done during an action if asked. Note the exact steps you took.
3. Also test: press Home during play and return after 30 seconds (Pass if it resumes), lock and unlock the screen (Pass if it resumes), and rotate the phone if the lead asks (Pass if the layout stays valid).
4. If the app crashes, write the time and what you did just before, and photograph any message.

## 11. Send the results back
Name every file `YYYY-MM-DD_device_test.ext`. Use lowercase, no spaces. Suggested device name: the model with dashes, for example `2026-10-14_redmi-13c_test.md`. If you have several files on one day and device, add a number: `2026-10-14_redmi-13c_test-2.png`. Use `.md` for the form, `.png` or `.jpg` for pictures, `.mp4` for recordings.

Option A: upload through the GitHub website (best for the form and photos).
1. On the phone (Desktop site helps) or a computer, open the repo and go to the folder `docs/phase0/results/`. If it does not exist, ask the lead to create it (a folder cannot be made empty in the browser).
2. Tap Add file, then Upload files. (On a phone this may show as a plus button, or Upload files at the top of the folder. If missing, use Desktop site.)
3. Tap choose your files, choose the photos and form (you may need to pick Browse or Files rather than Photos).
4. Under Commit changes, type a message such as "Add results 2026-10-14 redmi-13c" and choose Create a new branch for this commit and start a pull request if you are asked, or Commit directly to the main branch if the lead told you. Tap Commit changes.
5. Size limit: the browser upload limit is believed to be 25 MB per file and 100 files per upload (unverified: see https://docs.github.com/en/repositories/working-with-files/managing-files/adding-a-file-to-a-repository). A 20-minute screen recording is likely bigger than that.

Option B: email (simplest, best for video and big files).
1. Email the form text (or a photo of it), the screenshots, and the recording to the address the lead gives you (Nathan: this is the lead's own inbox; unverified).
2. Put the same name pattern in each filename. Subject line: "Mulligan Hills device test, YYYY-MM-DD, device".
3. If a file is too large for email (mail services commonly limit to about 25 MB, unverified), upload it to a cloud drive folder (Google Drive, iCloud, or OneDrive) and share the link, with viewing permission for anyone with the link.
4. Then the lead copies the files into `docs/phase0/results/`.

Always send at least: the completed form, one photo of the results screen, and one photo of the phone's About page. A recording is desired for soak runs.

## 12. What to do if something goes wrong
- The app will not install: see Section 4, item 6.
- The phone got too hot to hold comfortably, or shows a temperature warning: stop, note the time, photograph the warning, let it cool. This counts as a result (see `soak_protocol.md`).
- The phone restarts: this is a thermal or crash failure. Note the time. Do not keep retrying.
- You are unsure: stop and ask. A partial honest result is better than a guessed one. Never edit numbers.

## 13. iPhone plan (TestFlight)
Status: NOT YET RUN. iOS builds are workstream A/F work and depend on an Apple Developer account, code signing, and a macOS CI runner. Details unverified: check https://developer.apple.com/testflight/ and https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/.
What Nathan will need to do once a build is uploaded (the lead confirms when):
1. Get an Apple Developer Program membership for the account that will own the app (paid yearly; the price is not stated here because it is unverified; check Apple's site).
2. Install the free TestFlight app from the App Store on the iPhone (and iPad, if used).
3. In App Store Connect (a website), open the app, go to TestFlight, and add Nathan as an Internal Tester with his Apple ID email. (Internal testers are believed to be limited to members of the developer account, up to about 100 people; unverified.)
4. Open the invitation email on the iPhone, tap View in TestFlight, then Install (or Accept, then Install).
5. Open the app from the home screen. Each build in TestFlight has a build number; that is the Build id on the form.
6. Screenshot: press the side button and Volume Up together. Screen recording: Settings > Control Center > add Screen Recording, then swipe down from the top right corner and tap the record button.
7. iPhone battery and model: Settings > General > About (Model Name, Model Number, iOS Version). Settings > Battery for percentage. Low Power Mode OFF (Settings > Battery). Auto-Brightness OFF (Settings > Accessibility > Display & Text Size > Auto-Brightness). Airplane mode as per Section 5.
8. TestFlight builds are believed to expire after 90 days (unverified).
9. Send results back the same way as Section 11. iPhone test builds may have no equivalent of the APK zip; nothing needs to be downloaded from GitHub.
If a TestFlight build is not available for Phase 0, iPhone results are deferred to a later phase; the lead decides in `GATE0.md`.

## 14. Tablet plan
1. Use the same Android APK (Sections 3 and 4) on an Android tablet: same steps, same setup (Section 5), same results form. Write "tablet" in the Device field with the screen size (About tablet shows model; size is usually on the maker's spec page).
2. Tablets have larger screens and therefore more pixels to render; expect worse performance at the same tier than a phone with the same chip (general reasoning, not measured).
3. Run a Quick test at all tiers and one soak (Low or Medium tier first).
4. Test gestures with more room: two-hand pinch, rotate, two-finger pan; also try landscape (rotate) if the lead asks.
5. If the tablet is an iPad, use Section 13.
6. Split-screen and multi-window: do not use in Phase 0 tests.

## 15. Buying guide: low-end benchmark phone
Purpose: a phone that is deliberately weak, so that if the game runs acceptably here it runs on most phones we care about. No prices or stock claims are given (unverified; check current retailers). Look for:
- RAM: 3 to 4 GB is the low-end target; 2 GB is too small to be informative. A phone with 6 GB or more is not "low end" for this purpose.
- Chipset class: an entry-level chip (for example MediaTek Helio G-series or Dimensity 6xxx-class, Qualcomm Snapdragon 4-series, or Unisoc, and the equivalents; examples only, unverified). Avoid flagship or upper mid-range chips (Snapdragon 8-series, 7-series, Dimensity 8xxx and above).
- GPU: the GPU listed for the chipset should be an entry-level Mali or Adreno (for example Mali-G52 or Adreno 610-class; examples only, unverified). It must support Vulkan (the Godot Mobile renderer needs Vulkan; the Compatibility renderer uses OpenGL ES 3.0 and works on more devices; see `forest.md` and https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html, unverified).
- Android version: Android 11 to 14 is a fair target (Godot 4 Android minimum should be verified in the docs: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html, unverified). Avoid very old versions.
- Screen: 60 Hz, HD+ or Full HD+ resolution, about 6 to 6.7 inches is typical. A 90 or 120 Hz panel is not needed.
- Storage: 32 to 64 GB is fine; ensure a few GB free.
- Battery: a removable case is not needed; a normal battery of 4000 mAh or more is fine. A replaceable-battery phone is not needed.
- Buying condition: new or refurbished from a seller with a returns policy. Avoid phones with carrier locks, unknown bootloader state, or "gray market" variants with no warranty.
- Do not buy a phone that appears in Play Console or vendor lists as unsupported for your region (unverified).
- Because the model has not been chosen, the lead should give the list to Nathan and ask which model is available locally in Australia. Check that the phone supports Australian networks if it will ever be used with a SIM (not needed for testing).
- Record model, chipset, GPU, RAM, and Android version on the form for every device.
Second recommendation: if budget allows, also keep one mid-range phone as a control, so we can tell "the code is slow" from "this phone is slow".

## Unverified
- Real workflow name, artifact name, repo URL, and release channels (see `ci.md`).
- Benchmark UI names and buttons (see `forest.md`).
- All Android menu names (vary per maker and Android version).
- GitHub browser upload limits, artifact retention, TestFlight limits, and Apple costs (check the links above).
- Whether the app asks for permissions and whether a debug APK triggers extra Play Protect prompts.
- Screen recording overhead on low-end devices.

## Follow-ups for the lead
- Create `docs/phase0/results/` with a `.gitkeep` and a short README (this workstream may not write outside its own paths).
- Confirm artifact name from `ci.md`, benchmark UI text from `forest.md`, and gesture lists from `gestures.md`, then update the placeholders in this runbook.
- Decide whether iPhone TestFlight is in Phase 0 scope.

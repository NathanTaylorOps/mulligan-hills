# Results Form (copy this file, fill it in, name it YYYY-MM-DD_device_test.md)

> **Historical Phase 0 record.** This template belongs to the original proof stage. Current evidence requirements are defined in `docs/VERIFICATION.md` and the runbooks under `docs/verification/`.

One form per test run (one phone, one renderer, one tier, one mode). Do not edit numbers after the fact. If something is unknown write "unknown". Steps are in `device_runbook.md`. Field names in `code style` are the exact lines on the benchmark results screen. Type your own numbers in; photos alone are not enough.

Which phone: one form per phone. Section 1 says which (A = Samsung Galaxy S22 Ultra, B = low-end Android). Sections 2 to 13 are the same for both; the pass rule in section 7 differs.

## 1. Test identity
- Date (YYYY-MM-DD):
- Tester:
- File name used:
- Phone role (A flagship S22 Ultra / B low-end):
- Test type (install check / quick / soak / gesture / save-kill):
- Run counts as a Gate 0 attempt (yes only for phone B, and only if section 5 of the runbook was followed):

## 2. Device
Phone A, pre-filled (check it is true): Maker and model: Samsung Galaxy S22 Ultra. Chipset: Snapdragon 8 Gen 1 (US model, as told to us; confirm on the phone).
- Maker and model name:
- Model number:
- Android version and build number:
- RAM (GB, or "not found"):
- Chipset and GPU (if known; also copy `device` and `gpu` from the results screen):
- Storage free (GB):
- Screen size and refresh rate (if known):
- Case on or off (should be off):
- Condition (new / used; battery health if known; phone B only):

## 3. Build
- Actions run number and commit id:
- Workflow inputs used: `scene` = ; `renderer` = 
- Downloaded (Actions artifact `android-debug-apk` on the phone / computer transfer / TestFlight):
- `renderer_active` shown on results screen (Compatibility / Mobile / other / unknown):
- `tier` (`low` / `medium` / `high`):
- `mode` (`quick` / `soak`):
- Mode length (Quick 60s / Soak 20min):

## 4. Conditions (all required for a soak)
- Room temperature or feel (cool / warm / hot; number if known):
- Charging (plugged in / on battery):
- Airplane mode (on / off), Wi-Fi (on / off), Bluetooth (on / off):
- Screen brightness (percent) and adaptive brightness (off / on):
- Battery saver (must be off):
- Do Not Disturb (on / off):
- Phone placed on (table / hand / other):
- Screen recording during test (yes / no):
- Fan or air conditioning notes:
- Phone restarted and cooled 3 minutes before start (yes / no):

## 5. Battery (typed by hand: Godot has no battery reading, and the results screen shows -1)
- Battery percent at start:
- Battery percent at 10 minutes (soak, optional):
- Battery percent at end:
- `battery_start_pct` and `battery_pct` as shown on screen (expected -1):

## 6. Performance numbers (copy from the results screen; attach a photo)
- Test start time and end time:
- `verdict` (`PASS_30FPS` / `FAIL_30FPS` / `NO_DATA`; informational only):
- `duration_s`:
- `frames`:
- `avg_fps`:
- `min_fps` (under 10 = a frame over 100 ms):
- `p50_ms`:
- `p95_ms`:
- `p99_ms`:
- `pct_over_33ms`:
- `max_ms` (only in the pasted Copy JSON):
- `draw_calls_avg` and `draw_calls_max`:
- `primitives_avg`:
- `static_mem_max_mb` and `video_mem_max_mb`:
- `render_scale` (below 1.0 means the game lowered its resolution to keep up):
- `throttle_ratio` (soak; 0.85 or more wanted):
- `thermal` line as shown (expected "not available"):
- Photo file names:
- Pasted JSON note or file name (from Copy JSON; write "not available" if it did not work):

## 7. Pass or fail
Gate 0 rule (phone B only, DEC-047, placeholders until measured). Phone A results are recorded for information and cannot pass Gate 0.
- `avg_fps` is 30 or higher (yes / no):
- `p95_ms` is under 33 (yes / no):
- `min_fps` is 10 or higher, no frame over 100 ms (yes / no):
- `throttle_ratio` is 0.85 or higher (soak only; yes / no):
- No thermal shutdown, restart, crash or freeze (yes / no):
- Overall (PASS / FAIL / INVALID / not a gate run):
Phone A only, information: 60 fps target check: `avg_fps` about 60 and `p95_ms` about 17 or less (yes / no):

## 8. Thermal notes
- Phone felt (cool / warm / hot / too hot to hold) at start, 5, 10, 15 and 20 minutes:
- Any thermal warning message (photograph it):
- Did the frame rate drop over time (describe when):
- Any screen dimming by the phone (yes / no):
- Time to cool back to normal after test (minutes, if noted):

## 9. Crashes
- Did the app close or freeze (yes / no):
- Did the phone restart (yes / no):
- Time it happened (minutes into the test):
- What was on screen before it happened:
- Message shown (photograph it):

## 10. Gesture test (gesture sandbox build; Phone A first; results are from `gestures.md` steps, NOT YET RUN)
| Step | What should happen | Result (Pass / Fail / Not tried) | Note |
| --- | --- | --- | --- |
| 1 | Green ground, one tall red post, three shorter grey posts |  |  |
| 2 | Tap top-left square: black text box appears |  |  |
| 3 | One finger drag: yellow squares, `state: painting`, `fingers: 1` |  |  |
| 4 | Lift: `state: idle`, started and ended counters up |  |  |
| 5 | Second finger during a drag: squares vanish, `cancelled` +1, `state: camera` |  |  |
| 6 | Pinch apart and together: zoom, stops at a limit (which direction felt right or wrong?) |  |  |
| 7 | Two-finger twist: world turns with fingers (wrong way? jump past half a turn?) |  |  |
| 8 | Two fingers slide: world follows |  |  |
| 9 | Lift one finger, keep dragging: nothing paints, `state: camera` |  |  |
| 10 | Late second finger, 10 tries: number of yellow squares left behind = |  |  |
| 11 | Three fingers: nothing paints, camera still, `state: ignored` |  |  |
| 12 | Compass button (top right): red post returns to top of screen |  |  |
| 13 | Palm or thumb at the screen edge: stray marks? |  |  |
- Did painting feel delayed at the start of a stroke (one sentence):
- Gate 0 item 6 names 12 cases (tilt limit, long press, undo during gesture and others are not in the steps above): the lead will supply the checklist. Tick here if done: 

## 11. Save-kill test (only when the lead says a build with saving exists)
- Steps done (write what you did):
- App killed by swiping away in recent apps (yes / no):
- After reopening, was the change still there (Pass / Fail):
- Home button and return after 30 seconds (Pass / Fail):
- Lock and unlock screen (Pass / Fail):
- Notes:

## 12. Observations
Free text. Anything that looked odd: flicker, missing trees, stretched textures, black screens, lag when touching, heat, battery drain, slow loading, results text cut off at the bottom.

## 13. Files attached
- Results screen screenshot:
- Other screenshots:
- Pasted JSON:
- Screen recording:
- About-phone photo:
- Sent by (GitHub upload / email / cloud link):

# Soak Protocol (Phase 0): 20 minute thermal and stability test

> **Historical Phase 0 record.** This file contains the original soak-test procedure. Current physical-device and performance evidence should follow `docs/verification/DEVICE_TESTING.md` and `docs/verification/PERFORMANCE.md`.

Owner: workstream I (device). Status: written, NOT YET RUN. Thresholds updated 2026-09-29 to DEC-046 and DEC-047 (placeholders until measured). Steps for the manager are in `device_runbook.md` (sections 6 A4 and 7 B2).

## 1. Purpose
Show that the benchmark scene holds a playable frame rate on a low-end phone for 20 minutes, after the phone heats up. Short tests hide thermal throttling: many phones run fast for a few minutes and then slow down.

## 2. Pass thresholds (all must hold)
Gate 0 pass evidence comes from the LOW-END phone only. A soak on the Galaxy S22 Ultra is a learning run; record it, but it cannot pass Gate 0.
1. `avg_fps` over the 20 minutes is 30 or higher.
2. `p95_ms` (95 percent of frames) is under 33 ms.
3. No single frame over 100 ms: `min_fps` on the results screen is 10 or higher (min fps is 1000 divided by the slowest frame). The exact slowest frame is `max_ms`, visible only in the pasted Copy JSON.
4. No thermal shutdown, no phone restart, no app crash, no freeze needing a force close.
5. `throttle_ratio` is 0.85 or higher (last 5 second window divided by first 5 second window; proposed in `forest.md`, not from GATE0).
Averages in the code (`MHBenchStats.summarize`) are whole-run: frames counted over the full duration. The 5 second window averages are in `bench.json` only (private to the app, not reachable from the phone). The on-screen `verdict` uses p95 34.0 ms and no stall check; trust the numbers above, not the word.
For the flagship S22 the 60 fps target (DEC-047) is read from `avg_fps` and `p95_ms` of about 17 ms; it is a goal, not a Gate 0 pass rule.

## 3. Conditions (fix and record)
- Device: the low-end benchmark phone first; then the tablet; then any other.
- Tier: each tier separately (buttons `Low`, `Medium`, `High`), Low first. The tier the game will ship on this class of device must pass.
- Renderer: one soak per build; the results screen line `renderer_active` shows which ran. Record it.
- Start: phone at room temperature, restarted, idle 3 minutes, battery 50 to 100 percent.
- Case off; brightness about 50 percent fixed; battery saver off; Do Not Disturb on; other apps closed; airplane mode on unless a network is needed; phone flat on a hard table; steady room temperature; no fan aimed at the phone.
- Charging: run 1 plugged in, run 2 on battery. Do not mix within a run. Compare results between modes; if only one run is possible, use plugged in and say so.
- Recording: one run with screen recording, one without, to see recorder overhead.
- Runs: at least 2 soaks per tier per device on different days or after a 30 minute cool-down, to see variance.

## 4. Procedure
1. Complete the setup above and note the room temperature and battery percent.
2. Select the quality tier.
3. Start screen recording if this is a recorded run.
4. Tap `Soak 20min` and start a timer at the same moment.
5. Do not touch the phone for 20 minutes. Note the phone's feel (cool / warm / hot) at 5, 10, 15 and 20 minutes by touching only the back edges with a finger, not the screen.
6. If a thermal warning appears, photograph it, write the time, and let the test continue unless the phone is unsafe to hold (too hot to touch for 3 seconds): then stop and record failure by heat.
7. At the end, photograph the results screen before doing anything else. Stop the recording. Record end battery percent.
8. Let the phone cool for at least 15 minutes before another run.
9. Fill in `results_template.md` and send everything (see runbook Section 11).

## 5. What to log
- Everything in the results form: device, build id, renderer, tier, battery start and end, conditions.
- `avg_fps`, `min_fps`, `p95_ms`, `p99_ms`, `pct_over_33ms`, `render_scale`, `throttle_ratio` from the results screen. Battery percent at start and end is typed by hand because Godot has no battery reading (the screen shows -1).
- The app writes `bench.json` every 5 seconds to its private storage (`user://bench.json`) with per-window numbers. It cannot be opened from the phone; use the `Copy JSON` button for the final numbers. Temperature is not recorded by Godot; use the hand-touch notes. A computer with USB debugging could read `adb shell dumpsys thermalservice` during the run, if the lead asks.
- Times: start, when frame rate visibly dropped, any warning, end.
- Phone feel at 5, 10, 15, 20 minutes.
- Photos: results screen, About page, any warning.
- Video for at least one run per device and tier.

## 6. What counts as failure
Any one of these fails the run:
- `avg_fps` under 30.
- `p95_ms` of 33 or more.
- `min_fps` under 10 (a frame over 100 ms).
- `throttle_ratio` under 0.85.
- Thermal shutdown, self-restart, black screen with a return to the launcher, or a crash during the test.
- Freeze: the picture does not change for 10 seconds or more (not counting the intended scene), or the app needs a force close.
- The test stops before 20 minutes for any reason.
- The phone is too hot to hold (uncomfortable to touch for 3 seconds) or shows a critical temperature warning.
- Results screen not shown or numbers cannot be read (not a performance failure but an invalid run: repeat).
Note that a phone-imposed brightness reduction or a throttling notice is not failure by itself; record it, and check the numbers.

A run is INVALID (repeat it, do not count it) if the tester touched the screen during the test, a call or notification interrupted it (for reasons other than the app), the phone started warm, the battery was below 20 percent, or conditions changed mid-run.

## 7. Interpreting results (for engineers)
- Compare average with the last 5 minutes: a large drop means thermal throttling even if the whole-run average passes.
- Compare plugged in and on battery, recorded and unrecorded.
- Compare tiers: if Low fails, Phase 0 renderer work must reduce cost (fewer instances, cheaper materials, lower resolution scale); if only High fails, ship Low or Medium as default on this class of device.
- Two runs that differ by more than about 10 percent in average FPS mean the conditions are not controlled; find out why before deciding.

## 8. Gate 0 link
This soak addresses Gate 0 item 2 (`GATE0.md`). Evidence required: at least one PASS soak at the target tier on the low-end phone, with results form, results screen photo, pasted JSON and build id. `GATE0.md` row 2 wording (p95 40 ms) is superseded by the 33 ms and 100 ms stall rules above (DEC-047).

## Unverified
- Whether Copy JSON works on Android and whether the results text fits the screen.
- Whether Android obeys the app's keep-screen-on request.
- All numbers are placeholders until measured on the real low-end phone.

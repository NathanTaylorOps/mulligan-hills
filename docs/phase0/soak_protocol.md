# Soak Protocol (Phase 0): 20 minute thermal and stability test

Owner: workstream I (device). Status: written, NOT YET RUN. Thresholds come from the task brief; confirm against `GATE0.md`. Steps for the manager are in `device_runbook.md`.

## 1. Purpose
Show that the benchmark scene holds a playable frame rate on a low-end phone for 20 minutes, after the phone heats up. Short tests hide thermal throttling: many phones run fast for a few minutes and then slow down.

## 2. Pass thresholds (all must hold)
1. FPS average over the 20 minutes is 30 or higher.
2. p95 frame time is under 50 ms (95 percent of frames finish within 50 ms).
3. No thermal shutdown, no phone restart, no app crash, and no freeze needing a force close.
Confirm the definition of the average with workstream D (`forest.md`): whole-run average, or per-interval. Report the whole-run number, and also the last 5 minutes if the app shows it (unverified).

## 3. Conditions (fix and record)
- Device: the low-end benchmark phone first; then the tablet; then any other.
- Tier: each tier separately, Low first. The tier the game will ship on this class of device must pass.
- Renderer: as built by CI; record what the screen shows.
- Start: phone at room temperature, restarted, idle 3 minutes, battery 50 to 100 percent.
- Case off; brightness about 50 percent fixed; battery saver off; Do Not Disturb on; other apps closed; airplane mode on unless a network is needed; phone flat on a hard table; steady room temperature; no fan aimed at the phone.
- Charging: run 1 plugged in, run 2 on battery. Do not mix within a run. Compare results between modes; if only one run is possible, use plugged in and say so.
- Recording: one run with screen recording, one without, to see recorder overhead.
- Runs: at least 2 soaks per tier per device on different days or after a 30 minute cool-down, to see variance.

## 4. Procedure
1. Complete the setup above and note the room temperature and battery percent.
2. Select the quality tier.
3. Start screen recording if this is a recorded run.
4. Tap Soak and start a timer at the same moment.
5. Do not touch the phone for 20 minutes. Note the phone's feel (cool / warm / hot) at 5, 10, 15 and 20 minutes by touching only the back edges with a finger, not the screen.
6. If a thermal warning appears, photograph it, write the time, and let the test continue unless the phone is unsafe to hold (too hot to touch for 3 seconds): then stop and record failure by heat.
7. At the end, photograph the results screen before doing anything else. Stop the recording. Record end battery percent.
8. Let the phone cool for at least 15 minutes before another run.
9. Fill in `results_template.md` and send everything (see runbook Section 11).

## 5. What to log
- Everything in the results form: device, build id, renderer, tier, battery start and end, conditions.
- FPS average, minimum, p95, and p99 if shown.
- If the app writes a log or CSV (unverified; ask workstream D): its per-interval frame time and FPS, temperature if available, and the location of the file so it can be copied off (for example Files > Android > data, which may be blocked on Android 11 and later; unverified).
- Times: start, when frame rate visibly dropped, any warning, end.
- Phone feel at 5, 10, 15, 20 minutes.
- Photos: results screen, About page, any warning.
- Video for at least one run per device and tier.

## 6. What counts as failure
Any one of these fails the run:
- FPS average under 30.
- p95 frame time of 50 ms or more.
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
This soak addresses the forest and rendering performance proof item in `GATE0.md` (item numbers there are authoritative; unverified here). Evidence required: at least one PASS soak at the target tier on the low-end phone, with results form, results screen photo, and build id.

## Unverified
- Exact Soak button name, log output, and average definition in the benchmark (workstream D).
- Whether the thresholds match `GATE0.md`.
- Whether per-interval or temperature logging exists.

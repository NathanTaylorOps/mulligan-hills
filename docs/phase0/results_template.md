# Results Form (copy this file, fill it in, name it YYYY-MM-DD_device_test.md)

One form per test run (one tier, one mode). Do not edit numbers after the fact. If something is unknown write "unknown". Steps are in `device_runbook.md`.

## 1. Test identity
- Date (YYYY-MM-DD):
- Tester:
- File name used:
- Test type (quick / soak / gesture / save-kill):

## 2. Device
- Device type (phone / tablet / iPhone / iPad):
- Maker and model name:
- Model number:
- Android or iOS version:
- RAM (GB, or "not found"):
- Chipset and GPU (if known):
- Storage free (GB):
- Screen size and refresh rate (if known):
- Case on or off (should be off):

## 3. Build
- Build id (Actions run number and commit id, or TestFlight build number):
- Where downloaded (Actions artifact / computer transfer / TestFlight):
- Renderer shown on screen (Mobile / Compatibility / Forward+ / unknown):
- Quality tier (Low / Medium / High / Auto):
- Mode (Quick / Soak 20 minutes):

## 4. Conditions (must be recorded for soak)
- Room temperature or feel (cool / warm / hot; number if known):
- Charging (plugged in / on battery):
- Airplane mode (on / off), Wi-Fi (on / off), Bluetooth (on / off):
- Screen brightness (percent) and adaptive brightness (off / on):
- Battery saver / Low power mode (must be off):
- Do Not Disturb (on / off):
- Phone placed on (table / hand / other):
- Screen recording during test (yes / no):
- Fan or air conditioning notes:

## 5. Battery
- Battery percent at start:
- Battery percent at end:
- Battery percent at 10 minutes (soak, optional):

## 6. Performance numbers (copy from the results screen; attach a photo)
- Test start time and end time:
- FPS average:
- FPS minimum:
- p95 frame time (ms):
- p99 frame time (ms, if shown):
- Frame count or run duration shown:
- Any other numbers on the screen:
- Photo file names:

## 7. Pass or fail (soak only; see `soak_protocol.md`)
- FPS average is 30 or higher (yes / no):
- p95 frame time is under 50 ms (yes / no):
- No thermal shutdown, restart, or crash (yes / no):
- Overall (PASS / FAIL):

## 8. Thermal notes
- Phone felt (cool / warm / hot / too hot to hold) at start, 10 min, end:
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

## 10. Gesture test results (Pass / Fail / Not tried; list from `gestures.md` when it exists)
| Gesture | Result | Note |
| --- | --- | --- |
| Single tap |  |  |
| Drag / pan |  |  |
| Pinch zoom |  |  |
| Two-finger rotate |  |  |
| Long press |  |  |
| Other (from gestures.md) |  |  |

## 11. Save-kill test results
- Steps done (write what you did):
- App killed by swiping away in recent apps (yes / no):
- After reopening, was the change still there (Pass / Fail):
- Home button and return after 30 seconds (Pass / Fail):
- Lock and unlock screen (Pass / Fail):
- Notes:

## 12. Observations
Free text. Anything that looked odd: flicker, missing trees, stretched textures, black screens, lag when touching, sound, heat, battery drain, slow loading.

## 13. Files attached
- Results screen photo:
- Screenshot(s):
- Screen recording:
- About-phone photo:
- Sent by (GitHub upload / email / cloud link):

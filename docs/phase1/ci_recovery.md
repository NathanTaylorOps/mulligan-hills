# CI recovery after the 25-minute day change

5 October 2026. At a1d0037, Android debug APK and screenshots/bench workflows passed; main CI imported successfully and ran 984 Godot tests with zero errors and two failures. Personal-golfer Python checks passed. Determinism did not run because its workflow has path filters; missing run is not a pass.

Failures: `test_speed_hook_is_pure_token_arithmetic` expected 15 earned tokens to cover two accelerated days (old 15-minute duration). DEC-070 keeps token rates and now requires 25 tokens for two days; one-day whole-token quote is 13. Updated assertions explicitly check both quotes, affordability and unchanged balance. `test_autosave_policy_matches_clock_hour_events` stepped only 900 seconds, so reached seven save boundaries rather than twelve. Test now asserts the locked 1500-second duration and steps a full day. Production economy/clock behavior unchanged.

Local gdparse and schema validation checked; runtime fixes require new CI evidence. No main merge or device completion claim. Existing 1014 reported orphan nodes/resources need separate investigation; CI failure disposition was the two assertions, not an established clean resource lifecycle. Next priority remains personal-shot outcomes/profile/training after these regression fixes.

Expanded determinism push paths to all game tests and Python references so economy/save regressions and new reference changes also request the cross-platform check. Documentation-only commits remain filtered.

At a1d0037, all inspected gameplay session/save/aiming tests passed, including camera follow/overview preservation, screen-aim projection, camera inertia cancellation and target bounds. This is headless runtime evidence, not rendered/device acceptance.

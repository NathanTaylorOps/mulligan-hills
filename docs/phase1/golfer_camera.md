# Phase 1: personal-practice camera follow

Status: 5 October 2026. Implemented; syntax/schema checks PASS. Godot tests, rendered framing and device evidence NOT YET RUN. Independent review in `golfer_camera_verification.md`.

## Built

The practice camera recentres after opening, starting/restarting a round and committing a shot. **Course overview** switches to the full development patch and suspends follow. **Back to golfer** restores follow to the current ball. There is still only a ball marker, not a finished golfer avatar. Camera controls do not affect money, course rating or player shot state. Modal actions are refused. Opening practice and the two camera buttons clear pending aim contacts.

`MHOrbitRig.focus_target` clears residual pan/spin/snap, clamps the configured target/distance and preserves yaw. `MHCameraController.focus_target` applies that presentation state and emits the existing camera-change signal. No new engine API was needed: existing rig maths and transform calls were reused. No unverified new API signature identified; runtime behavior is pending.

Follow distance100, overview distance150 and a downward framing bias20m are provisional values for this small prototype. They need real phone tuning; the bias is a camera target, not a change to course elevation. Movement is immediate, not animated ball flight or eased follow. Camera preference is transient; committed practice progress still saves. Existing world camera gestures remain suppressed while the practice panel is open.

## Checks

- gdparse on changed scripts/tests: PASS, syntax only.
- `python3 docs/spec/data/validate.py`: ALL PASS.
- Pending Godot regressions: focus stops inertia/snap without changing yaw, configured bounds/distances hold, overview/back leave practice/cash unchanged, shots recenter only while follow is enabled.
- Official sim/rating/economy data unchanged; no golden regeneration required.

## Golfer model proposal

`docs/spec/golfer_controls.md` specifies a proposed seven-attribute model, meaningful shot-style responsibilities, player-sim version boundary, deterministic preview/resume and training/match settlement requirements. This is a working specification, not implemented gameplay or locked coefficients. DEC-076 remains the approved automatic-execution control choice.

## Next and Nathan checks

Once CI produces a green APK, run Sim hash and Benchmark Quick 60s first. In one-hole practice, confirm that a shot moves the camera to the ball, Course overview keeps the wide view after the next shot, and Back to golfer returns to the current ball. Report whether the ball/cup remain visible above the controls. Do not judge final art or golfer progression from the current marker.

Next implement a separate integer personal-golf Python reference for attribute-specific straight/recovery/putting behavior, with measured test-hole choices; then a persistent golfer profile and training rewards. Curved/punch/high-spin styles need actual trajectory/interception rules before exposing buttons. CI and device evidence still gate merging.

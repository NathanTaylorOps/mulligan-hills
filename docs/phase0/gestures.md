# Workstream E: Gestures (touch camera vs brush painting)

Status: code and tests WRITTEN. NOT YET RUN. Nothing here has been executed, parsed by Godot, or tried on a device.

## README block
- Purpose: prove one-finger painting and two-finger camera control do not fight each other on a phone.
- Public API: `MHGestureStateMachine` (signals `stroke_started(screen_pos)`, `stroke_moved(screen_pos)`, `stroke_ended()`, `stroke_cancelled()`, `camera_gesture(pan_px, zoom_ratio, twist_rad)`, `camera_gesture_ended()`, `state_changed(state)`), `MHCameraController.camera_changed()`, `MHStrokeSink` (`begin_stroke()`, `apply_brush_at(cell_x, cell_y)`, `end_stroke()`, `cancel_stroke()`), `MHStrokeBridge` (signals to sink).
- How tests run: gdUnit4 on `res://tests/input/` (CI installs gdUnit4, workstream A). Local: Godot editor, GdUnit4 panel, run `tests/input`.
- Gate 0: touch camera plus brush gesture proof item.

## 1. What was built
All under `game/input/` unless noted.
- `mh_gesture_math.gd` (`MHGestureMath`): pure math. Angle wrap at PI, twist delta, pinch ratio, orbit offset, ground-plane pan, easing.
- `mh_gesture_config.gd` (`MHGestureConfig`): dead zone (10 px), commit window (80 ms), long-press option (off), tap dab, edge margin.
- `mh_touch_tracker.gd` (`MHTouchTracker`): fingers by index from `InputEventScreenTouch` and `InputEventScreenDrag`. Edge rejection and `reject_filter` palm hook.
- `mh_gesture_state_machine.gd` (`MHGestureStateMachine`): IDLE, PENDING, PAINTING, CAMERA, IGNORED. Time is passed in, so no scene needed.
- `mh_camera_config.gd` (`MHCameraConfig`, Resource): every camera parameter including master `sensitivity`.
- `mh_orbit_rig.gd` (`MHOrbitRig`): pure orbit camera state. Named so because `game/render/mh_camera_rig.gd` already defines `MHCameraRig`.
- `mh_camera_controller.gd` (`MHCameraController`, Node3D): applies the rig to a Camera3D, desktop helpers.
- `mh_stroke_sink.gd` (`MHStrokeSink`), `mh_forwarding_stroke_sink.gd` (dynamic-call adapter for the terrain object), `mh_stroke_bridge.gd` (`MHStrokeBridge`, screen to cell).
- `mh_input_router.gd` (`MHInputRouter`): real input, desktop mapping, UI tap regions, focus-loss cancel.
- `mh_debug_overlay.gd`, `mh_compass_button.gd`: overlay (top-left corner square toggles) and compass (top-right, tap = snap north).
- `mh_gesture_sandbox.gd` and `.tscn`: standalone proof scene, flat ground, yellow dabs, red post marks north. A cancelled stroke deletes its dabs.
- Tests in `game/tests/input/`: `test_gesture_math.gd`, `test_gesture_state_machine.gd`, helpers `input_test_helpers.gd`, `mock_stroke_sink.gd`.

### Behaviour rules
1. First finger down: PENDING. The stroke starts when the finger has been down 80 ms, or moves more than 10 px, whichever is first. Stroke start replays the original touch position, then the current position.
2. Second finger while PENDING: CAMERA, no stroke ever starts (late second finger).
3. Second finger while PAINTING: `stroke_cancelled` (sink must roll back), then CAMERA.
4. CAMERA and IGNORED last until ALL fingers lift. A lifted finger never returns to painting. A new second finger during CAMERA resumes camera only.
5. Three or more fingers: cancel any stroke, ignore everything until all lift.
6. A quick tap (lift before commit) paints one dab. App pause or focus loss calls `cancel_all()`.
7. Long press option: set `long_press_ms` above 0. Painting then needs a still hold that long. Moving early makes the touch inert until lift, taps do nothing. Off by default.
8. Camera: twist yaw from the two-finger angle delta (wrapped at PI, positive = clockwise on screen), pinch zoom `distance / ratio^(zoom_sensitivity*sensitivity)` clamped, two-finger pan on the ground plane scaled by distance, tilt limited 25 to 70 degrees and by default derived from zoom, compass snap to yaw 0 by the shortest way with exponential ease, optional inertia for pan and yaw.
9. Desktop: left-drag paint, right-drag rotate (x yaw, y tilt only if `tilt_follows_zoom` is false), wheel zoom, middle-drag pan.

## 2. How it is tested
Written, NOT YET RUN: gdUnit4 tests using synthetic `InputEventScreenTouch` and `InputEventScreenDrag` for single-finger paint, fast drag start, tap dab, second-finger cancel, late second finger, second finger after the window, no paint resume after lift, camera resume, three-finger ignore, twist math (quarter turn, wrap at PI, degenerate), pinch clamp, tilt clamp, snap north easing, pan bounds, edge rejection, palm hook, long press, canceled touch, focus loss, desktop stroke, bridge with `MHMockStrokeSink` (rollback and missing cell).
Not run at all: every script, the sandbox scene, the router, overlay, compass, controller node. No real touch hardware has been used.

## 3. Gate 0 criteria and CI evidence
- Evidence CI must produce: gdUnit4 report with all `tests/input` cases passing on Ubuntu and macOS, and no GDScript parse errors when the project loads.
- Real evidence still needed: the phone script below, with results recorded by Nathan.

## 4. Unverified assumptions
Check against https://docs.godotengine.org/en/stable/ (classes InputEventScreenTouch, InputEventScreenDrag, Camera3D, Node3D, Control, ProjectSettings).
- `InputEventScreenTouch.canceled` exists in the targeted 4.x versions.
- Project setting paths `input_devices/pointing/emulate_mouse_from_touch` and `input_devices/pointing/emulate_touch_from_mouse`. Both must be false in `project.godot` (workstream A owns that file; not edited here).
- Inner classes (`MHGestureMath.TwoFingerDelta`, `MHInputTestHelpers.Recorder`) referenced from other scripts, and an inner class extending a `class_name` class (sandbox).
- `Node3D.look_at_from_position` works with the controller at identity transform.
- Twist and compass sign conventions were derived by hand (yaw 0 = camera on +Z looking -Z). `twist_sign` flips twist if it feels backwards. Needle direction may be mirrored.
- Whether Controls receive raw touch with mouse emulation off is unknown, so UI taps use manual rect hit tests in `_input`. If a Control or other node consumes touches before `_input`, the corner tap or compass could fail.
- Signal connections on a `RefCounted` bridge or machine may drop if nothing references them. The router stores both.
- `NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_WM_WINDOW_FOCUS_OUT` fire as expected on Android.
- gdUnit4 assertion names (`assert_vector().is_equal_approx`, `assert_array().contains_exactly`) match the vendored gdUnit4 version.
- Default numbers (80 ms, 10 px, sensitivities, pan speed, tilt) are guesses.
- Fixed ground plane at y=0 in the sandbox; the real terrain needs a real ray cast supplied as `screen_to_cell`.

## 5. Risks and follow-ups
- 80 ms start latency may feel laggy, or too short for slow second fingers. Tune on device.
- Fast strokes leave gaps: one brush apply per drag event, no interpolation between samples. Terrain or a follow-up should interpolate.
- Camera has no dead zone: tiny finger differences during a pinch also pan and twist. Add per-axis thresholds if it feels sloppy.
- No touch contact size in Godot events, so palm rejection is position rules only.
- No touch tilt gesture. Tilt follows zoom by default.
- Sensitivity is a resource field only. A settings screen and saving are not built.
- Lead or workstream A: set `res://input/mh_gesture_sandbox.tscn` as the main scene for the gesture test build, and confirm the two emulate settings above.
- Terrain must make `cancel_stroke()` a real rollback.

## 6. Update 2026-09-29: picking sentinel fix and terrain-connected gesture scene
- Bug found: `MHPicking.MISS` is `Vector2i(-1, -1)` but `MHStrokeBridge.NO_CELL` is `Vector2i(INT_MIN, INT_MIN)`. A picker returning `MISS` straight into the bridge would dab cell (-1, -1) instead of skipping.
- Fix: `game/input/mh_cell_sentinel.gd` (`MHCellSentinel`): `from_pick(cell)` (MISS to NO_CELL), `from_ground_hit(hit)` (flat plane, used by `mh_gesture_sandbox.gd`), `pick_terrain(grid, origin, dir)`, and `MHCellSentinel.TerrainPicker` whose `screen_to_cell` Callable is what `MHInputRouter.setup` takes for a real terrain. Rule: every `screen_to_cell` handed to the router or bridge must return one of these helpers' results. Tests: `game/tests/input/test_cell_sentinel.gd` (NOT YET RUN).
- The terrain-connected gesture scene is `res://gate0/terrain_paint.tscn` (600 x 400 cells, real `MHTerrainEditor`, Undo/Redo buttons, router on the real pick). Its unit tests live in `game/tests/gate0/`. See `docs/phase0/gate0_scenes.md`. Still NOT YET RUN on any device.
- UI buttons: with `emulate_mouse_from_touch` off, Godot `Button` nodes may not react to a finger (unverified). The Gate 0 panel therefore hit-tests its buttons on raw touch, and the terrain scene registers them as router UI regions so a button tap never paints.

## For Nathan
Prerequisite: the lead tells you an Android build with the gesture sandbox scene is ready and where to download it. If not told, stop here; there is nothing for you to do yet.

Phone test script (about 10 minutes). Use a phone with normal use, not a case-less slippery one.
1. Install the build on the phone and open the app. You should see a green ground, one tall RED post, and three shorter grey posts.
2. Tap the small square outline in the top-left corner of the screen. A black box with text should appear. If it does not, write "overlay failed" and stop.
3. Put ONE finger on the ground and drag slowly. Yellow squares should appear under your finger. The box should say `state: painting` and `fingers: 1`.
4. Lift your finger. The box should say `state: idle`. `strokes started/ended/cancelled` should show 1 or more started and ended.
5. Start a new drag with one finger. While still dragging, put a SECOND finger down. The yellow squares of that drag should disappear, `cancelled` should go up by 1, and the state should say `camera`. Write down if the squares did not disappear.
6. Keep both fingers down and move them apart, then together. The view should zoom in and out and stop at a limit. Write down which direction felt right or wrong.
7. Twist your two fingers like turning a dial. The world should turn with your fingers. Write down if it turns the wrong way. Twist through more than half a turn and note any jump.
8. Slide both fingers together in one direction. The world should follow your fingers.
9. Lift ONE finger and keep dragging with the other. Nothing should be painted, and the state should stay `camera`. Then lift the last finger.
10. Do it 10 times: put one finger down, and about a fifth of a second later (fast, slightly late) put a second finger down. Count how many times a yellow square stays behind. Write the number down.
11. Put three fingers on the screen and move them. Nothing should paint and the camera should not move; state says `ignored`.
12. Twist the view so the red post is not at the top of the screen. Tap the round compass in the top-right. The view should ease back until the red post is straight ahead (far side of the ground, top of the screen).
13. Rest the side of your palm or thumb at the very edge of the screen while painting with another finger. Write down whether stray marks appear.
14. Send Claude: the answers for steps 2, 5, 6, 7, 9, 10 (the number), 12, 13, and one sentence on whether painting felt delayed at the start of a stroke.

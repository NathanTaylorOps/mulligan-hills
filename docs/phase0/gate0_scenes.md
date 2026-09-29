# Gate 0 phone scenes

Status 2026-09-29: every scene and test below is WRITTEN, NOT YET RUN. No Godot was available, so nothing has been parsed, loaded, or tried on a phone. Owner: workstream E (files under `game/gate0/`, tests under `game/tests/gate0/` and `game/tests/input/`).

All scenes show a big text panel: title, a live line, a result box, large buttons, and four built-in buttons: `Copy` (whole result text to the clipboard), `Up` and `Down` (scroll the result box), `Back` (returns to `res://ui/mh_launcher.tscn` if that scene is in the build). Every result is also written to `user://gate0_<name>.txt` on the phone. Each result ends with (or offers) an evidence JSON block with the fields `docs/phase0/GATE0.md` requires: `item`, `commit_sha`, `godot_version`, `device`, `renderer`, `date_utc`, `result`, plus measurements. `commit_sha` comes from `res://build_info.json` (CI writes it); it reads `dev` if that file is missing.

## How to launch a scene (Android debug APK workflow)
1. GitHub, Actions tab, `Android debug APK`, Run workflow.
2. `game_path` = `game`. Paste the `scene` value from the table below. `renderer` = `compatibility` (the project default).
3. Run, wait for green, download artifact `android-debug-apk`, install. Same steps as `docs/phase0/device_runbook.md` sections 3A to 3C.

| Scene | `scene` input value |
| --- | --- |
| Sim hash (items 3, 4) | `res://gate0/sim_hash.tscn` |
| Terrain paint (items 5, 4 fps) | `res://gate0/terrain_paint.tscn` |
| Save and kill (item 10) | `res://gate0/save_kill.tscn` |
| Animation cost (item 9, cost half) | `res://gate0/anim_cost.tscn` |

Note: `game/ui/mh_launcher.gd` (not my file) lists the first three but not `anim_cost.tscn`. If the launcher is the main scene, the lead must add `["Gate 0: animation cost", "res://gate0/anim_cost.tscn"]` to its `SCENES` list, or launch it through the `scene` input above.

## 1. Sim hash: `res://gate0/sim_hash.tscn`
Files: `sim_hash.gd`, `mh_gate0_sim.gd`. Item 3 (hash on the phone) and one figure for item 4.

What it proves: the golden sim runs (4x3, 10x18, 60x18 golfers x holes, course seed 20260929, base seed 777) hash on the phone to the same 64-bit hex values that Linux, macOS and the Python reference produce (`c36530956ac94b59`, `e78ef50b1b29abe7`, `7fe28c37437e041a`). The values are compiled into `mh_gate0_sim.gd` because the Android export excludes `tests/*`; `test_gate0_sim.gd` fails if they drift from `game/tests/core/golden/shotsim.json`.

What to tap:
1. Open the app. It runs three passes by itself (the 60x18 row can take many seconds on a phone; the live line names the row being run).
2. Read the result box. Each row says `PASS` or `FAIL`, shows `got` and `expected`, and the time. The bottom lines say `all hashes match golden: YES` and `identical across 3 passes: YES`. Item 3 needs three consecutive runs: `Run 3 passes` starts a fresh set.
3. `Evidence JSON` replaces the box with the item 3 evidence (hashes of the last pass, `arch_arm64`, result `pass` only if 3 passes all match). Tap `Copy` and send it to the lead.
4. `Sim cost 24x18` (item 4 figure): times 24 golfers x 18 holes three times on the MAIN thread with hashing off, and prints microseconds per simulated second and the implied cost per frame at 4x speed and 60 fps, with a verdict against the proposed budgets (2 ms main thread, 4 ms worker).

What the numbers mean: `us per sim second` is wall time of the whole round divided by the longest golfer's simulated round length. `per frame` = that x 4 / 60. It is an AVERAGE over a whole round on the main thread, not a per-frame histogram and not a worker-thread measurement. The real item 4 criterion (p99, worker thread, 5 minutes, item 2 scene active) is NOT covered: no such scene exists.

## 2. Terrain paint: `res://gate0/terrain_paint.tscn`
Files: `terrain_paint.gd`, `mh_gate0_terrain_api.gd`, `mh_gate0_terrain_sink.gd`, `mh_gate0_terrain_check.gd`; input side `game/input/mh_cell_sentinel.gd`. Item 5 (and the fps half of it).

What it proves: a 600 x 400 cell `MHHeightGrid` with `MHTerrainEditor` and `MHTerrainChunks` runs on the phone with the real gesture router, and the scripted item 5 sequence holds: 50 strokes, 50 undos back to the exact initial hash, 50 redos back to the stroked hash, a cancelled stroke leaves no residue, all heights in int16, save then load gives the identical grid hash.

What to tap:
1. The scene opens on a rough green landscape with a wide view. One finger paints (default brush Raise). Two fingers pinch, twist, pan. Top-right compass snaps north. Top-left square toggles the gesture debug box.
2. Buttons along the bottom: `Undo`, `Redo`, `Brush: X` (cycles Raise, Lower, Smooth, Flatten), `Run 50-stroke check`, `Hide report`, `Save`, `Load`, and the built-ins. Taps on these buttons never paint.
3. The live text (top) shows fps, average, p95 and max frame time over the last 600 frames, then `strokes ok/cancelled`, the undo and redo stack sizes, dab count, and the average chunk upload time.
4. For the fps figure: paint continuously with one finger for 30 seconds, then tap `Run 50-stroke check`.
5. `Run 50-stroke check` freezes the app for a while (it runs on the main thread), then shows the report and an evidence JSON. It ends with `RESULT: PASS` or `FAIL` and one yes/no line per criterion. Note it edits the live terrain (the 50 strokes stay applied at the end). `Copy` it and send it.
6. `Save` writes `user://gate0_terrain_paint.mhts` and shows the hash; `Load` reads it back and says whether it equals the terrain on screen.

What the numbers mean: `hash ...` values are the FNV-1a height hash (`MHHeightGrid.hash_fnv1a`), decimal. The CI half of item 5 is the same check on a smaller grid in `test_gate0_terrain_check.gd`. fps is the frame rate including vsync waits, so a 60 Hz phone caps at about 60; the 30 fps floor is p95 under 33.4 ms and no frame over 100 ms (DEC-047 placeholder).

Not covered: the "float use audit" file for item 5 (a grep of `game/terrain/`), a per-frame editor-loop measurement under a scripted stroke rather than a hand-painted one, and the low-end phone (does not exist yet).

## 3. Save and kill: `res://gate0/save_kill.tscn`
Files: `save_kill.gd`, `mh_gate0_save_harness.gd`, `mh_gate0_kill_log.gd`. Item 10 (device half).

What it proves: killing the app at any moment during a save of a 600 x 400 terrain never leaves a bad save. Each save of generation g: append `B g` to `user://gate0_kill_log.txt`, copy the current valid save to `<file>.bak` (atomic tmp + rename, via `MHTerrainSave.write_atomic`), write the new save atomically, append `D g`. The generation is stamped into two height samples. On every launch the scene loads the primary (falls back to the `.bak`), reads the generation, and checks it against the log: it must be the last finished save or the one in flight when the app died.

What to tap:
1. Open the app. It verifies automatically. First launch says `RESULT: NONE` (no files yet). That is expected.
2. `Save now` writes one generation. `Start repeated saves` saves every 0.5 s while the app runs (each save is a blocking write of about a second or less, so the app spends most of its time inside a save; that is the point). Force-kill it (recent apps, swipe away; or from a computer, below) at any time.
3. Reopen. The launch check prints `RESULT: OK` (log consistent) or `RESULT: FALLBACK` (primary unusable, backup used; investigate, this should not happen) or `CORRUPT` / `LOG MISMATCH` (FAIL). It also prints the running tally of all launches: `verifies N: OK a, FALLBACK b, CORRUPT c, NONE d`. Item 10 needs at least 200 kills with zero FAIL. `Load and verify` re-checks without adding to the tally.
4. Self-kill helpers (they use `OS.kill`; whether it behaves like a real force-stop on Android is unverified): `Saves + random self-kill` starts repeated saves and a background thread kills the app 0.3 to 2.8 s later; `Save, kill mid write` and `Save, kill before rename` use the `MHTerrainSave` fault hooks to kill inside the write of the primary file (half written temp file; complete temp file before rename). After each, reopen and read the result. A leftover `.tmp` is reported (`stale .tmp ... present: yes`) and removed.
5. `Clear files and log` resets everything.
6. `Evidence JSON` is at the bottom of the result text: `tally`, the last verify, and `result` (`pass` only if the last verify was consistent and no CORRUPT was ever logged). Send it after the 200 kills.

From a computer (USB debugging on, `adb` installed), one kill cycle for a tester loop. The package id is `@@PACKAGE_ID@@` in the export template, so find the real one first:
```
adb shell pm list packages | grep -i mulligan
adb shell monkey -p PACKAGE_ID -c android.intent.category.LAUNCHER 1
sleep 3
adb shell am force-stop PACKAGE_ID
```
Tap `Start repeated saves` once per launch is still manual; a fully automatic loop needs a launch argument the scene does not have yet (NOT BUILT). The relevant hooks: the scene could start repeated saves itself when launched with a user arg; ask the lead if the 200-kill run should be automated.

What is NOT covered by this scene: kills during "backup copy" beyond the atomic `.bak` write, "migration", and "cloud handoff" (no such code exists), a desktop harness for CI (`game/terrain/demo/save_probe.gd` covers mid/after temp write), and power-loss durability (`FileAccess.flush` is not a guaranteed fsync).

## 4. Animation cost: `res://gate0/anim_cost.tscn`
Files: `anim_cost.gd`, `mh_gate0_anim_cost.gd`. Item 9, COST HALF ONLY.

What it proves (if it runs): the main-thread CPU cost of evaluating procedural golfer animation, per golfer, at 1, 5, 10 or 20 placeholder golfers (`MHGolferRig`, `MHProceduralSwing`, `MHGolferAnimator`, read-only use of `game/characters/`).

What it does NOT prove, plainly: item 9 requires one licensed humanoid rig with three clips (walk, swing, celebrate) retargeted onto the game skeleton, licence records, and no foot sliding beyond 5 percent of stride. None of that is done here. There is no licensed rig in the repo, no celebrate clip exists, and nothing here measures foot sliding or proportions. The clips are the procedural `walk` and `swing_full` of workstream G. The evidence JSON is labelled `09_retarget_cost_only` with result `incomplete` so it cannot be mistaken for a pass. Also unverified: that `golfer_placeholder.gltf` imports and animates in Godot at all (never viewed).

What to tap:
1. Scene opens with 20 golfers in a grid, half walking, half swinging every 3 s. Live line: fps, process time, draw calls.
2. `1 golfers`, `5 golfers`, `10 golfers`, `20 golfers` respawn the crowd. `Animation: ON/OFF` freezes the poses (`AnimationPlayer.active`).
3. `Measure 12 s`: 6 s with animation off, then 6 s on (the first second of each is discarded). Then the report shows: average main-thread process time (`Performance.TIME_PROCESS`) off vs on, the per-golfer difference, a linear projection for 20 golfers, frame-time figures, and each clip's track and key counts as a size proxy. `Copy` it.
Meaning: per-golfer ms is (on minus off) divided by the golfer count. Skinning still draws while frozen, so this is animation evaluation only, not GPU cost. If off is not lower than on, `TIME_PROCESS` is not seeing the animation update and only the fps lines are usable. No budget number for item 9 exists in `GATE0.md` (only "measured"), so there is no PASS line.

## Tests (all `extends GdUnitTestSuite`, NOT YET RUN)
- `game/tests/input/test_cell_sentinel.gd`: MISS to NO_CELL translation, pass-through of real cells, bridge skips a translated miss and dabs (-1,-1) for a raw one.
- `game/tests/gate0/test_gate0_sim.gd`: embedded golden equals the JSON, smallest row hashes correctly, comparison and consistency logic, cost arithmetic and verdict bands, report and evidence.
- `game/tests/gate0/test_gate0_terrain_check.gd`: plan determinism, the full 50-stroke style check on a small grid, judge, sink stroke/undo/cancel.
- `game/tests/gate0/test_gate0_kill.gd`: kill-log parsing and judging, stamp tear detection, save then verify, corrupt primary falls back to the backup, both corrupt, injected write failures leave the old generation loadable.
- `game/tests/gate0/test_gate0_helpers.gd`: rolling stats and verdict, evidence fields, build-info sha parsing, panel button hit test, anim layout, cost math.

## Unverified assumptions
- `TextEdit` read-only selection by long press on Android, and `DisplayServer.clipboard_set` on Android. If long press does not select, `Copy` is the route.
- Godot `Button` does not receive finger taps with `emulate_mouse_from_touch` off; the panel handles raw touch itself. If a device also delivers mouse events, a tap could fire twice (not expected with both emulate settings off).
- `OS.kill(OS.get_process_id())` from a Thread, and `OS.delay_msec` in a Thread, behave on Android as on desktop.
- `Performance.TIME_PROCESS`, `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `AnimationPlayer.active`, `TextEdit.virtual_keyboard_enabled`, `HFlowContainer` exist under those names in 4.7.2 (all believed stable since 4.0).
- Terrain API used through `MHGate0TerrainApi` only: `MHTerrainEditor.new(grid)` (splat optional), `MHTerrainChunks.setup(grid, splat, 32)`, `flush(tracker)`, `MHTerrainSave.encode/decode/write_atomic/load_from_file/cleanup_stale_temp/temp_path` and its `fault_point`/`fault_action` statics. If the terrain owner changes those, edit that one file.
- `res://build_info.json` keys (`sha`) as written by `tools/ci/gen_build_info.sh`.
- The 600 x 400 save encodes in GDScript loops; on a phone this may take a second or more per save. Measured nowhere yet.

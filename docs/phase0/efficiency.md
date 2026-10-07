# Frame efficiency (workstream D extension)

> **Historical Phase 0 record.** This file captures an early efficiency/planning checkpoint. Current priorities are in `docs/ROADMAP.md`, `docs/TECH_DEBT.md` and `docs/QUALITY_GATES.md`.

Status: written, **NOT YET RUN**. No Godot binary was available. Nothing here is a measurement.

## README block

- **Purpose:** stop the phone rendering frames nobody can see change (battery and heat), let the player pick a frame cap, and keep the 3D render scale from dropping or oscillating needlessly, all without lowering per-frame visual quality.
- **Public API:** `MHFrameGovernor` (`resolve_cap`, `decide`, `update`, `apply`, `note_input`, `release`), `MHFrameCapSetting` (`options`, `load_value`, `save_value`, `next`), `MHAdaptiveScale` (`next_scale`, `step`, `changes`, `paused`, `set_target_fps`).
- **Tests:** gdUnit4, `game/tests/render/test_frame_governor.gd`, `test_adaptive_scale.gd` (plus the existing `test_bench_helpers.gd`, which still exercises the adaptive scale).
- **Gate 0:** supports the 30 fps forest proof item and the soak/battery evidence (idle fps and frame time, scale changes, share of frames over 33 ms). Confirm wording in `docs/phase0/GATE0.md`.

## 1. What was built

New:
- `game/render/mh_frame_governor.gd`: modes `disabled`, `active`, `idle`. Activity inputs are input events, camera motion and animation (golfers moving). Active holds the cap. After `hold_ms` (2000) with no activity it drops to `idle_fps` (15, never above the cap). `OS.low_processor_usage_mode` is turned on only in idle AND only if no ambient shader animation (water waves) is running, because low processor mode would freeze it. Engine calls happen only in `apply` and only when the value changed. Pure logic: `decide(cap, since_activity_ms, hold, idle_target, ambient)` and `update(now_ms, input, camera, anim, ambient)` take time and flags as arguments.
- `game/render/mh_frame_cap_setting.gd`: setting values `"30"`, `"60"`, `"auto"`, stored in `user://mh_render_settings.cfg` (ConfigFile). `options()` gives id and label pairs for a UI. Auto: low and medium tiers 30, high tier 60 (`MHFrameGovernor.resolve_cap`). The UI workstream must add the actual settings screen; only the bench HUD has a cycle button so far.
- `game/tests/render/test_frame_governor.gd`, `game/tests/render/test_adaptive_scale.gd`.

Changed:
- `game/render/mh_adaptive_scale.gd`: decision metric is now the **p95 frame time of each 30 frame window** (was window average). Down when p95 > 1.05 x budget. Up only after 4 consecutive windows with p95 < 0.80 x budget. Dead band between. Flip-flop backoff: a down step within 6 windows of an up step doubles the calm requirement (max 16), reset after 20 stable windows. New `changes` counter, `paused`, `set_target_fps`, pure `next_scale`. Only `Viewport.scaling_3d_scale` changes, so UI (CanvasLayer/Control) stays at native resolution. Floors are still the tier values in `MHQuality`: high 0.75, medium 0.7, low 0.6. The request said min about 0.75; medium and low were left lower on purpose (weakest phones need it to hold 30), change `render_scale_min` in `mh_quality.gd` if you want a hard 0.75 everywhere.
- `game/render/mh_golfers.gd`: `paused` flag (used by the idle scenario).
- `game/bench/bench_scene.gd`: governor wiring, `--fps-cap=30|60|auto|off`, "Idle 30s" button, "Cap" cycle button, input wake-up, idle frames excluded from adaptive scale.
- `game/bench/mh_bench_runner.gd`: `idle` mode (30 s). `game/bench/mh_bench_stats.gd`: verdict `IDLE_MEASURED` for idle runs (the 30 fps pass rule does not apply to a deliberately throttled scene).

## 2. Bench output (bench.json, per window and in summary)

New fields: `governor_mode` (`disabled`, `active`, `idle`), `fps_cap` (0 = uncapped/governor off), `fps_cap_setting`, `governor_idle_pct`, `governor_transitions`, `scale_changes`. Already present: `pct_over_33ms`, `pct_over_50ms`, `avg_fps`, `avg_ms`, `p95_ms`, `render_scale`.

Default for quick and soak is governor **off and uncapped**, so existing measurements stay comparable and a cap cannot mask headroom or make avg fps read just under 30. Use `--fps-cap=...` to bench with the governor on.

Idle scenario: `--mode=idle` (or the Idle 30s button). Camera orbit off, golfers paused, governor forced on. Expect `governor_mode` idle, `avg_fps` near 15 (or near the render rate if low processor mode makes frames event driven) and a much lower frame cost than the active run. Water waves are on in medium and high tiers, so low processor mode is intentionally NOT used there; only the low tier can use it.

## 3. How to verify (NOT YET RUN)

1. CI runs the gdUnit4 suites in `game/tests/render/`; expect all green.
2. On a device, run the bench three times, same tier: `--mode=quick --autostart` (baseline), `--mode=quick --autostart --fps-cap=auto`, `--mode=idle --autostart`. Compare `avg_fps`, `pct_over_33ms`, `scale_changes`, battery drop per the device runbook.
3. Idle should show `governor_mode: idle` and the lower fps. On a soak, `scale_changes` should be small and not grow steadily (steady growth means oscillation).

## 4. Unverified assumptions

- `Engine.max_fps` and `OS.low_processor_usage_mode` behave as documented in 4.x on Android and iOS, including that changing max_fps mid-run takes effect on the next frame. Low processor mode behaviour with a live Godot HUD Label update and with vsync is unverified.
- `Viewport.scaling_3d_scale` leaves Control/CanvasLayer UI at native resolution (documented Godot behaviour, not checked here).
- Idle fps 15 and hold 2 s are guesses; tune from device data.
- `MHFrameCapSetting` uses `ConfigFile` at `user://`; not exercised by tests (tests avoid disk).
- Auto = high tier 60 is a policy guess. With a 60 cap the adaptive budget is still the tier's 30 fps target, so 60 only removes the upper limit and does not force scale down to chase 60.

## 5. Risks and follow-ups

- Any code path that animates without input, camera or golfer motion (new effects, UI animation, timers) must report activity or it will render at idle fps. The game scene needs to feed `MHFrameGovernor.update` its own activity flags, and call `note_input` from `_input`.
- Wake-up latency: one frame at idle fps (up to about 67 ms) may elapse before an input is handled, mitigated by the `_input` hook applying the change immediately.
- p95 over 30 frames reacts to two or more bad frames per window; hitches from asset loads are ignored by design.

# Phase 1: tap-to-aim and shot feedback

Status: 5 October 2026. Implemented under Nathan-approved DEC-076. Syntax/schema checks PASS; independent static evidence in `aiming_verification.md`. Godot import/tests, rendered path, raw device touch and phone ergonomics NOT YET RUN.

## Built

The exact one-hole practice panel now accepts a course tap or desktop left click to move the target. Four numeric aim-nudge buttons were removed. Aim at cup, separate Play shot, restart and design controls remain. A ray intersects the flat prototype layout, then the UI boundary rounds world position into integer centiyards. It neither changes course geometry nor commits a shot.

The yellow intended line runs from the ball to the selected target. A ring shows rough skill/lie-based lateral spread around the nominal carry endpoint; it is not a confidence percentile or guaranteed landing zone. Feedback distinguishes within reach, beyond reach, and nominal water/OB/sand landings. Official carry and lateral-scale parameters are reused. Preview does not inspect the next random draw, alter practice state, change official rating or consume currency. Trees/curved shots, roll/slope physics and final skill-based putting are not predicted by this simple marker.

`MHAimTap` owns a contact from press to release. UI-started contacts never aim, world contacts cannot aim after dragging onto UI, movement beyond 18 viewport units remains a drag even if the pointer returns, and two contacts suppress aiming until all lift. Cancelled releases and focus loss clear ownership. The input node is added last under the live scene, before the UI bridge in reverse-depth event order; UI events remain unconsumed so buttons work once. Opening practice clears pending pointer state. Touch and desktop events share ownership rules; no simulated mouse-from-touch is enabled.

Draft preview still cannot play against the old finalized geometry. Restart now restores finalized design fields and exits draft preview, avoiding a practice restart that remains stuck in preview mode. Text feedback wraps to the current viewport width; final responsive phone layout remains pending.

## Validation and evidence

- `python3 docs/spec/data/validate.py`: ALL PASS.
- `gdparse` changed/new scripts: PASS; syntax only, not engine typing.
- New pending Godot tests: world/UI ownership, UI crossings, drag-return/cancel, mixed UI/world two-finger cancellation, focus clear, preview state/next-draw preservation, unreachable/water feedback. Live-scene projection test checks an exact 50-yard aim while preserving cash/round state.
- No economy parameters, official rating/sim definitions or golden outputs changed.
- Godot API evidence: [input event order](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html) explicitly documents reverse-depth traversal; [Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html) documents project_ray_origin, project_ray_normal and unproject_position. BoxMesh/material methods reuse earlier scene code. No unverified new engine API signature identified. Actual event order in this scene still requires engine/device evidence.

## Limits and next work

This remains the flat, short-par-3 prototype described in `one_hole.md`. No golfer avatar, career attributes/XP, varied shot styles, NPC opponent or played tournament is claimed. Landing-ring accuracy, phone hit area, UI occlusion and camera composition need device checks. Camera gestures remain suppressed in the open practice panel; add dedicated practice camera controls/follow after aiming is measured. The aim itself is transient; committed ball/stroke state remains checkpointed.

Path meshes are rebuilt only when aim/layout/round changes, not each frame. Measure renderer/draw-call cost on the low-end phone before adopting this representation for production. Runtime accounting/save performance concerns from `one_hole.md` still apply.

Latest predecessor CI (7564c95): all four workflows queued/pending at the start of this increment. Earlier 2675841 jobs failed/cancelled before test steps and had no logs; exact runner-start annotation cause remains unknown. No green build or merge certification.

## Nathan's device check after a green APK

Run Sim hash and Benchmark Quick 60s first. Then Live construction -> Build / play one hole -> finalize. Tap different course positions: target/path should move, cash/strokes must not change. Tap Play shot once: one shot only. Try a drag, two-finger touch, and a touch starting on a UI button: none should aim accidentally. Save/reopen after a shot and confirm position/strokes. Report whether the course is visible enough to choose targets and whether the warnings help.

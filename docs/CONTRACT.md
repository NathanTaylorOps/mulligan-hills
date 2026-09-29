# Mulligan Hills: Engineering Contract (Phase 0)

Read this fully before writing anything. Every agent works under it.

## Project
Mulligan Hills is a golf course design tycoon for phones (Android first, iPhone later, tablets), stylized 3D, day only, built in Godot 4.x with GDScript. The master plan is the Docs artifact "Mulligan Hills: Master Plan" (project id 5991cb68-b96d-45aa-a0ac-f25408624480). Phase 0 exists to prove the risky technical parts before anything else is built. Gate 0 has 10 proof items (listed in `docs/phase0/GATE0.md`).

## Environment facts (important)
- Nobody can run Godot 4 in this sandbox: downloads are blocked. Code is validated by CI on GitHub Actions later. Therefore: write small, conservative, typed GDScript; prefer APIs stable across Godot 4.3 to 4.7; mark anything you are unsure about in a `## Unverified` section of your status doc; never claim code was run when it was not. Say "NOT YET RUN" plainly.
- Python 3.11 is available here. Use it for reference implementations and golden test vectors. Network to package registries may be blocked; do not depend on installing anything.
- The manager (Nathan) is not a programmer. Any instruction meant for him must be exact, numbered, copy-paste, with no assumed knowledge.
- Target devices: a budget Android phone (low end), an iPhone, an Android tablet. CI runs on GitHub Actions (Ubuntu and macOS runners).

## Repo layout and ownership
Each agent writes ONLY inside its own paths. Do not edit another agent's files. Do not run git; the lead commits.

| Owner workstream | Paths |
| --- | --- |
| A ci | `.github/workflows/`, `tools/ci/`, `docs/phase0/ci.md`, `docs/GODOT_VERSION.md`, `game/project.godot`, `game/export_presets.cfg.template`, `.gitignore`, `.gitattributes` |
| B determinism | `game/core/` , `game/tests/core/`, `tools/reference/determinism/`, `docs/phase0/determinism.md` |
| C terrain | `game/terrain/`, `game/tests/terrain/`, `tools/reference/terrain/`, `docs/phase0/terrain.md` |
| D forest | `game/render/`, `game/bench/`, `game/tests/render/`, `docs/phase0/forest.md` |
| E gestures | `game/input/`, `game/tests/input/`, `docs/phase0/gestures.md` |
| F platform | `game/platform/`, `android/`, `ios/`, `docs/phase0/platform.md` |
| G animation | `game/characters/`, `tools/animation/`, `docs/phase0/animation.md`, `docs/LICENSE_LEDGER.md` |
| H spec | `docs/spec/`, `docs/DEFINITION_OF_DONE.md`, `docs/DECISIONS.md`, `docs/phase0/GATE0.md` |
| I device | `docs/phase0/device_runbook.md`, `docs/phase0/soak_protocol.md` |

Shared decisions: the game project root is `game/`. GDScript classes use the prefix `MH` (for example `MHFixed`, `MHRng`). Tests use gdUnit4 under `game/tests/<module>/` (files `test_*.gd`). If gdUnit4 is needed, workstream A vendors or downloads it in CI; other agents just write tests against `gdUnit4` `GdUnitTestSuite`.

## Code rules
- Typed GDScript everywhere (`var x: int`, return types). snake_case files and functions, PascalCase class names.
- Simulation and rating code (`game/core/`) uses integers and fixed-point only: no float arithmetic, no `randf`, no engine physics, no trig functions, no unordered Dictionary iteration in anything that affects results. Terrain heights are integers (int16 millimetres or similar as workstream C defines and documents).
- Every module has a short README block at the top of its status doc: purpose, public API, how tests run, what Gate 0 criteria it addresses.
- No invented facts about Godot APIs, plugins, prices or policies. If unsure, say unverified and give the doc URL to check.
- Copy-paste ready instructions for the manager go in the status docs under `## For Nathan`.

## Status doc format (`docs/phase0/<name>.md`)
1. What was built (files list)
2. How it is tested (and what has NOT been run)
3. Gate 0 criteria covered and what evidence CI must produce
4. Unverified assumptions
5. Risks and follow-ups
6. For Nathan (only if he must do something)

## Definition of done for Phase 0 work
Files exist, typed, self-consistent, tests written, status doc complete, honest about what is unrun. Nothing else.

## Lead decisions after the first Phase 0 round (29 Sep 2026)
- Terrain API: the implemented API in `game/terrain/` (MHHeightGrid, MHTerrainEditor with begin_stroke, apply_brush_at, end_stroke, cancel_stroke, undo, redo) is authoritative. `docs/spec/interfaces/terrain.md` describes a facade to be reconciled to it.
- New module paths for later phases: `game/core/rating/`, `game/core/economy/`, `game/core/buildings/`, `game/core/save/`, `game/ui/`.
- Tests may also live beside a module (`game/platform/tests/`, `game/characters/tests/`); CI runs `res://` recursively for `test_*.gd`.
- Touch: `emulate_mouse_from_touch` is false in `project.godot`; desktop dev builds use the mouse mapping in `game/input/`.
- Score gates, land classes and Gate 0 performance budgets in the specs are placeholders until Phase 0 measurements exist.

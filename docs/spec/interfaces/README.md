# Module interface contracts (DRAFT until Gate 0 passes, then FROZEN)

Owner: workstream H. Purpose: parallel agents build against these names and signatures, not against each other's code. Status of every file below is DRAFT. Nothing here was compiled or run (no Godot in this sandbox); signatures are typed GDScript written to stay valid across Godot 4.3 to 4.7. Anything not certain is listed under "Unverified".

RECONCILED 29 Sep 2026: `docs/CONTRACT.md` says the implemented API is authoritative. `terrain.md` now describes the implemented classes exactly. The other files still contain Phase 1 DRAFT interfaces (rating, economy, buildings, save, UI shell) that have no code yet, and each now opens with an "Implementation status" block naming what really exists in `game/`. Where a draft type in these files does not exist in code (for example `MHResult`, `MHTerrain`, `MHSimEngine`), treat it as a proposal, not as an API.

## Freeze rules
1. DRAFT -> FROZEN happens when Gate 0 passes and Nathan signs off (a DECISIONS.md entry records the date). After that a change needs an interface change proposal (ICP): a PR touching only `docs/spec/interfaces/` and `docs/DECISIONS.md`, labelled `interface-change`, reviewed by the owner of the module and every consumer listed, with a compatibility note and updated contract tests. Adding a method or signal is minor; changing or removing one is major and needs Nathan's approval.
2. Implementers may add private members (leading underscore) freely. Anything public (no underscore) must appear here.
3. Each module ships gdUnit4 tests under `game/tests/<module>/` (or beside the module, see CONTRACT.md) that call every public method listed here (workstream that owns the module writes them; the verifier agent checks they exist). The Phase 0 suites are named `test_*.gd` by topic (for example `game/tests/terrain/test_brush.gd`); no file named `test_contract_*.gd` exists, so CI must not require that name.

## Conventions
- Prefix `MH`. Files snake_case, classes PascalCase (`class_name MHSimEngine`). Typed everything.
- Simulation and rating (`core`, `rating`) use integers and fixed-point only: `MHFixed` (Q16.16 in an int) and `MHRng` (PCG32, `MHRng.new(seed, stream)`) come from workstream B and exist in `game/core/`. The rating spec (`docs/spec/rating/golfer-sim.md`) does NOT use `MHRng`: it uses a counter-based hash `H32` with no stateful PRNG. Where a method here says `int`, it is an integer in the unit named in `docs/spec/data/README.md`.
- No exceptions. PROPOSED (not implemented; no `MHResult` class exists in `game/` as of 29 Sep 2026): fallible calls return `MHResult` (a small class: `ok: bool`, `code: int`, `msg: String`, `value: Variant`) with ints from each module's `MHxxxError` constants. Phase 0 code instead returns Godot `Error` ints or small inner result classes (`MHTerrainSave.LoadResult`) or Dictionaries (`MHEntitlementToken.verify`, `MHShotSim.simulate_hole`). Never NaN, never crash on bad input.
- Signals are for UI and audio. The sim/rating core never emits signals from inside a tick; it fills event buffers (`PackedInt32Array` rows) that the caller drains, so results do not depend on signal connection order.
- Threads: sim runs on one worker thread via an `MHSimRunner`; the main thread never touches sim state except through `snapshot()` copies.
- Data in and out is plain typed data (`MHCourse`, `PackedInt32Array`, `PackedByteArray`), matching the JSON schemas in `docs/spec/data/`.

## Module map and paths
The Phase 0 contract fixes `game/core/` (B), `game/terrain/` (C), `game/render/` (D), `game/input/` (E), `game/platform/` (F), `game/characters/` (G). The lead decisions of 29 Sep 2026 in `docs/CONTRACT.md` fix the later-phase paths as `game/core/rating/`, `game/core/economy/`, `game/core/buildings/`, `game/core/save/`, `game/ui/`. The table below uses those paths. (The earlier proposal `game/core/sim/`, `game/economy/`, `game/buildings/`, `game/save/` is superseded; Phase 0 sim code sits directly in `game/core/`.)

| Module | Interface doc | Proposed path | Implementing owner (Phase 0 / later) | Consumers |
| --- | --- | --- | --- | --- |
| Core sim | core_sim.md | `game/core/` (Phase 0, flat files; a `sim/` subfolder is not in CONTRACT.md) | B | rating, economy, render, UI |
| Rating engine | rating_engine.md | `game/core/rating/` | B | economy, buildings, UI, tournaments |
| Terrain | terrain.md | `game/terrain/` (implemented, file describes the code) | C | render, input, save (sim and rating do not read it yet) |
| Economy | economy.md | `game/core/economy/` | Phase 1 owner TBD | buildings, UI, save |
| Buildings | buildings.md | `game/core/buildings/` | Phase 1 owner TBD | economy, UI, save, render |
| Save | save.md | `game/core/save/` | Phase 1 owner TBD (F helps with atomic file I/O) | all |
| Platform services | platform_services.md | `game/platform/` (implemented, differs from draft, see file) | F | UI, save, analytics |
| UI shell | ui_shell.md | `game/ui/` | Phase 1 owner TBD | all |

Dependency direction (arrows = "may call"): ui -> economy, buildings, rating, sim, save, platform; economy -> buildings data, rating (read only), sim events; buildings -> rating (read only); rating -> sim, terrain; sim -> terrain, core math; terrain -> nothing today (the drafted "terrain -> core math" edge is not in the code: `game/terrain/` does not use `MHFixed`); save -> everything as plain data; platform -> nothing in game logic. No cycles. The rating engine and sim never import UI, render, input or platform.

## Unverified
- Exact `PackedInt32Array`/`PackedByteArray` method names beyond `size()`, `resize()`, `append()`, `slice()`, `to_byte_array()`: check https://docs.godotengine.org/en/stable/classes/class_packedint32array.html.
- `WorkerThreadPool` and `Thread` usage in 4.3 to 4.7: check https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html.

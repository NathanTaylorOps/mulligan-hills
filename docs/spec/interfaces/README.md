# Module interface contracts (DRAFT until Gate 0 passes, then FROZEN)

Owner: workstream H. Purpose: parallel agents build against these names and signatures, not against each other's code. Status of every file below is DRAFT. Nothing here was compiled or run (no Godot in this sandbox); signatures are typed GDScript written to stay valid across Godot 4.3 to 4.7. Anything not certain is listed under "Unverified".

## Freeze rules
1. DRAFT -> FROZEN happens when Gate 0 passes and Nathan signs off (a DECISIONS.md entry records the date). After that a change needs an interface change proposal (ICP): a PR touching only `docs/spec/interfaces/` and `docs/DECISIONS.md`, labelled `interface-change`, reviewed by the owner of the module and every consumer listed, with a compatibility note and updated contract tests. Adding a method or signal is minor; changing or removing one is major and needs Nathan's approval.
2. Implementers may add private members (leading underscore) freely. Anything public (no underscore) must appear here.
3. Each module ships `game/tests/<module>/test_contract_*.gd` that calls every public method listed here (workstream that owns the module writes it; the verifier agent checks it exists).

## Conventions
- Prefix `MH`. Files snake_case, classes PascalCase (`class_name MHSimEngine`). Typed everything.
- Simulation and rating (`core`, `rating`) use integers and fixed-point only: `MHFixed` (Q16.16 in an int) and `MHRng` (PCG32) come from workstream B. Where a method here says `int`, it is an integer in the unit named in `docs/spec/data/README.md`.
- No exceptions. Fallible calls return `MHResult` (a small class: `ok: bool`, `code: int`, `msg: String`, `value: Variant`). Error codes are ints from each module's `MHxxxError` constants. Never NaN, never crash on bad input.
- Signals are for UI and audio. The sim/rating core never emits signals from inside a tick; it fills event buffers (`PackedInt32Array` rows) that the caller drains, so results do not depend on signal connection order.
- Threads: sim runs on one worker thread via an `MHSimRunner`; the main thread never touches sim state except through `snapshot()` copies.
- Data in and out is plain typed data (`MHCourse`, `PackedInt32Array`, `PackedByteArray`), matching the JSON schemas in `docs/spec/data/`.

## Module map and paths
The Phase 0 contract fixes `game/core/` (B), `game/terrain/` (C), `game/render/` (D), `game/input/` (E), `game/platform/` (F), `game/characters/` (G). The contract does not yet assign paths for rating, economy, buildings, save or UI. PROPOSED (lead to add to CONTRACT.md before Phase 1):

| Module | Interface doc | Proposed path | Implementing owner (Phase 0 / later) | Consumers |
| --- | --- | --- | --- | --- |
| Core sim | core_sim.md | `game/core/sim/` | B | rating, economy, render, UI |
| Rating engine | rating_engine.md | `game/core/rating/` | B | economy, buildings, UI, tournaments |
| Terrain | terrain.md | `game/terrain/` | C | core sim, rating, render, input, save |
| Economy | economy.md | `game/economy/` | Phase 1 owner TBD | buildings, UI, save |
| Buildings | buildings.md | `game/buildings/` | Phase 1 owner TBD | economy, UI, save, render |
| Save | save.md | `game/save/` | Phase 1 owner TBD (F helps with atomic file I/O) | all |
| Platform services | platform_services.md | `game/platform/` | F | UI, save, analytics |
| UI shell | ui_shell.md | `game/ui/` | Phase 1 owner TBD | all |

Dependency direction (arrows = "may call"): ui -> economy, buildings, rating, sim, save, platform; economy -> buildings data, rating (read only), sim events; buildings -> rating (read only); rating -> sim, terrain; sim -> terrain, core math; terrain -> core math; save -> everything as plain data; platform -> nothing in game logic. No cycles. The rating engine and sim never import UI, render, input or platform.

## Unverified
- Exact `PackedInt32Array`/`PackedByteArray` method names beyond `size()`, `resize()`, `append()`, `slice()`, `to_byte_array()`: check https://docs.godotengine.org/en/stable/classes/class_packedint32array.html.
- `WorkerThreadPool` and `Thread` usage in 4.3 to 4.7: check https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html.

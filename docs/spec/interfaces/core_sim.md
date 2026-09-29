# Interface: Core sim (`game/core/`, owner B)

## Implementation status (29 Sep 2026, NOT YET RUN in Godot)
The types below (`MHSimEngine`, `MHSimConfig`, `MHGolferSpec`, `MHWeatherState`, `MHSimEvent`, `MHDaySummary`, `MHSimSnapshot`, `MHCourse`, `MHTerrain`, `MHResult`) do NOT exist in `game/`. Phase 0 (workstream B) implemented a prototype for the determinism proof, flat in `game/core/` (no `sim/` subfolder):
- `MHFixed` (Q16.16 in an int): `FRAC`, `ONE`, `DIV0`, `from_int`, `mul`, `div`, `isqrt`, `sqrt_fx`, `hypot`, `abs_fx`, `clamp_fx`, `lerp_fx`, `trunc_int`, `floor_int`.
- `MHTrig` (angles in 16-bit brads, 65536 = one turn): `sin_brad`, `cos_brad`, `atan2_brad`; tables in generated `MHTrigTable`.
- `MHRng` (instance, PCG32): `MHRng.new(seed_value: int, stream: int)`, `reseed`, `next_u32`, `bounded(n)`, `range_incl(lo, hi)`, `gauss_q16()`. Seed is ONE int in [0, 2^63) and stream in [0, 2^62); there are no `seed_hi/seed_lo/inc_hi/inc_lo` accessors (the halves are private `_hi/_lo/_inc_*`).
- `MHHash` (instance, FNV-1a 64): `add_byte`, `add_u32`, `add_i64`, `hex() -> String` (16 hex chars), `static hex32`.
- `MHHole` (lie grid, `GRID_W` 128 cells of 4 m, Q16.16 metres, lies `LIE_TEE, LIE_FAIRWAY, LIE_ROUGH, LIE_BUNKER, LIE_WATER, LIE_GREEN, LIE_TREES, LIE_OB`) and `MHShotSim` (`make_hole(course_seed, idx)`, `simulate_hole(hole, skill, wind_x, wind_y, rng, want_trace) -> Dictionary`, `trace_hash_hex`, `PARS`, `MAX_STROKES` 12, time constants). `MHSimHash.run(course_seed, base_seed, n_golfers, n_holes, want_hash) -> Dictionary` and `run_with_holes(holes, base_seed, n_golfers, want_hash)`. `game/core/bench_sim.gd` is the headless benchmark.
- The prototype reads no terrain and no course file; holes are generated from a seed. Skill is 0..100 (an int). It uses metres in Q16.16, while the rating spec (`docs/spec/rating/golfer-sim.md`) uses centiyards and a counter-based hash instead of `MHRng`. Those two models are NOT the same simulation; reconciling them is a Phase 1 decision.
- Hash mismatch to resolve: `MHHash` is FNV-1a 64 bit; the rating spec's `MH-HASH64` is two 32-bit FNV-1a lanes (offset bases `0x811C9DC5` and `0x9747B28C`). Different output for the same bytes.

Everything from "Types" down is the Phase 1 DRAFT and a proposal only. `state_hash() -> PackedByteArray` in it would be `MHHash.hex()` (a String) if built on the Phase 0 class.

Purpose: deterministic golfer simulation. Same inputs (course, golfer roster, seed, sim_version) give byte-identical outputs on every device. Integer and fixed-point only. No engine physics, no `randf`, no trig functions (lookup tables from B), no unordered Dictionary iteration, no `delta`.

## Types
```gdscript
class_name MHSimConfig extends RefCounted
var sim_version: String            # tag from B, e.g. "MHSIM-1.0.0"
var seed_hi: int                   # 32-bit halves of the 64-bit seed (saved as hex in the save file)
var seed_lo: int                   # PROPOSED. MHRng currently takes one int seed and one int stream (see status)
var inc_hi: int
var inc_lo: int
var golfer_cap: int                # max simultaneous golfers, default 24
var speed: int                     # 1, 2 or 4 (affects how many day-ticks run per call, never the results)

class_name MHGolferSpec extends RefCounted   # one golfer, all ints
var golfer_id: int
var skill_band: int                # 0..99, higher is better
var style: int                     # enum index, see MHGolferStyle
var mood: int                      # -100..100
var is_regular: bool
var regular_id: int                # -1 if not a regular
```

## Engine
```gdscript
class_name MHSimEngine extends RefCounted
func setup(config: MHSimConfig, course: MHCourse, terrain: MHTerrain) -> MHResult
func begin_day(day: int, roster: Array[MHGolferSpec], weather: MHWeatherState) -> MHResult
func step(budget_us: int) -> int                    # runs up to budget_us microseconds of work; returns events produced this call
func is_day_done() -> bool
func drain_events() -> PackedInt32Array             # rows of MHSimEvent.STRIDE ints; clears the buffer
func state_hash() -> PackedByteArray                # hash ( of canonical state (algorithm per docs/phase0/determinism.md)), used by golden tests and Gate 0 item 3
func snapshot() -> MHSimSnapshot                    # immutable copy for the render/UI thread
func get_day_summary() -> MHDaySummary              # rounds played, strokes per hole, queue times, revenue inputs
func get_rng_state() -> PackedInt32Array            # [seed_hi, seed_lo, inc_hi, inc_lo] for saving (MHRng has no public state accessor yet; needs adding)
```
`MHWeatherState`: `wind_dir_deg: int (0..359)`, `wind_speed: int (0..40)`, `rain_level: int (0..3)`, `season: int`. Weather is a pure function of the save RNG and the day, never wall-clock.

## Events (row layout, all ints)
`[tick, golfer_id, type, hole_no, a, b, c]` where `type` is one of `MHSimEvent.TEE_OFF, SHOT, LANDED, HOLED, QUEUE_WAIT, HAZARD_HIT, ROUND_DONE, COMPLAINT`. `a,b,c` payload meanings are documented in `docs/phase0/determinism.md`. Rating reason codes ride on `COMPLAINT`.

## Guarantees
- `step()` results depend only on setup + begin_day inputs, never on `budget_us` chunking (the budget bounds work per call; the same events appear in the same order however it is sliced). Golden test: run in slices of 1 ms, 5 ms, and unlimited; hashes equal.
- Golfers processed in ascending `golfer_id`, holes ascending, ties broken by `golfer_id`.
- Invalid course (no tee/green, unreachable) returns `MHResult.ok == false`, never crashes.

## Consumers
Rating engine (calls the sim to sample shots), economy (revenue inputs), render/UI (snapshot and events), save (RNG state).

## Contract tests
Hash match on a fixed course and seed for 1000 rounds; slice-independence; malformed course rejection; 24 golfers x 18 holes performance number logged (Gate 0 item 4).

# Interface: Core sim (`game/core/sim/`, owner B)

Purpose: deterministic golfer simulation. Same inputs (course, golfer roster, seed, sim_version) give byte-identical outputs on every device. Integer and fixed-point only. No engine physics, no `randf`, no trig functions (lookup tables from B), no unordered Dictionary iteration, no `delta`.

## Types
```gdscript
class_name MHSimConfig extends RefCounted
var sim_version: String            # tag from B, e.g. "MHSIM-1.0.0"
var seed_hi: int                   # 32-bit halves of the 64-bit seed (saved as hex in the save file)
var seed_lo: int
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
func get_rng_state() -> PackedInt32Array            # [seed_hi, seed_lo, inc_hi, inc_lo] for saving
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

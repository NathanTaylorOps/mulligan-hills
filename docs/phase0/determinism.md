# Workstream B: Determinism (Phase 0)

**Status: Python reference RUN and self-tested. GDScript NOT YET RUN (no Godot binary in the authoring sandbox).**

## README block

- **Purpose:** prove the golfer simulation and rating engine can give bit-identical results on Linux, macOS, Android and iOS, by using only integers, a hand-written RNG and hash, and table-driven trig.
- **Public API (all in `game/core/`, GDScript, static unless noted):**
  - `MHFixed` (Q16.16): `from_int, mul, div, isqrt, sqrt_fx, hypot, abs_fx, clamp_fx, lerp_fx, trunc_int, floor_int`.
  - `MHTrig` (angles in brads16, 65536 = one turn): `sin_brad, cos_brad, atan2_brad`; tables in generated `mh_trig_table.gd` (`MHTrigTable`).
  - `MHRng` (instance, PCG32): `MHRng.new(seed, stream)`, `reseed, next_u32, bounded(n), range_incl(lo, hi), gauss_q16()`.
  - `MHHash` (instance, FNV-1a 64): `add_byte, add_u32, add_i64, hex()`.
  - `MHHole` + `MHShotSim`: `make_hole(course_seed, idx)`, `simulate_hole(hole, skill, wind_x, wind_y, rng, want_trace)`.
  - `MHSimHash.run(course_seed, base_seed, n_golfers, n_holes, want_hash)`: hash of the full result for N golfers x M holes.
  - `bench_sim.gd`: headless benchmark.
- **Gate 0 criteria addressed:** cross-platform determinism of sim and rating math; sim speed at 4x. (Item numbers are in `docs/phase0/GATE0.md`, owned by workstream H; map them there.)
- **How tests run:** Python: `python3 tools/reference/determinism/selftest.py`. GDScript: gdUnit4 suites in `game/tests/core/` (run by CI, workstream A). Bench: `godot --headless --path game -s core/bench_sim.gd`.

## 1. What was built

`game/core/`
- `mh_fixed.gd`, `mh_trig.gd`, `mh_trig_table.gd` (GENERATED), `mh_rng.gd`, `mh_hash.gd`, `mh_hole.gd`, `mh_shot_sim.gd`, `mh_sim_hash.gd`, `bench_sim.gd`

`tools/reference/determinism/` (pure integer Python, runs on 3.11)
- `mh_fixed.py, mh_trig.py, mh_rng.py, mh_hash.py, mh_shotsim.py` (line-for-line mirrors)
- `gen_tables.py` (writes `mh_trig_table.gd`), `gen_golden.py` (writes golden JSON), `selftest.py`

`game/tests/core/`
- `golden_loader.gd` (`MHGolden`), `test_fixed.gd, test_trig.gd, test_rng.gd, test_hash.gd, test_shotsim.gd`
- `golden/` : `rng.json, fixed.json, trig.json, hash.json, shotsim.json`

### Design choices (integer semantics)

| Topic | Choice |
| --- | --- |
| Fixed format | **Q16.16** in 64-bit ints. Resolution 1/65536 m. `mul` inputs must satisfy `abs(raw) <= 2^31` so the product is under 2^62. Q24.8 rejected: 1/256 m is too coarse for wind and dispersion factors of 0.01. |
| Overflow | Never relied on. GDScript ints wrap at 64 bits, but signed overflow is not something to depend on across compilers/ABIs. Every product is bounded below 2^63; the Python reference wraps every such product in `chk()` which asserts it fits int64. |
| 64-bit multiply (PCG, FNV) | State is kept as two 32-bit halves (hi, lo). Multiplication uses 16-bit limbs so intermediates stay below 2^63. FNV prime is 2^40+435, done as `x*435 + (x<<40)`. |
| Negative division | GDScript `int / int` truncates toward zero and `%` follows the dividend sign (C++ semantics). Python `//` and `%` floor. So the reference uses `tdiv()` and code only divides/mods non-negative operands, except one truncating divide in `_center` (both sides use truncation). |
| Shifts on negatives | Never applied. `mul`, `div`, `trunc_int`, `floor_int` use sign-magnitude. `& 0xFFFF` on negative angles is used (two's complement AND is well defined). |
| Rounding | `mul`, `div`, `trunc_int` truncate toward zero. `floor_int` rounds down. Trig tables round half up. |
| Divide by zero | `div(x, 0)` returns +-2147483647 (saturate). `atan2(0,0)` returns 0. |
| sqrt | Integer Newton (`isqrt`), floor result, start value `1 << ceil(bits/2)`. `sqrt_fx(a) = isqrt(a << 16)`. Exact floor, verified against `math.isqrt`. |
| Angles | brads16, 65536 per turn, 0 = +x, counter-clockwise. |
| Trig | Quarter-wave sine table (257 entries, step 64 units) and atan table over ratio 0..1 (257 entries), linear interpolation. Tables built with 60-digit `Decimal`, no float. Documented max error, measured over all 65536 angles against float math: **sin/cos 1.70 LSB (2.6e-5), atan2 1.57 brads (0.0086 deg)**. Tables are monotonic so interpolation shifts never see a negative value. |
| RNG | PCG32 XSH-RR 64/32. Matches the published pcg32-demo vector for seed 42, stream 54 (`a15c02b7 7b47f409 ba1d3330 83d2f293 bfa4784b cbed606e`; vector recalled from the pcg-c demo, and independently cross-checked against a bigint PCG32 on 300 random seeds). `bounded(n)` uses unbiased rejection. `gauss_q16()` = sum of four uniform 16-bit values minus 131070 (range +-2.0, sd 0.577 in Q16.16). |
| Hash | FNV-1a 64. Matches published vectors for "", "a", "foobar". Integers absorbed as 8 little-endian two's-complement bytes (`abs(v) < 2^62`). |
| JSON goldens | GDScript parses JSON numbers as floats, exact only below 2^53. Larger values are decimal strings, hashes are hex strings. `MHGolden.i()` converts. |
| Ordering | No Dictionary iteration affects results. All sim loops are integer `for` loops over Arrays. |
| Shot sim | Hole = 128-wide integer lie grid of 4 m cells (tee/fairway/rough/bunker/water/green/trees/OB), built from a seeded RNG. Golfer skill 0..100, wind vector, lie-based distance penalty, hazard look-ahead, dispersion via `gauss_q16`, penalty strokes, putting by integer make-percentage, pickup at 12 strokes. **Balance is untuned**; it exists to exercise the math. |

## 2. How it is tested

**RUN here (Python 3.11):** `python3 tools/reference/determinism/selftest.py` gives 21 PASS, 0 failures:
- PCG32 vs published vector and vs bigint implementation (300 seeds x 50 outputs)
- FNV-1a vs published vectors and vs bytewise reference
- `isqrt` vs `math.isqrt` (5000), `mul` vs exact product (5000), sqrt exact floor, negative semantics
- trig max errors (numbers above), table monotonicity
- shot-sim repeatability, seed sensitivity, trace flag independence, stroke bounds 1..12
- golden JSON regenerates byte-identical

Golden files generated by `python3 tools/reference/determinism/gen_golden.py`.

**NOT YET RUN: everything in GDScript.** The five gdUnit4 suites and `bench_sim.gd` have never been parsed or executed. Any syntax error or engine-behaviour difference would show up first in CI.

## 3. Gate 0 evidence CI must produce

1. All `game/tests/core/test_*.gd` pass on Ubuntu and macOS runners (headless).
2. The same suites pass on Android and iOS devices/emulators. Because tests read the golden vectors from `res://`, the golden files must be included in the test export (check the export filter includes `*.json`). The device-side proof is the sim hash: run `MHSimHash.run(20260929, 777, 60, 18, true)` on each platform and log `hash`.
3. Expected 60x18 result (course seed 20260929, base seed 777): hash `c36530956ac94b59`, total strokes 3909, max round time 5160 sim seconds (from the Python reference; also in `game/tests/core/golden/shotsim.json`). All platforms must print the identical string.
4. `bench_sim.gd` JSON line from a desktop runner and a low-end Android device. Pass condition proposed: `us_per_sim_second <= 30000` (assumes a 2 ms/frame sim budget at 60 fps and 4x speed; the budget is my assumption, confirm against the master plan).

## 4. Unverified assumptions (GDScript / Godot)

- The GDScript has never been parsed. Typing, `@warning_ignore("integer_division")` on functions (used to silence INTEGER_DIVISION warnings), and `while true:` followed by `return` could raise warnings or errors.
- `const X: Array = [...]` in the generated table file, indexed as `MHTrigTable.SIN_QUARTER[i]` from another class. I used a plain `Array` const rather than `PackedInt32Array([...])` because it is the conservative choice; switching later is a generator change.
- `>>` on non-negative int64 behaves as logical/arithmetic identically (true for non-negative). Negative shifts are avoided, so the arithmetic-vs-logical question never arises.
- `&`, `|`, `^` on negative ints behave as two's complement 64-bit (used for angle wrap and `add_i64`).
- `int / int` truncates toward zero and `%` keeps dividend sign. Only one call site depends on it (`_center`, negative numerator); if wrong, the golden test for hole generation fails.
- `absi, maxi, mini, clampi`, `PackedInt64Array.append`, `PackedByteArray.resize` and element assignment, `Time.get_ticks_usec`, `Engine.get_version_info()["string"]`, `FileAccess.get_file_as_string`, `JSON.parse_string`, `JSON.stringify`, `extends SceneTree` with `_init()` and `quit()`: all believed available in Godot 4.3 to 4.7; check https://docs.godotengine.org/en/stable/classes/ if a parse error appears.
- `JSON.parse_string` returns numbers as float; `int(float)` is exact below 2^53. Values above are strings.
- gdUnit4 API: `GdUnitTestSuite`, `before()`, `assert_int(...).is_equal(...)`, `assert_str(...)`, `assert_bool(...)`. Check the version workstream A vendors.
- `res://tests/core/golden/*.json` is readable at test time (project root is `game/`).
- Speed: the Python run cost is irrelevant to GDScript speed. Real numbers only come from `bench_sim.gd`. GDScript is interpreted; hashing every trace int byte by byte is slow, so the benchmark times the sim with hashing off.

## 5. Risks and follow-ups

- **Not covered by this proof:** terrain heights (workstream C), the rating engine itself (only its math primitives exist here), and any float use elsewhere in the project. A lint check that greps `game/core/` for float literals and `randf` is worth adding to CI (I ran one manually: no hits).
- If bench shows `us_per_sim_second` near budget on the low-end Android, options: drop hash/trace, cache `make_hole`, replace `Dictionary` results with a preallocated struct, or move the hot loop to C# / GDExtension (a bigger decision, not made here).
- `1 LSB` sin/cos and 1.6 brads atan errors are fine for golf, but if the sim later needs sub-degree aim precision, add interpolation tables or widen the table.
- The shot model is a placeholder (no roll-out, no slopes, no per-club table, no terrain). Balance is not meant to be judged from it.
- If a golden mismatch appears on one platform only, the first suspects are int division/modulo of negatives and `>>` on a negative that I missed. Compare `test_fixed` and `test_rng` first, since they isolate those.

## 6. For Nathan

Nothing to do now. When CI (workstream A) is running, the only thing to check is that the `test_shotsim.gd` and `test_rng.gd` results are green on the Linux and macOS jobs, and later that the 60-golfer hash line looks identical in the Android and iPhone logs (workstream I's device runbook covers collecting it).

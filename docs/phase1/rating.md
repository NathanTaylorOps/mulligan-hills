# Phase 1: rating engine (MHRATE-1.0.0 / MHSIM-1.0.0)

STATUS: the Python reference RAN (all 15 spec fixtures pass, goldens generated). The GDScript is written and **NOT YET RUN**: nobody could start Godot in this environment, so no GDScript parse, no gdUnit4 test and no timing exists. CI is the first real execution. Expect small parse fixes on first run.

## Purpose and public API
Integer-only, deterministic hole rating and course roll-up exactly as `docs/spec/rating/rating-engine.md` and `golfer-sim.md` specify (axes Accuracy 25 / Imagination 35 / Length 20 / Beauty 20 permille weights, fairness multiplier 0.4 to 1.0, 120 golfers in 6 bands, 70% mean + 30% worst-third roll-up, duplicate factor down to 0.4, 66 advisor codes). `params.json` is the data source for every table.

```gdscript
MHRatingEngine.rate_hole(hole_def: Dictionary, ctx: Dictionary) -> Dictionary
MHRatingEngine.rate_course(hole_defs: Array, ctx: Dictionary) -> Dictionary   # {"course": rollup, "holes": [results]}
MHRatingEngine.rollup_course(holes: Array[MHRHole], results: Array) -> Dictionary   # no simulation, used by tests
MHRatingEngine.rate_shared(raw, ctx)       # validate_input first (shared codes, daily challenge), then rate
MHRatingEngine.validate_input(raw) -> {"ok", "code"}      # E01..E10
MHRatingEngine.explain(result) -> [{code, severity}]      # top 3 advisor codes
```
`ctx` keys: `save_secret`, `rating_epoch` (seed = `H32(secret, epoch, slot_id, 0x4D48)`), or an explicit `hole_seed` (daily and tournament seeds: `MHRMath.daily_seed`, `MHRMath.tournament_seed`); `condition {wx, wy, rain}` (default calm = the only official condition); `preview` (N = 30, estimate only); `want_records` (adds per golfer arrays). Hole result keys: `valid, score_pm (0..1000), score (rdiv(score_pm,10)), A, I, Len, B, F, par, L, means, forced_pm, pickup_pm, tree_pm, risk_pm, raw_corr, comps, pace_pm, pace_pen, spread, T_par, inversions, over, bend_s, elev, Oc, R, shape, PQ, B_raw, n_tree, raw_trees, wat, cats, stacked, dead, hash (sim hash), content_hash, hole_seed, engine_version, sim_version, params_hash, reasons (top 3), all_reasons`. Course roll-up keys: `course_x10 (0..1000, shown /10), mean, low_third, factors, adj, n_dup, valid_non_dead, tier (1..5 reached by hole count AND score gate), codes {course, per_hole}`.

Hole input (RHI v1): `slot_id, tee [x,y], green [x,y,r], tee_z_mm, green_z_mm, features[]` in whole yards, hole-local frame, exactly as spec 2.1. Rock and flower features are counts. Tree features are `{t:"tree", at:[[x,y],...]}`; the fixture form `{t:"tree", rect, count}` is also accepted.

## Files
Game code (`game/core/rating/`): `mh_rmath.gd` (fdiv, rdiv, isqrt, interp, H32, MH-HASH64, seeds), `mh_rparams.gd` (loads `res://data/rating/params.json` once, `params_hash`), `mh_rhole.gd` (hole model, lies, tree buckets, content hash), `mh_rsim.gd` (golfer sim, planner, cost table cache), `mh_rating_engine.gd` (axes, hole score, API), `mh_rcourse.gd` (descriptor, duplicate factor, roll-up, tiers), `mh_radvisor.gd` (66 codes, triggers), `mh_rtournament.gd` (sustained score, prestige, tie-break, RC009/010/07x/081), `mh_rvalidate.gd` (E01..E10).
Runtime data: `game/data/rating/params.json` (byte identical copy of `docs/spec/rating/params.json`; `tests/` and `docs/` are not exported, `data/` is). The golden file is test only: `game/tests/rating/golden/rating_golden.json`.
Tests (`game/tests/rating/`): `test_rating_math.gd`, `test_rating_validate.gd`, `test_rating_sim.gd` (11 simulated holes, bit exact sim hash and all axes), `test_rating_course.gd`; helper `rating_golden.gd`.
Reference (`tools/reference/rating/`): `rating_core.py` (math, hole, validation, sim), `rating_eng.py` (axes, roll-up, advisor, tournament), `selftest.py` (runs all fixture rules, about 1 minute), `gen_golden.py` (writes the golden and copies params, about 45 s).

## How the two simulations relate (MHShotSim versus rating)
`MHShotSim`, `MHSimHash`, `MHRng`, `MHHole` in `game/core/` are the Phase 0 determinism benchmark: a stateful PCG32 shot loop over a lie grid, built to prove cross platform bit equality and to measure speed (Gate 0). They are untouched and still used by their own tests. The rating engine does NOT use them: it has no stateful RNG (every draw is a pure function of `(hole_seed, golfer, shot, channel)` via `H32`), its own vector hole model (rectangles and circles, not a lie grid), its own planner and its own hash (MH-HASH64, two 32-bit FNV-1a lanes; `MHHash` is FNV-1a 64 and is a different function). What carries over is only the method: integers only, Python reference first, golden vectors, bit equality on every platform.

## Decisions taken on ambiguities (the spec stays authoritative; each is a candidate spec fix)
1. The older `tools/reference/rating_sanity.py` is a sanity model, not the shipping definition. The new reference follows the spec where the two differ, so some numbers moved: OB penalty adds 150 s and water 90 s (the old model gave OB 90 s because it tested the returned lie); a ball stopped by a tree in a bunker is `deep` (spec: deep unless green, water, OB; old model kept bunker); RC004 and RC008 use the lie rule (out of bounds counts) with correct operator precedence; `{t:"tree", rect, count}` expansion has no upper y bound (spec 2.1 text). Effect: fixture 08 golden is unchanged (hash `b2fa7a1f29bf7394`, score 563); fixture 06 forced hole 132 became 120; fixture 11 mixed course 248 became 243. All fixture rules still pass.
2. Planner `here` (the "safe candidate" baseline) is `ES(lie, Dg)` at the 4 yd cell centre used for the cached cost table, not at the golfer's exact position (spec 8 does not say). Same for the lattice costs; the aim actually flown is recomputed from the exact position.
3. JSON numbers reach GDScript as floats. `validate_input` therefore treats a float with a whole value as an integer; only fractional, NaN, infinite, string, bool and null are E07. The reference does the same.
4. `validate_input` also returns E06 for rect/circle/at arrays of the wrong length and for a missing shape on area features (spec lists "a shape array of the wrong length"); a negative or non-integer `count` is E09 / E07; a hole `features` stub with `_len` at or below 3000 is E10 (it has no features).
5. `content_hash` byte string (spec only names the order): int32 LE of tee x,y, green x,y,r, tee_z, green_z; feature count; each area feature sorted by (type code fairway 1, deep_rough 2, bunker 3, water 4, ob 5; shape 0 rect or 1 circle; coords); rock count, flower count, tree count; trees sorted by (x, y). Coordinates in whole yards. `slot_id` excluded.
6. RC009 needs where holes sit relative to each other, which the hole input does not carry. `MHRTournament.near_holes(origins, tees_greens)` takes optional per hole world origins; the course screen must supply them.
7. Hole-count gates (6/10/14/18) are constants in `MHRParams.hole_gates` (not in `params.json`); score gates come from `params.json`. A hole counts only if valid and `score_pm >= 250` (DEC-048, DEC-063). Dead holes stay in mean and worst third. `tier` is the highest tier whose gates and all lower tiers' gates pass.
8. "Next tier" for RC066 and RC067 is `tier + 1`; no code at tier 5.
9. Duplicate factor uses the best match among earlier valid holes only (first copy full value); `similar_s` and `similar_j` expose the best similarity and its partner for the advisor.
10. Time penalties: bunker +30 s is applied to a shot played FROM a bunker; water +90 s and OB +150 s are applied to the shot that incurred the penalty.
11. `rate_course` gives each hole its own seed from its own `slot_id`. An explicit `hole_seed` in `ctx` would give every hole the same seed; use it only for single holes.
12. Preview (N = 30) uses band counts `[3,5,8,8,4,2]`; the result carries `preview: true`.
13. The result cache keyed by `content_hash`, seed, version and condition (spec 3) is NOT in this engine; it belongs to the caller (the course data owner). Rating is a pure function, so the caller can memoise on `(content_hash, hole_seed, engine_version, params_hash, condition)`.

## Tested (reference, run here) and NOT YET RUN list
Run here, Python 3.11: `python3 tools/reference/rating/selftest.py` passes all 15 fixture files (0 fails); `python3 tools/reference/rating/gen_golden.py` writes the golden. The old `rating_sanity.py` also still passes unchanged.
NOT YET RUN (everything below needs CI or a Godot machine):
- Every `.gd` file in `game/core/rating/` and `game/tests/rating/` (no parse check at all).
- Bit equality of GDScript with the Python goldens: sim hash, all axes and all advisor codes of 11 holes; roll-ups and descriptors of 3 courses; hash, seed and `rdiv/fdiv/isqrt/interp` vectors.
- Cross platform equality (Android, iPhone): the 32-bit hash multiply is done in 16-bit limbs so it does not rely on signed overflow wrap, but this is unproven.
- Speed: Python needs about 0.6 s per hole; GDScript is unmeasured. `test_rating_sim.gd` simulates 11 holes and may take tens of seconds in CI. If it is too slow, drop cases from `gen_golden.py` first (the synthetic par 3 and par 5, tree spam).
Unverified Godot API use: `static var` typed initialisers, `PackedInt64Array.sort()`, `Array.sort_custom` with a lambda that calls a static method, `FileAccess.get_file_as_bytes`, `is_finite`/`floorf`, `Vector3i` as an int triple, `JSON.parse_string` float handling of whole numbers. Check the Godot 4.7 class reference if CI complains.

## Risks and follow-ups
- Speed on the benchmark phone (budget 250 ms per hole, 5 s per 18 holes) is unknown; levers are in golfer-sim.md section 14 and each changes results and the version. The sim allocates little in the hot loop (members, packed arrays) but is not yet profiled.
- The spec's own weak points stay open (`docs/spec/rating/open-questions.md`): dogleg modelling, risk term floor, calm only rating.
- Wiring: nothing in UI, save or buildings calls the engine yet. `buildings.json` gates use the 0..100 scale (32/42/52/62); compare them with `course_x10 / 10` (course_x10 >= 320 for 32.0). The save schema `ratings.course_score` stores 0..100 in the Phase 1 save fixture; decide whether it stores `course_x10`.
- Any change to a formula, table or constant needs a version bump and regenerated goldens (`gen_golden.py`).

## For Nathan
Nothing is needed from you to build. When CI first runs these tests, send the failing test names to the lead; the likely first failures are GDScript parse errors, not rating logic.

Questions (no instruction needed from you to proceed, answers change tuning only):
1. Gate scale: keep tier gates at 32/42/52/62 on the displayed 0..100 average (current choice, matches DEC-048 and `buildings.json`)? The reference model rates a plain wide hole about 37, so tier 3 already needs real design choices.
2. Is a 2 to 3 point flicker of a hole card at season change acceptable? (Hole scores move about 25 permille between epochs.) If not, the official run can use 180 or 240 golfers at 1.5x or 2x cost.
3. Should the player see per-axis numbers and advisor text from day one, or only the 0..100 hole score?

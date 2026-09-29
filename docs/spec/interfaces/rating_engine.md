# Interface: Rating engine (`game/core/rating/`, owner B until Phase 1 assigns)

## Implementation status (29 Sep 2026)
No rating code exists in `game/` (no `game/core/rating/` directory, no `MHRatingEngine`, `MHRatingContext`, `MHHoleRating`, `MHCourseRating`, `MHCourse`, `MHResult`, `MHTerrain`). The normative rating design is the spec in `docs/spec/rating/rating-engine.md`, `golfer-sim.md` and `params.json`, checked only against the Python reference `tools/reference/rating_sanity.py`. Where this API draft disagrees with that spec, THE SPEC WINS, and the fixes are applied below:
- Stored hole score is `score_pm` (0..1000 permille); the hole card shows `rdiv(score_pm, 10)` (0..100). Course score is `course_x10` (0..1000), shown as 0..100.0. The draft's "integer 0..100" applies to the displayed value only. The building data (`buildings.json`) gates on the 0..100 scale (25/30/36/42) while the rating spec and `params.json` `gates_avg_score_x10` say 320/420/520/620 (32/42/52/62): UNRECONCILED, see `docs/spec/OPEN_QUESTIONS.md`.
- The seed is one 32-bit `hole_seed = H32(save_secret, rating_epoch, slot_id, 0x4D48)` (`rating-engine.md` section 4), not `seed_hi/seed_lo`. There is no stateful PRNG (`MHRng` is not used by rating).
- Official runs use N = 120 golfers in six skill bands; preview mode N = 30 is an estimate and never feeds gates. The draft's `golfer_samples >= 100` is satisfied by 120.
- The engine reads only tee and green heights (`tee_z_mm`, `green_z_mm` in the hole input, mm). It does not need the terrain object; the `terrain` parameter below is optional convenience and the terrain classes that exist are `MHHeightGrid` and `MHTerrainEditor` (see `terrain.md`), not `MHTerrain`.
- Hashes: `content_hash` and the sim hash are `MH-HASH64` (two 32-bit FNV-1a lanes, 16 hex chars), which is NOT the same function as `MHHash` (FNV-1a 64) in `game/core/mh_hash.gd`.
- Lie names in the rating spec (water, ob, bunker, fairway, green, fringe, ...) are richer than the Phase 0 `MHHole` lies (8 constants); the rating engine will need its own hole model.

Purpose: score holes and courses. Pure function of geometry, terrain, seeds and golfer samples. Reads no camera, screen or wall-clock. Integers only. Formulas and the 10 required test cases live in `docs/phase0/determinism.md` (rating spec); this file freezes only the API shape.

## Score scale
Per axis and per hole: integer 0..100 in this draft (the spec computes axes in permille 0..1000 internally). Axes: accuracy, imagination, length, beauty, fairness (fairness is an axis and also a penalty input, defined in the rating spec). Course score: integer average of hole scores after the similarity penalty, 0..100.

## API
```gdscript
class_name MHRatingEngine extends RefCounted
const RATING_VERSION: String = "MHRATE-1.0.0"   # tag format set by B (spec/rating), not semver
func rate_hole(course: MHCourse, terrain: MHTerrain, hole_no: int, ctx: MHRatingContext) -> MHHoleRating
func rate_course(course: MHCourse, terrain: MHTerrain, ctx: MHRatingContext) -> MHCourseRating
func explain(rating: MHHoleRating) -> PackedInt32Array   # rows of [reason_code, severity 0..2, param_a, param_b]; UI maps codes to string keys advisor.<axis>.<reason>
func validate_course(course: MHCourse) -> MHResult        # hard limits from docs/spec/data/README.md; deterministic reject
```
```gdscript
class_name MHRatingContext extends RefCounted
var hole_seed: int                         # 32-bit, H32(save_secret, rating_epoch, slot_id, 0x4D48), NOT from the course hash (replaces seed_hi/seed_lo)
var rating_epoch: int
var golfer_samples: int                    # N = 120 official, 30 preview (estimate only)
var weather: MHWeatherState                # fixed reference weather for rating (documented), not live weather

class_name MHHoleRating extends RefCounted
var hole_no: int
var valid: bool                            # false for unplayable holes: score 0, never NaN
var score: int                             # 0..100
var accuracy: int; var imagination: int; var length: int; var beauty: int; var fairness: int
var similarity_penalty: int                # 0..100 points removed, from duplicate/mirror detection
var reasons: PackedInt32Array

class_name MHCourseRating extends RefCounted
var holes: Array[MHHoleRating]
var course_score: int                      # 0..100
var pace_score: int                        # 0..100, from a sim day, used by tournaments
func to_dict() -> Dictionary               # matches the `ratings` block of save.schema.json
```

## Rules the API must honour
- Stable: moving one object by 1 m changes a hole score by less than an epsilon (rating spec).
- Decoration caps: beauty gain from non-play objects is capped; length peaks near par-appropriate yardage.
- Every result includes `RATING_VERSION`; server payloads and saves carry it; results with a different version are recomputed or rejected.
- Unplayable/malformed input: `valid=false`, `score=0`, reason code `INVALID_*`.
- Imported (shared) courses are always re-rated locally; an embedded score is ignored (post-launch feature, but the validator exists now).

## Consumers
Buildings (gates read `course_score`, `holes.size()`), economy (fee and demand), tournaments (snapshots), UI (advisor, heatmaps), save (cache).

## Contract tests
The 10 rating test cases; golden hole and course scores byte-identical across platforms (Gate 0 item 3 covers the sim hash; rating goldens are added in Phase 1).

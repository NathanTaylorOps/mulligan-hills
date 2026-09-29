# Interface: Rating engine (`game/core/rating/`, owner B until Phase 1 assigns)

Purpose: score holes and courses. Pure function of geometry, terrain, seeds and golfer samples. Reads no camera, screen or wall-clock. Integers only. Formulas and the 10 required test cases live in `docs/phase0/determinism.md` (rating spec); this file freezes only the API shape.

## Score scale
Per axis and per hole: integer 0..100. Axes: accuracy, imagination, length, beauty, fairness (fairness is an axis and also a penalty input, defined in the rating spec). Course score: integer average of hole scores after the similarity penalty, 0..100.

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
var seed_hi: int; var seed_lo: int         # derived from the save secret and rating_epoch, NOT from the course hash
var rating_epoch: int
var golfer_samples: int                    # N >= 100
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

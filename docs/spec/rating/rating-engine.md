# Rating engine spec (MHRATE-1.0.0)

Owner: workstream H1. Status: specification, checked against a Python reference model. No GDScript for this spec has been written or run. Companion files in this folder: `golfer-sim.md` (the shot simulation, arithmetic rules, hash), `params.json` (normative tables), `open-questions.md` (what needs a human playtest), `sanity-results.txt` (output of the reference model). Fixtures: `docs/spec/fixtures/rating/*.json`. Reference model: `tools/reference/rating_sanity.py`.

Where this spec and the reference model disagree, treat it as a spec bug and report it. The reference model is a sanity check of formulas, not the shipping code, and every number marked "measured" below comes from it, not from the game.

Contents: 1 Scope and conventions, 2 Inputs and validation, 3 Sampling, 4 Seed policy, 5 The axes, 6 Hole score, 7 Course roll-up and tier gates, 8 Anti-exploit terms, 9 Dead and unplayable holes, 10 Weather, 11 Tournaments and prestige, 12 Tie-breaks, 13 Versioning and payloads, 14 Sanity results, 15 Advisor reason codes.

## 1. Scope and conventions

The rating engine reads course data only (never the camera). It has no rendering dependency and runs headless. It is integer only (see `golfer-sim.md` section 1 for the arithmetic rules that apply here too: `fdiv`, `rdiv`, `isqrt`, no float, no unordered iteration).

Ranges and units:

| Value | Type | Range | Unit |
| --- | --- | --- | --- |
| Axis value (Accuracy `A`, Imagination `I`, Length `Len`, Beauty `B`, Fairness `F`) | int | 0 to 1000 | permille |
| Hole score `score_pm` | int | 0 to 1000 | permille, shown to the player as `rdiv(score_pm, 10)`, integer 0 to 100 |
| Course score `course_x10` | int | 0 to 1000 | shown as one decimal, 0.0 to 100.0 |
| Length | yards | 60 to 1000 valid | integer yards |
| Strokes statistics | int | | strokes x 100 |

Rounding: floor for positive quantities unless `rdiv` is named. Every clamp is inclusive. The output is always a well defined integer. Invalid input returns `valid = false`, `score_pm = 0`, and reason codes; the engine never raises, never divides by zero (all divisors are constants or guarded), never returns NaN (no float exists).

## 2. Inputs and validation

### 2.1 Hole input (RHI v1)

Hole-local frame: yards, `x` lateral (right positive), `y` forward from the tee. Fields:

* `tee: [x, y]`, `green: [x, y, radius]`, `tee_z_mm`, `green_z_mm` (int, default 0).
* `slot_id`: stable integer id of the hole on this course, assigned once at creation from a per-save counter that only increases. Deleting a hole and creating another gives a new id.
* `features`: list of `{t, rect:[x0,y0,x1,y1]}` or `{t, circle:[cx,cy,r]}` for `t` in `fairway`, `deep_rough`, `bunker`, `water`, `ob`; `{t:"tree", at:[[x,y],...]}` for trees; `{t:"rock"|"flower", count}`. Test fixtures may also give trees as `{t:"tree", rect:[x0,y0,x1,y1], count:n}`: the loader expands it to `at` deterministically (spacing `s = max(1, isqrt(area // n))`, row major from `(x0 + s//2, y0 + s//2)`, `nx = max(1, (x1 - x0) // s)` per row, first `n` points). The shipping data format stores `at` only.

Everything not covered by a feature is light rough. The play area outside `|x| <= 120`, `y < -30` or `y > length + 80` is out of bounds.

The source of truth for a hole is its **canonical content**: `tee, green, tee_z, green_z`, then features sorted by (type code, shape code, coordinates), trees expanded and sorted by `(x, y)`, all as int32 values. `content_hash = MH-HASH64` (see `golfer-sim.md` section 13) of that byte string. `slot_id` is not part of the content hash.

### 2.2 Limits and deterministic rejection

Any input that will be rated from outside the running game (a shared hole code after launch, a daily challenge submission, a server re-simulation) passes `validate_input` first. It runs before any per-feature work and rejects in this order, returning the first code found. All limits are constants.

| Code | Condition |
| --- | --- |
| E01_NOT_OBJECT | input is not an object |
| E02_BAD_SCHEMA_VERSION | `schema != 1` |
| E03_ENGINE_MISMATCH | `engine != "MHRATE-1.0.0"` |
| E04_MISSING_FIELD | no `hole`, `tee`, `green` or `features` |
| E05_TOO_MANY_OBJECTS | more than 3000 features, or more than 1500 trees in total (declared count is checked before iterating) |
| E06_TRUNCATED_OR_SHAPE | `tee` not length 2, `green` not length 3, or a shape array of the wrong length |
| E07_NON_INTEGER | any coordinate that is not a JSON integer (floats, strings such as "NaN", "Infinity", booleans, null) |
| E08_OUT_OF_RANGE | any coordinate with magnitude above 1200 |
| E09_NEGATIVE_SIZE | green radius negative, rect with `x1 < x0` or `y1 < y0`, circle radius negative |
| E10_BAD_FEATURE_TYPE | feature type not in the allowed list |

Also: encoded size above 262144 bytes is rejected before parsing; the parser is a bounded reader that never allocates from a declared length without checking it against the limits. Rejection is deterministic and independent of hardware. A claimed score or claimed axis values in the input are never read; the engine always recomputes. The reference model rejects the 14 fuzz cases in fixture 09 with the listed codes and rates the embedded-score case from geometry only.

### 2.3 Hole validity

After validation the hole is **valid** unless one of these holds (score 0, `valid = false`):

| Code | Condition |
| --- | --- |
| RC001 | no tee |
| RC002 | no green |
| RC003 | tee to green distance below 60 or above 1000 yards |
| RC004 | green centre inside water or out of bounds |
| RC005 | more than 3000 features |
| RC006 | green radius below 5 or above 30 yards |
| RC007 | unplayable: all 10 band A golfers pick up in the sim |
| RC008 | tee inside water or out of bounds |

`L` is the integer tee to green distance, `isqrt(dx*dx + dy*dy)` in yards. Par is derived: `L <= 260` par 3, `L <= 470` par 4, else par 5. (Par is not player-set in v1, so par and length cannot be gamed apart.)

## 3. Sampling

* Golfers per official rating run per hole: `N = 120` (bands and skills in `golfer-sim.md` section 4). Preview mode `N = 30` is labelled an estimate and never feeds gates, tournaments or leaderboards.
* Conditions: the official rating uses one condition, the calm dry reference `{wx:0, wy:0, rain:0}`.
* Cost control: a hole is re-rated only when its `content_hash`, the `hole_seed`, the engine version or the condition changes. Undo, redo and no-effect edits (painting the same value) reproduce the same canonical content and therefore the same rating without a re-run. Rating runs are time-sliced across frames; the result is committed when all holes finish.
* Measured cost in the reference model: 50,000 to 62,000 ball-flight evaluations and about 0.7 to 0.8 s of Python per hole. GDScript speed is unmeasured (Gate 0 must measure it).

## 4. Seed policy

Goal: tiny edits do not re-roll results; re-rolling cannot be farmed; a designer cannot tune a hole to the exact trajectories of 8 fixed shots.

```
hole_seed = H32(save_secret, rating_epoch, slot_id, 0x4D48)
```

* `save_secret` is a 32-bit value generated once per save from the operating system's secure random source (the only non-deterministic input in the whole engine). It is stored in the save and never shown. It exists so the seed cannot be precomputed offline by a third party. It is not a security boundary against the owner of the device.
* `rating_epoch` is a small counter stored in the save. It increases by 1 once per in-game season (rule owned by the calendar feature; the player cannot trigger it).
* `slot_id` as in 2.1.
* The seed does **not** depend on hole content. Every random draw inside the sim is a pure function of `(hole_seed, golfer index, shot number, channel)` (`golfer-sim.md` section 3), so moving one tree changes only the golfers whose ball physically meets that tree. The rest of their draws are unchanged (common random numbers).
* Anti-farming: a player cannot change `save_secret`, cannot choose the epoch, and cannot change the seed by editing. The only way to draw a new seed for a hole is to delete it and build another (a new `slot_id`), which costs the build price and resets its rating history. With `N = 120` the seed-to-seed spread of one hole score is small (below) and the course score averages over up to 18 holes, so the possible gain is far below the cost of rebuilding.
* Anti-sniping: the seed changes every epoch, so tuning to one draw decays. A designer who tunes to the calm-condition draws still faces different draws next season, and the accuracy fit and fairness rates are statistics over 120 golfers, not single trajectories.
* Daily challenge: seed is public: `H32(0xDA11, challenge_id, slot_id, 0x4D48)`. Every player gets the same draws; the server re-simulates.
* Tournament: seed `H32(save_secret, event_id, slot_id, 0x7E)`, a new draw not seen by the player before the event.

Stability requirements (test 08). One tree moved one yard must change the hole score by at most 60 permille. Measured 5 permille on fixture 08. Epoch to epoch variation of a hole score (measured over 8 epochs on one hole): min 501, max 588, range 87 permille (standard deviation about 25). For an 18 hole course the course score varied 437 to 448 (range 11) over 6 epochs, so gate flicker is about one score point at most. Tier gates are persistent once bought (master plan, review fixes), so epoch noise cannot lock a player out of something they already own.

## 5. The axes

`N`, band means and flags come from the sim (`golfer-sim.md`). Notation: `bm[b]` is the mean strokes x 100 of band `b` (A=0 to F=5, capped at par + 4); `pm(flag)` is the permille of the 120 golfers that have the flag set on this hole.

### 5.1 Accuracy `A` (does the hole reward good striking, and separate skill levels)

Accuracy measures how strongly the hole separates golfers by skill. A hole that everyone scores the same on rewards no precision; a hole that only scratch golfers can finish is separated too hard.

1. Fit a least-squares line of strokes on skill over all 120 golfers, and take the fitted difference across a reference skill gap of 530:
   `spread = max(0, rdiv(-Sxy * 100 * 530, Sxx))`, with `Sxy = sum (skill_i*N - S) * (strokes_i*N - T)`, `Sxx = sum (skill_i*N - S)^2`, `S = sum skill`, `T = sum strokes`. (Strokes x 100.) All 120 golfers are used because the four band means are too noisy.
2. Target `T_par`: par 3 = 120, par 4 = 220, par 5 = 260 (strokes x 100).
3. `A = 1000 * spread // T_par` if `spread <= T_par`, else `max(400, 1000 - (spread - T_par) * 600 // T_par)`.
4. Inversions: count `i` in 0..4 with `bm[i+1] < bm[i] - 15`. `A = clamp(A - min(300, 100 * inversions), 0, 1000)`.

Cap: 1000. Meaning: a wide flat 400 yard par 4 measured 563 to 595 in the reference model (high enough to pass the "at least 500" fixture bound, well short of a maximum).

### 5.2 Fairness `F` (is the hole playable, and are the penalties the golfer's own doing)

Fairness is an axis and a multiplier (6): it is computed as an axis and then multiplies the weighted sum. Only penalties the golfer could not avoid count.

* `forced_pm = pm(flag 1)`: penalty on a shot where no safe candidate existed (`golfer-sim.md` sections 8 and 9).
* `pickup_pm = pm(flag 4)`, `tree_pm = pm(flag 8)`.
* `over = max(0, bm[2] - (par * 100 + 180))` (band C mean above par + 1.8).
* `P1 = min(700, 2 * forced_pm)`, `P2 = min(200, 2 * pickup_pm)`, `P3 = min(100, tree_pm)`, `P4 = min(250, 2 * over)`.
* `F = clamp(1000 - P1 - P2 - P3 - P4, 0, 1000)`.

Design choices that answer the review: a risk and reward hole is not penalised for optional water because `pens >= 2` on a chosen line with a safe line available is a **chosen** risk; and a mishit into water from a safe aim is **variance**. Neither lowers `F`. In the reference model a hole with a central lake and safe routes both sides scored `F = 1000` against `F = 984` for the plain hole. A hole whose only landing strip is a 12 yard island in water scored `F = 0` with forced penalties for 866 permille of golfers.

### 5.3 Imagination `I` (does the player face choices)

Three parts:

1. **Corridors** `Oc`. Take 4 slices across the hole at 25, 40, 55 and 70 percent of `L`, perpendicular to the tee to green line. On each slice sample `lat = -60..60` in steps of 2 yards. A sample is blocked if its lie is `water`, `ob`, `bunker` or `deep`, or a tree covers it (tree radius 2 yards). A corridor is a run of at least 6 consecutive unblocked samples (12 yards). `raw_corr` is the largest corridor count on any slice, `comps = max(1, raw_corr)`. `Oc = 0` if `comps <= 1`, 800 if `comps == 2`, 1000 if `comps >= 3` (no reward beyond 3: spaghetti guard). `raw_corr == 0` (no playable corridor at some slice) still gives `comps = 1`; it also raises RC028.
2. **Temptation** `R`, only if `Oc > 0`. `risk_pm = pm(flag 16)` (golfers who took a chosen risk line). `R = 300 + 700 * risk_pm // 150` for `risk_pm < 150`; `1000` for 150 to 500; `1000 - (risk_pm - 500) * 700 // 250` for 501 to 750; `max(0, 300 - (risk_pm - 750) * 300 // 250)` above 750. `R = 0` when `Oc = 0`. Rationale: some, but not most, golfers gamble.
3. **Shape**. For par 4 and 5, take the median first-shot landing point `M` of band C (median of x and of y, lower median for even counts). `bend_pm = |cross(M - tee, green - M)| * 1000 // (|M - tee| * |green - M|)` (the sine of the turn, 0 when either length is 0; par 3 uses 0). `bend_s = min(1000, max(0, bend_pm - 60) * 1000 // 240)`. `elev = min(1000, |green_z - tee_z| * 1000 // 5486)`. `shape = (600 * bend_s + 400 * elev) // 1000`.

`I0 = (450 * Oc + 350 * R + 200 * shape) // 1000`; then `I = I0 * min(1000, 2 * F) // 1000` (an unfair hole cannot bank Imagination). Cap 1000.

Measured: plain wide hole `I` about 0; a hole with a central lake 28 x 110 yards `I = 465`; the wider variant `I = 572` with 66 permille of golfers attempting the risk line.

### 5.4 Length `Len`

`Len = interp(length_table, L)` from `params.json`: (60,0), (120,600), (150,1000), (190,1000), (230,750), (260,500), (300,750), (370,1000), (430,1000), (470,700), (500,850), (530,1000), (570,1000), (650,600), (700,300), (850,0). So each par has its own peak: par 3 150 to 190 yards, par 4 370 to 430, par 5 530 to 570. A 520 yard par 5 scores 950; 900 yards scores 0. Cap 1000. Measured `Len = 950` at 520 and `0` at 900.

Anti-exploit: length is the tee to green straight line, so loops and detours add nothing. A forced detour costs strokes and lands in Accuracy and Fairness. There is no reward above 570 yards on a par 5.

### 5.5 Beauty `B`

All parts saturate; none scales with raw object counts.

* `pol`: 100 if the hole is valid, plus 50 if at least 60 percent of points sampled every 10 yards along the tee to green line have lie `fairway`, `green` or `fringe`. (Shaped land beats default land.)
* `tr`: trees counted once per 3 yard cell (`(x // 3, y // 3)`), only trees within 60 yards lateral of the tee to green line and within `-10..L+30` yards along `y`; at most 60 counted (`n_tree`); `tr = 120 * n_tree // (n_tree + 25)`. Maximum 120.
* `wat`: water area `wa` = 16 sq yd for each cell of a 4 yard grid over `x in [-60, 60]`, `y in [0, L]` that is water. `wat = 120 * wa // (wa + 800)`. Maximum 120.
* `var`: 25 for each of five categories present: trees (`n_tree >= 3`), rocks (`count >= 1`), flowers (`count >= 3`), water (`wa >= 200`), bunkers (at least one). Maximum 125. Rocks and flowers add nothing beyond presence.
* `rel`: `min(100, |green_z - tee_z| * 100 // 5486)`.
* `B_raw = min(700, pol + tr + wat + var + rel)` (the sum cannot exceed 615 in v1).
* `PQ = (A + I + Len + F) // 4` (play quality). `B = min(B_raw, PQ + 300)`. A pretty hole that plays badly cannot bank Beauty.

Caps and their effect (measured): a plain hole `B = 150`; the same hole with 500 trees near the line `B = 259`; total score rose from 366 to 378 permille (+12).

### 5.6 Pace and difficulty inputs

* `pace_pm = mean(time_s of band C) * 1000 // pace_std[par]`, with `pace_std` = 420, 560, 720 seconds for par 3, 4, 5. Above 1150 the hole loses `pace_pen = min(80, (pace_pm - 1150) // 4)` permille from its final score. Below 1150 there is no bonus.
* Difficulty is not a separate axis. Its inputs are `bm[2] - par*100` (band C over par, in `P4`) and the accuracy spread. Game difficulty modes (master plan: Easy, Normal, Hard, owned by the economy workstream) never change a hole score: they change the visitor mix (`band_population_pm`) and cash flow only, so leaderboards and gates are mode independent.
* Course level pace (queues, tee sheet) is a separate system; it receives `time_s` per band per hole from the sim.

## 6. Hole score

```
base  = (250*A + 350*I + 200*Len + 200*B) // 1000
m     = 400 + 600*F // 1000            (F = 0 gives 40 percent of the score, F = 1000 gives 100 percent)
score = clamp(base * m // 1000 - pace_pen, 0, 1000)
```

Weights sum to 1000: Imagination 35 percent (it is what makes a hole good rather than merely playable), Accuracy 25, Length 20, Beauty 20 (bounded by caps). Fairness acts as a multiplier so that an unfair hole cannot be rescued by its other axes. `score_pm` is stored; the hole card shows `rdiv(score_pm, 10)`.

A hole scoring below 250 permille is **dead**.

Measured on the reference model (calm, epoch 1): plain 400 yard par 4 wide fairway, 366 (shown 37); plain with 500 decorative trees, 378; 400 yard par 4 with a central lake, 583 and 648; 520 yard par 5 plain, 360; 900 yard par 5, 176; forced water hole, 132; 12 yard island fairway (all scratch golfers pick up), invalid 0.

## 7. Course roll-up and tier gates

### 7.1 Roll-up

For a course of `n` holes (1 to 18) in course order `0..n-1`, with hole scores `score_i` (0 for invalid holes):

1. **Duplicate factor.** Each valid hole `i` has a mirror invariant descriptor: 72 coverage cells = 6 bins along the tee to green axis x 3 bands of absolute lateral offset (up to 10, up to 25, up to 50 yards) x 4 types (water, bunker, tree, ob). Water, bunker, ob cell value = permille of 4 yard samples in the cell of that type; tree cell value = `min(1000, trees * 1000 // 20)`. The hole frame is rotated to the tee to green axis and lateral offset is taken as absolute value, so mirror images match. For a pair: `Dc = sum |cell_i - cell_j| // 3`; `S = 1000 - min(1000, Dc + 3*|L_i - L_j| + 5*|dz_i - dz_j| + 20*|par_i - par_j|)` with `dz = (green_z - tee_z) // 914` (whole yards). `f_i = min over valid j < i of dup_factor(S_ij)`, with `dup_factor(S) = 1000` if `S <= 700`, else `1000 - 2 * (S - 700)` (0.4 at `S = 1000`). The first copy keeps its full score; later copies pay. `adj_i = score_i * f_i // 1000`.
2. `M = sum(adj) // n`. Sort holes by `(adj, index)` ascending; `k = ceil(n / 3)`; `W = sum of the k lowest adj // k`.
3. `base = (70 * M + 30 * W) // 100`.
4. If `n >= 6` and fewer than 2 different pars exist among valid holes, `base = base * 920 // 1000`.
5. `course_x10 = clamp(base, 0, 1000)`.

Why this roll-up. A plain mean lets nine good holes hide nine dead ones. A minimum punishes every experimental hole and makes one bad hole decide the whole course, which discourages bold design. A weighted mean with the worst third blended in punishes weak holes about twice as hard as their share of the average but still lets a single experiment through. Measured: nine decent holes plus nine dead holes has mean 339 and low third 109, giving 248 (below the plain mean by 91); 18 varied holes 440; the same hole copied 18 times 214 (the first copy at full value, later copies at factors between 400 and 1000 because each copy gets its own seed and only the fully similar ones reach 400).

### 7.2 Building tier gates (proposal for the economy workstream)

The master plan gates tiers on scores of 150, 300, 500 and 750 with no scale and, the economy review found, gates that collapse into hole count if read as a sum. This spec replaces them with gates on the **average hole score** `course_x10` (which is already an average, so hole count is a separate gate):

| Tier | Hole count gate (unchanged) | Old gate | New gate: `course_x10` at least | Shown as |
| --- | --- | --- | --- | --- |
| 2 | 6 | 150 | 320 | 32.0 |
| 3 | 10 | 300 | 420 | 42.0 |
| 4 | 14 | 500 | 520 | 52.0 |
| 5 | 18 | 750 | 620 | 62.0 |

Data lives in `params.json` (`gates_avg_score_x10`), so tuning needs no code. Calibration from the reference model: plain wide holes rate about 37, so a course of plain holes clears tier 2 but not tier 3; holes with a real choice rate 55 to 65, so tier 4 needs about half the course to have meaningful choices and tier 5 needs nearly every hole to. Copies and dead holes drag the score down through 7.1. **These four numbers are provisional** (see `open-questions.md` item 1); the economy simulation should treat them as an input range of plus or minus 6 points.

Counting toward the hole-count gate: a hole counts only if valid and not dead (`score_pm >= 250`). This stops padding a course with junk to reach 10, 14 or 18.

Persistence: gates are checked at purchase; the master plan review fix states holes and buildings a purchased tier depends on cannot be demolished. Rating changes after purchase never revoke a building.

## 8. Anti-exploit terms (summary)

| Exploit from the attack review | Term | Where |
| --- | --- | --- |
| Length farming (900 yard hole, cart path loops) | Length table peaks per par, zero at 850; tee to green straight distance only | 5.4 |
| Beauty and decoration spam | trees deduped per 3 yard cell, within 60 yards, at most 60 counted, saturating; categories give presence only; `B <= PQ + 300`; Beauty weight 20 percent | 5.5, 6 |
| Wide empty fairway scores top | Imagination 0, Accuracy limited by the spread fit, total 37 in the reference model | 5.1, 5.3 |
| Spaghetti holes for Imagination | corridor count capped at 3; Imagination multiplied by fairness; straight distance for Length | 5.3, 6 |
| Risk and reward punished | chosen and variance penalties do not count in Fairness | 5.2 |
| Mean hides dead holes | worst-third blend; dead holes counted; do not count toward hole gates | 7.1, 7.2 |
| Copied or mirrored holes | descriptor similarity with mirror invariance; duplicate factor down to 0.4 | 7.1 |
| Small edits re-roll the score | seed independent of content; common random numbers | 4 |
| Re-roll farming | seed from secret and epoch and slot; only reroll is delete and rebuild | 4 |
| Malformed input | validation limits and codes; claimed scores ignored | 2.2 |
| Forged client score | engine version and hash in payload, server re-simulation (13) | 13 |
| Tournament dress-up | snapshot, sustained score, cooldown, lock | 11 |
| Low fee farming pace | slow holes lose up to 80 permille through `pace_pen`; tee sheet consumes `time_s` | 5.6 |

## 9. Dead and unplayable holes

* **Dead**: valid, `score_pm < 250`. Advisor RC031. Counts in the roll-up at its score (dragging the worst third), does not count toward hole-count gates.
* **Unplayable**: fails validity (2.3), including RC007. Score 0, `valid = false`. It is included in the course as 0 in `M` and `W`. No crash, no NaN, no exception on any of: no tee, no green, tee in water, green in water, 3000 features, radius out of range, all scratch golfers picking up. Each has an advisor sentence via its reason code.
* A hole whose ball can never be replayed (every drop point is water) ends by the stroke cap and the 40 flight limit, never by an infinite loop.

## 10. Weather

* The official rating and the course score use the calm dry condition only. This keeps gates stable and lets the weather feature (a Should item) be added without changing any score.
* Live weather (wind, rain, seasons) changes simulated visitor rounds: strokes, `time_s`, complaints. It uses the same sim with a condition record `{wx, wy, rain}` from the save's weather schedule. No wall clock anywhere.
* A **wind check** (advisor, on demand): re-run one hole with a fresh breeze condition (default 12 mph from a direction chosen by the player or the prevailing wind of the save) at `N = 60`. It never changes the score. RC081 reports when mean strokes rise by 40 or more against calm.
* Tournaments use the event's own condition (11).
* The rating interface takes a condition argument from day one (Phase 1), so weather is not a retrofit. Measured (fixture 14): headwind 15 mph lifted the mean of the six band means from 463 to 513; tailwind 462; crosswind 471; rain level 2 495.

## 11. Tournaments and prestige

Definitions (units are in-game days; the calendar feature owns their real length; values are data). Only the sustained score and prestige formulas below are exercised by the reference model (fixture 10); the field simulation, lock and cooldown are specified but not modelled.

* **Checkpoint**: every 3 game days the engine records `course_x10` and the 18 `content_hash` values.
* **Sustained score**: `SS = min(current, median of the last 8 checkpoints)`, where missing checkpoints count as 0 and the median of 8 is `(s[3] + s[4]) // 2` of the sorted values. A new course therefore needs at least 24 game days of history at the qualifying level.
* **Application**: requires 18 valid non-dead holes, `SS >= 520` (52.0), mean band C `pace_pm` at most 1150, the building requirements from the master plan (tier 4 or lower buildings only), and no cooldown. On acceptance the 18 `content_hash` values are snapshotted and geometry edits to those holes are locked until the event ends. Cancelling unlocks and starts a 30 day cooldown. Any hole content mismatch at event start cancels the event (RC073).
* **Cooldown**: 30 game days after a completed event, 60 after a failed one (prestige below 200).
* **Field and run**: 24 professionals (skill 1000, style neutral) play the snapshot course once under the event condition drawn from the event seed (section 4). It is simulated with the same engine but a separate tournament roster; it does not change the course score.
* **Prestige** (0 to 1000, integer):
  `course = 600 * SS // 1000`
  `pace = 200 * clamp(2000 - mean_pace_pm, 0, 1000) // 1000` (on standard pace gives 200, at 150 percent of standard gives 100)
  `fac = min(200, 10 * (min(4,Clubhouse) + min(4,Restaurant) + min(4,ProShop) + min(4,CartBarn) + min(4,Maintenance)))` (tiers 1 to 4 only, so prestige never depends on tier 5 buildings; this breaks the circularity found in the contradiction review)
  `raw = course + pace + fac - 40 * unfair_holes` with `unfair_holes` the number of holes with `F < 300`
  `prestige = clamp(raw * (1000 - 100 * min(5, events_in_last_5)) // 1000, 0, 1000)`.
* The tier 5 gate "a hosted tournament" is met by one event with `prestige >= 400` (proposal; owned by the economy workstream).

Measured (fixture 10): honest course checkpoints [520,520,530,520,525,530,520,525] give `SS = 522` and prestige 633. A course that scored 380 for seven checkpoints and 700 for the last (18 pretty holes built the day before, then reverted) gives `SS = 380` and prestige 548: a gain of 85 below the honest course. The lock removes the revert step, and the checkpoint median removes the benefit of a last-day makeover.

## 12. Tie-breaks

* Leaderboards (daily challenge and any ranking of hole or course scores): sort by `score_pm` descending, then Fairness `F` descending, then server receive time ascending (server clock, never client), then submission id ascending. Sort is a total order, so it is stable. Fixture 15 gives the expected order.
* Inside the engine: holes with equal adjusted score sort by hole index ascending; golfers by `gid`; candidate aims by index; clubs by index; trees by `(x, y)`.
* Tournament results (player against the field, if a player entry is ever ranked): total strokes, then back nine, then last six, three and one hole strokes (countback), then `H32(event_seed, player_id)` lowest. There is no manual coin flip.

## 13. Versioning and payloads

* `engine_version = "MHRATE-1.0.0"`, `sim_version = "MHSIM-1.0.0"`. Any change to a formula, table, constant, sample size, tie rule or hash changes the version: patch for bug fixes that provably change no result on the fixture set, minor for changed tables or constants, major for changed formulas. Every fixture golden is regenerated on any change.
* A `params_hash` (MH-HASH64 of the bytes of `params.json` after normalising line endings to LF) is stored beside the version string, so a table change without a version bump is detected in CI.
* Every stored or transmitted rating carries `engine_version`, `sim_version`, `params_hash`, `hole_seed`, `rating_epoch`, `content_hash` and the sim hash. Stored ratings from another version are stale: they are shown greyed and re-rated on load. Leaderboards, daily challenges and shared codes are keyed by version; a bump starts a new board. (Gates already earned stay earned.)
* Server side: entries carry the compact hole spec (RHI), the claimed result and the hashes. The server re-runs the engine on a sample of entries and on every entry that would place in the top N, and rejects on any mismatch of the sim hash. The client cannot supply a score the server accepts without re-derivation for top placements. Play Integrity and account controls are outside this spec.
* Shared hole codes (post launch) carry geometry only, never a score; importing rates the hole locally.

## 14. Sanity results (reference model, not the game)

The full output is in `sanity-results.txt`. Run `python3 tools/reference/rating_sanity.py`. All 15 fixtures pass (0 fails). Summary of the ordering the formulas produce, hole score in permille, calm, epoch 1:

| Hole | Score | A | I | Len | B | F |
| --- | --- | --- | --- | --- | --- | --- |
| Plain 400y par 4, wide fairway | 366 | 563 | 0 | 1000 | 150 | 984 |
| Plain plus 500 trees near line | 378 | 595 | 0 | 1000 | 259 | 909 |
| Central lake 28x110 yd | 583 | 668 | 465 | 1000 | 270 | 1000 |
| Central lake 36x120 yd | 648 | 772 | 572 | 1000 | 276 | 1000 |
| 520y par 5 | 360 | 561 | 0 | 950 | 150 | 1000 |
| 900y par 5 | 176 | 719 | 0 | 0 | 150 | 742 |
| Forced water island strip | 132 | 509 | 0 | 1000 | 286 | 0 |

Courses: 18 varied hole family 440; 18 copies of one hole 214; nine decent plus nine dead 248.

Honest limits of this check. The sanity model shows ordering, not tuning. Three things are weak: (a) `risk_pm` (chosen risk) is small in most fixtures because the reference planner is a simple expected strokes model, so `R` sits near its floor of 300 unless the hole is wide open to gamble; (b) hole score noise across epochs is about 25 permille standard deviation, visible as a plus or minus 2 to 3 point flicker on the hole card at epoch change; (c) the fixtures cover straight and lake holes; there is no dogleg, no par 3 with a bunkered green, no sloped fairway. See `open-questions.md`.

## 15. Advisor reason codes

The advisor maps codes to sentences (text generator, another workstream). A code fires when its trigger is true. Severity: BLOCK (hole is not rated), SEVERE (score heavily hurt, must be shown), WARN (should be shown), INFO (shown in detail view or as praise). The advisor shows at most 3 codes per hole, highest severity first, then lowest code number. All metrics are defined in section 5 and `golfer-sim.md`; the text generator receives the code and these numbers: `L`, `par`, `score_pm`, the five axes, `forced_pm`, `pickup_pm`, `tree_pm`, `raw_corr`, `risk_pm`, `pace_pm`, `bm[2]`, `S` (similarity) and the other hole in the pair.

| Code | Severity | Trigger |
| --- | --- | --- |
| RC001 | BLOCK | no tee placed |
| RC002 | BLOCK | no green placed |
| RC003 | BLOCK | tee to green distance below 60 or above 1000 yd |
| RC004 | BLOCK | green centre in water or out of bounds |
| RC005 | BLOCK | more than 3000 features on the hole |
| RC006 | BLOCK | green radius below 5 or above 30 yd |
| RC007 | BLOCK | unplayable: all band A golfers pick up |
| RC008 | BLOCK | tee in water or out of bounds |
| RC009 | WARN | this hole's tee or green centre is within 10 yd of another hole's tee or green (course level) |
| RC010 | INFO | stored rating is from an older engine version (being re-rated) |
| RC011 | WARN | `L < 120` |
| RC012 | INFO | `120 <= L < 150` (very short par 3) |
| RC013 | WARN | `650 <= L <= 700` |
| RC014 | SEVERE | `700 < L < 850` |
| RC015 | SEVERE | `L >= 850` (Length is 0) |
| RC016 | INFO | `L` within 8 yd of a par boundary (260 or 470) |
| RC017 | INFO (praise) | `Len >= 950` |
| RC021 | SEVERE | `forced_pm >= 300` (water or out of bounds with no safe line) |
| RC022 | WARN | `100 <= forced_pm < 300` |
| RC023 | SEVERE | `pickup_pm >= 100` |
| RC024 | WARN | `30 <= pickup_pm < 100` |
| RC025 | WARN | `tree_pm >= 100` (trees punish wayward shots often) |
| RC026 | WARN | band C mean above par + 1.8 (`over > 0`) |
| RC027 | SEVERE | band C mean above par + 2.5 |
| RC028 | SEVERE | `raw_corr == 0` (no playable 12 yd corridor at some slice) |
| RC029 | INFO (praise) | `F >= 950` and `I >= 400` |
| RC031 | SEVERE | dead hole (`score_pm < 250`) |
| RC032 | WARN | `250 <= score_pm < 400` |
| RC033 | INFO (praise) | `score_pm >= 650` |
| RC034 | WARN | `pace_pm > 1150` (pace penalty active) |
| RC035 | SEVERE | `pace_pm >= 1400` |
| RC036 | WARN | `spread < 40%` of `T_par` (skill barely matters) |
| RC037 | WARN | `spread > 2 * T_par` (weaker golfers are crushed) |
| RC038 | INFO | one or more band inversions (weaker golfers beat stronger ones) |
| RC039 | INFO (praise) | `A >= 800` |
| RC040 | WARN | `A < 300` |
| RC041 | WARN | `I < 100` and `comps == 1` (no choices, no bend, no relief) |
| RC042 | INFO | `comps == 2` (two ways to play it) |
| RC043 | INFO (praise) | `comps >= 3` |
| RC044 | INFO | `comps >= 2` and `risk_pm < 150` (options, but nobody is tempted) |
| RC045 | WARN | `risk_pm > 500` (most golfers gamble; the safe route is too weak) |
| RC046 | SEVERE | `risk_pm > 750` |
| RC047 | INFO | par 4 or 5 and `bend_s == 0` (straight line of play) |
| RC048 | INFO | `elev == 0` (flat hole) |
| RC051 | WARN | `B < 200` |
| RC052 | INFO | trees at the 60 counted cap (more will not raise Beauty) |
| RC053 | INFO | raw tree count exceeds counted trees by 50 percent or more (stacked or out of view trees ignored) |
| RC054 | WARN | `B_raw > PQ + 300` (Beauty capped by play quality) |
| RC055 | INFO | fewer than 2 scenery categories present |
| RC056 | INFO (praise) | `wat >= 60` and water does not remove all corridors |
| RC057 | INFO | tree count within a single 3 yd cell above 1 (stacked objects) |
| RC061 | WARN | `S >= 850` with an earlier hole (copy or mirror) |
| RC062 | INFO | `700 < S < 850` with an earlier hole (very similar) |
| RC063 | WARN | fewer than 2 different pars on a course of 6 or more holes |
| RC064 | WARN | `M - W >= 150` (weak holes drag the course score) |
| RC065 | SEVERE | course contains one or more invalid holes (counted as 0) |
| RC066 | INFO | the number of valid non-dead holes is below the next tier's hole gate |
| RC067 | INFO | `course_x10` below the next tier gate (show the gap) |
| RC068 | WARN | mean course `pace_pm` above 1150 |
| RC071 | INFO | tournament: sustained score below 520 |
| RC072 | INFO | tournament: fewer than 8 checkpoints exist |
| RC073 | BLOCK | tournament: a snapshot hole changed |
| RC074 | INFO | tournament: cooldown active |
| RC075 | WARN | tournament: one or more holes with `F < 300` reduced prestige |
| RC076 | WARN | tournament: mean pace above 1300 |
| RC081 | INFO | wind check: mean strokes rose by 40 or more against calm |

That is 66 codes. Numbers not used (RC018 to RC020, RC030, RC049 to RC050, RC058 to RC060, RC069 to RC070, RC077 to RC080) are reserved.

Complaint feed: the golfer complaint feed is generated from per-golfer flags. A golfer complaint is eligible if the golfer had flag 1 (forced penalty), 4 (pickup) or 8 (tree hit) on a hole, and is written with that hole's top advisor code. At most one complaint per golfer per hole, at most 3 per hole per round. Praise is eligible for a golfer who finished at or below par on a hole with `comps >= 2`.

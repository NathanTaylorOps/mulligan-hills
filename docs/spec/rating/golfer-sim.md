# Golfer simulation spec (MHSIM-1.0.0)

Status: versioned simulation specification with Python reference coverage and current runtime implementation under `game/core/`. Runtime source/tests are authoritative for implemented behavior; this document remains the deterministic arithmetic/behavior contract and should be reconciled when either side changes. Companion: `rating-engine.md`; normative tables: `params.json`. If prose and `params.json` disagree on a table value, `params.json` wins. If prose and the reference model disagree on a formula, treat it as specification debt and resolve it explicitly.

Contents: 1 Rules of arithmetic, 2 Units, 3 Random numbers, 4 Golfer roster, 5 Clubs and shot execution, 6 Lies, hazards, trees, drops, 7 Putting, 8 Decision rule (planner), 9 Risk and skill, 10 Wind and rain, 11 Pace inputs, 12 Order of evaluation, 13 Result record and hash, 14 Performance budget, 15 Test vectors.

## 1. Rules of arithmetic (apply to everything in the sim and the rating)

1. Integers only. No float type, no `randf`, no trig, no `pow`, no engine physics, no engine noise, no threads.
2. Integers are 64-bit signed. Results must never exceed 2^62 in magnitude. The largest intermediate in the spec is the accuracy regression (about 9e16); it fits.
3. `fdiv(a, b)` is floor division with `b > 0`. GDScript `/` on ints truncates toward zero, so implement:
   `func fdiv(a: int, b: int) -> int: var q: int = a / b; if (a % b != 0) and (a < 0): q -= 1; return q`
   Every `//` in the reference model means `fdiv`.
4. `rdiv(a, b)` is round half away from zero, `b > 0`: `a >= 0: (2a + b) / (2b)` (truncating, positive operands); `a < 0: -((-2a + b) / (2b))`.
5. `%` is only used on non-negative left operands. `>>` and `<<` are only used on non-negative values masked to 32 bits.
6. `isqrt(n)` is the floor of the square root for `n >= 0`. Implement with integer Newton or binary search, never `sqrt()`. Vectors: isqrt(0)=0, isqrt(15)=3, isqrt(16)=4, isqrt(10^12)=10^6.
7. `clamp(x, lo, hi)`, `min`, `max` are the usual integer versions.
8. `interp(table, x)` is piecewise linear over ascending `[x, y]` pairs: below the first x return the first y, above the last x return the last y, otherwise `y0 + rdiv((y1 - y0) * (x - x0), x1 - x0)`.
9. No iteration over a Dictionary or Set in anything that affects results. All loops run over arrays in the order given in section 12. (The reference model sorts before iterating whenever it uses a set.)

## 2. Units

| Quantity | Unit | Notes |
| --- | --- | --- |
| Horizontal position | centiyard (cy), 1 yd = 100 cy | int. `x` is lateral (right positive), `y` is forward from the tee, hole-local frame, tee normally at (0,0). |
| Rating input geometry | whole yards | converted to cy by multiplying by 100 |
| Height | millimetre (mm) | only tee and green heights enter the rating; 5486 mm = 6 yd |
| Wind | miles per hour, whole numbers | vector `(wx, wy)`, the direction the wind blows toward |
| Time | whole seconds | |
| Rates | permille (pm), 0 to 1000 | |
| Strokes in statistics | strokes x 100 | |

A unit direction is a pair `(ux, uy)` scaled by 1024, computed by `unit(dx, dy)`: `d = isqrt(dx*dx + dy*dy)`; if `d == 0` return `(0, 1024, 0)`; else `(rdiv(dx*1024, d), rdiv(dy*1024, d), d)`. The lateral unit is `(-uy, ux)`.

## 3. Random numbers

No stateful PRNG exists in the rating path. Every random value is a pure function of its coordinates (a counter-based generator). This is what makes results independent of evaluation history and lets a small edit change only the shots it physically affects (see the seed policy in `rating-engine.md`).

```
mix32(h):  h &= 0xFFFFFFFF
           h ^= h >> 16;  h = (h * 0x85EBCA6B) & 0xFFFFFFFF
           h ^= h >> 13;  h = (h * 0xC2B2AE35) & 0xFFFFFFFF
           h ^= h >> 16;  return h

H32(x1, x2, ..., xn):
           h = 0x811C9DC5
           for each xi in order:  h = mix32(((h ^ (xi & 0xFFFFFFFF)) + 0x9E3779B9) & 0xFFFFFFFF)
           return h
```

Each 32-bit product `h * C` can exceed 2^63 in the signed 64-bit type. GDScript integer multiplication wraps, and only the low 32 bits are kept by the mask, so the result is exact. Do not convert to float at any point. Negative arguments are reduced by `& 0xFFFFFFFF` (two's complement low 32 bits).

Shot noise for a golfer uses these draws. `nid` is the golfer's index within its skill band (0 for the first golfer of each band), so golfers with the same `nid` in different bands share luck (common random numbers across bands; this cuts variance in the accuracy fit). `shot` is the 1-based number of the ball flight taken by this golfer on this hole, counting only ball flights (not penalty strokes, not putts).

| Channel | Formula | Use |
| --- | --- | --- |
| 0 | `Z[H32(seed, nid, shot, 0) & 255]` | lateral error, Z units (x1000 sd) |
| 1 | `Z[H32(seed, nid, shot, 1) & 255]` | depth error |
| 2 | `H32(seed, nid, shot, 2) % 1000` | mishit roll |
| 3 | `H32(seed, nid, shot, 3)` | mishit severity |
| 4 | `H32(seed, nid, shot, 4) % 1000` | putt roll (`shot` = number of ball flights taken plus 1) |
| 10 + i | `H32(seed, gid, shot, 10 + i) & 1023` | perception noise for candidate `i` (uses `gid`, the golfer's global index, so decision noise is independent per golfer) |

`Z` is the 256 entry table `z256` in `params.json`: `Z[i] = round_half_away(1000 * inverse_normal_cdf((i + 0.5) / 256))`, from -2886 to 2886. It was generated once offline and is now plain data. Its hash is a test vector (section 15).

## 4. Golfer roster

A rating run simulates `N = 120` golfers per hole, split into six skill bands. Golfer `gid` runs 0 to 119 in band order A to F.

| Band | Count | Skill range | Median skill | Handicap band | Population share (pm) |
| --- | --- | --- | --- | --- | --- |
| A | 10 | 860 to 1000 | 930 | 0 to 5 | 80 |
| B | 20 | 700 to 860 | 780 | 6 to 12 | 170 |
| C | 32 | 540 to 700 | 620 | 13 to 19 | 270 |
| D | 30 | 380 to 540 | 460 | 20 to 26 | 250 |
| E | 18 | 220 to 380 | 300 | 27 to 33 | 150 |
| F | 10 | 60 to 220 | 140 | 34 to 40 | 80 |

Skill of the k-th (0-based) golfer of a band with `n` golfers and range `[lo, hi]`: `lo + fdiv((hi - lo) * (2k + 1), 2n)`. Skill is therefore fixed, not sampled: the roster is a stratified quantile grid. Band counts are the population shares rounded to whole golfers of 120 (band A and F get 10 each so their means are estimable). The economy workstream uses `band_population_pm` for visitor mix, not the sample counts.

Handicap index shown to the player: `hcp_x10 = fdiv((1000 - skill) * 46, 100)`, so skill 930 shows 3.2, skill 140 shows 39.6.

Style is a fixed trait of the golfer, `r = H32(0xC0FFEE, gid) % 100`: `r < 25` aggressive (style 0), `r < 75` neutral (style 1), else cautious (style 2). It does not depend on any seed, so the same `gid` has the same style in every hole and every run.

Preview mode (editor live feedback, not official): the same construction with counts `[3, 5, 8, 8, 4, 2]` (N = 30). Preview results never feed gates, tournaments or leaderboards and are labelled as estimates.

## 5. Clubs and shot execution

Clubs (base carry in yards for skill 1000; loft factor in permille; tree intercept fraction in permille of the flight path):

| Index | Club | Base carry | Loft pm | Tree tmax pm |
| --- | --- | --- | --- | --- |
| 0 | Driver | 260 | 800 | 600 |
| 1 | 3 Wood | 235 | 820 | 550 |
| 2 | 4 Hybrid | 210 | 900 | 450 |
| 3 | 5 Iron | 190 | 1000 | 400 |
| 4 | 6 Iron | 178 | 1000 | 350 |
| 5 | 7 Iron | 166 | 1050 | 300 |
| 6 | 8 Iron | 154 | 1050 | 280 |
| 7 | 9 Iron | 142 | 1100 | 260 |
| 8 | Pitching wedge | 128 | 1150 | 240 |
| 9 | Gap wedge | 112 | 1200 | 220 |
| 10 | Sand wedge | 95 | 1200 | 200 |
| 11 | Lob wedge | 70 | 1200 | 200 |

(`params.json` holds the same values; the last column is a constant list in the model.)

Skill functions (all integer, skill 0 to 1000):

* `carry_max(club, skill, lie) = base * 100 * (600 + fdiv(skill * 400, 1000)) // 1000 * lie_carry_pm // 1000` in cy. Skill 930 driver carries 253 yd; skill 140 driver carries 170 yd.
* `spread_pm(skill) = 130 - fdiv(skill * 90, 1000)` (lateral sd as permille of distance).
* `depth_pm(skill) = 25 + fdiv((1000 - skill) * 35, 1000)`.
* `mishit_pm(skill) = 30 + fdiv((1000 - skill) * 200, 1000)`.
* `short_game_mult(distance_yd)` = `interp(short_game_mult, distance_yd)`: 3500 at 0 yd, 3000 at 20, 2000 at 60, 1400 at 120, 1000 at 200 and beyond (permille). Chips and pitches are far less precise than full shots.

Club choice: given a desired distance `D` (cy), pick the shortest club (highest index) whose `carry_max` is at least `D`; if none, index 0 (driver). The ball always travels the desired distance `Deff = min(D, carry_max(club))`; clubs matter for the distance cap, the wind loft factor and the tree intercept fraction, not for a separate distance.

One ball flight from `ball` toward `aim`, lie `lie0`, golfer skill `s`, noise `(zl, zd, mroll, msev)`:

1. `(ux, uy, D) = unit(aim - ball)`; `ci = pick_club(D, s, lie0)`; `Deff = min(D, carry_max(ci, s, lie0))`.
2. `sgm = short_game_mult(Deff // 100)`; `sl = Deff * spread_pm(s) // 1000 * lie_disp_pm // 1000 * sgm // 1000`; `sd = Deff * depth_pm(s) // 1000 * lie_disp_pm // 1000 * sgm // 1000`.
3. `dl = zl * sl // 1000`, `dd = zd * sd // 1000`.
4. Mishit if `mroll < mishit_pm(s) * lie_mishit_pm // 1000`: `Deff = Deff * (500 + msev % 300) // 1000` and `dl = dl * 2`.
5. Wind (section 10): `(wa, wl)`. `along = max(0, Deff + dd + wa) * (1000 - 40 * rain) // 1000`; `lat = dl + wl`.
6. Landing `t = ball + rdiv(u * along + p * lat, 1024)` computed per axis (`p = (-uy, ux)`).
7. Trees, hazards and drops: section 6.

## 6. Lies, hazards, trees, drops

Lie of a point (first match wins):

1. `ob` if `x < -12000` or `x > 12000` or `y < -3000` or `y > hole_length_cy + 8000` or inside an `ob` feature.
2. `water` if inside a `water` feature.
3. `green` if within `green_radius` yd of the green centre.
4. `fringe` if within `green_radius + 3` yd.
5. `bunker`, `fairway`, `deep` (feature `deep_rough`), in that order.
6. Otherwise `rough`. The first shot starts from lie `tee`.

Lie factors (permille): carry / lateral dispersion / mishit probability. `tee` and `fairway` and `fringe` 1000/1000/1000; `rough` 880/1200/1400; `deep` 650/1600/2000; `bunker` 750/1400/1800; `green` is putted.

Features are axis aligned rectangles `[x0, y0, x1, y1]` (inclusive) or circles `[cx, cy, r]` (inclusive), in yards, with types `fairway`, `deep_rough`, `bunker`, `water`, `ob`, plus `tree`, `rock`, `flower`. Rocks and flowers only count for Beauty. A tree is a circle of radius 2 yd (200 cy).

Tree interception: with `e = landing - ball`, for every tree centre `T` in the 10 yd buckets touched by the segment bounding box (expanded by 200 cy): `t_pm = clamp(dot(T - ball, e) * 1000 // dot(e, e), 0, 1000)` (0 if `e` is zero), closest point `P = ball + e * t_pm // 1000`. The tree is hit if `|T - P|^2 <= 200^2` and either `t_pm <= tmax_pm(club)` or the landing point itself is within 200 cy of `T`. The earliest hit (smallest `t_pm`) wins. The ball stops 100 cy before the hit point along the flight line (or at the ball if closer), and its lie is `deep` unless that point is `green`, `water` or `ob`. Lofted clubs clear trees late in the flight; woods do not. `treehit` is recorded.

Penalties:

* `ob`: penalty stroke, ball replayed from its previous position (stroke and distance). Lie is unchanged.
* `water`: penalty stroke. Starting at the landing point, step back along the flight line toward the ball in 200 cy steps (`landing - unit * 200 * k`, k = 1, 2, ...) until a point that is neither `water` nor `ob` is found; the ball is dropped there with that point's lie. If the walk reaches the start, replay from the start.
* A shot that ends in `ob` or `water` adds 1 to `strokes` on top of the stroke for the shot itself.

Stroke cap: `cap = par + 4`. When `strokes >= cap` the golfer picks up, `strokes = cap`, flag `pickup` is set. Putts that would exceed the cap also cap and set the flag. A hard loop limit of 40 ball flights per golfer per hole also forces pickup (protects against replay loops).

## 7. Putting

A ball on `green` at distance `d_cy` from the pin (green centre). `ft = d_cy * 3 // 100`. `base` from `putt_p1_base` (3 ft 950, 6 ft 600, 10 ft 350, 20 ft 150, 40 ft 60, farther 25; first row whose limit is at least `ft`). `p1 = base * (500 + skill // 2) // 1000`. `p3 = min(600, ft * 6 * (1100 - skill) // 1000)`. With roll `r` (channel 4): `r < p1` gives 1 putt, `r >= 1000 - p3` gives 3 putts, else 2. Each putt takes 25 s. There is no slope model in v1.

## 8. Decision rule (planner)

Every golfer chooses a target for each ball flight by comparing a fixed lattice of candidate aim points using a cost table. The table is deterministic and shared by all golfers of a band, which is what keeps the cost small.

**Candidates.** From ball position `pos` with lie `lie`, band median skill `sk`: `Dg` is the distance to the green centre, `(ux, uy)` is the unit direction to the green, `Dm = carry_max(longest club, sk, lie)`, `base = min(Dm, Dg)`, spacing `sp = clamp(Dg // 16, 300, 1000)` cy. Candidate `(fi, j)` for `fi` in 0..3 and `j` in -3..3 is the point `pos + (u * (base * F[fi] // 1000) + p * (j * sp)) / 1024` with `F = [1000, 850, 700, 550]`. That is 28 candidates. Candidate index is `fi * 7 + (j + 3)`.

**Cost table** (per band, per 4 yd cell of `pos`, per lie; the table is computed at the cell centre, `(x // 400 * 400 + 200, y // 400 * 400 + 200)`, and cached for the rating run). For each candidate, 8 fixed samples from `plan_samples` in `params.json` (lateral Z in {-1534, -887, -489, -157, 157, 489, 887, 1534} thousandths of sd, depth in {319, -1150, 1150, -319} used for each mirrored pair, so the sample set is left-right symmetric), mishit disabled (`mroll = 999`). Each sample runs the same landing, tree and penalty logic as a real shot, giving landing `(pos2, lie2, pen)`. Sample cost is `100 + ES(lie2, dist(pos2, green)) + 100 * pen` (all x100 strokes). Candidate cost is `rdiv(sum of sample costs, 8)`; `pens` is the number of samples with `pen = 1`.

**Expected strokes remaining ES** (x100): from `green`, `interp(es_green_ft, feet)`; otherwise `interp(es_fw, yards) + lie_add[lie]` with `lie_add` = tee 0, fairway 0, fringe 5, rough 20, deep 45, bunker 30. Then scaled by the golfer skill: `rdiv(v * (1350 - skill * 350 // 1000), 1000)`. Tables in `params.json` (`es_fw`, `es_green_ft`, `lie_add`). ES for lie `tee` uses the fairway curve.

**Choice.** For golfer `g` with style `st` and skill `s` at shot `k`: for each candidate `i`, `adj_i = cost_i + STYLE_W[st] * pens_i + noise_i` where `STYLE_W = [0, 8, 30]` per penalty-eighth and `noise_i = rdiv(amp * ((H32(seed, gid, k, 10 + i) & 1023) - 512), 512)` with `amp = (1000 - s) * 30 // 1000`. The golfer takes the candidate with the lowest `adj`; ties go to the lowest index. The aim actually flown is the candidate's aim recomputed from the golfer's exact position (not the cell centre).

`here` is `ES(lie, Dg)` for the golfer's band median skill (lie `tee` uses `fairway`). A candidate is **safe** when `pens <= 1` and `cost <= here + 160`.

## 9. Risk and skill

* Skill enters the plan in three ways: the band median skill changes dispersion and carry in the cost table; `noise_i` makes weak golfers misjudge (up to 0.30 strokes at skill 0, 0.02 at skill 1000); style changes the penalty weight.
* A chosen candidate with `pens >= 2` while a safe candidate exists is a **chosen risk** (flag 16). If the ball then takes a penalty the penalty is flagged 2 (chosen). If `pens >= 2` and no safe candidate exists the penalty is **forced** (flag 1). If `pens <= 1` and a penalty still happens (a mishit, a bad roll) it is **variance** (flag 32). Only forced penalties count against Fairness.
* This is what stops a good risk and reward hole being punished: bad golfers who gamble by choice, and any golfer unlucky on a safe line, never lower Fairness. Only holes where there is no safe line pay.

## 10. Wind and rain

Condition record `{wx, wy, rain}`: `wx, wy` in mph as integers (direction the wind blows toward, world axes), `rain` 0 to 3. The **reference condition** for the official rating is `{0, 0, 0}`.

For a flight with unit `(ux, uy)` and distance `D`: `wa = (wx * ux + wy * uy) // 1024` (tail positive), `wl = (wx * (-uy) + wy * ux) // 1024`. `along_shift = D * wa * 8 * loft_pm // 1000000` (8 permille of distance per mph along the line, scaled by the club loft factor), `lat_shift = D * wl * 6 * loft_pm // 1000000` (6 permille per mph across). Rain: total distance is multiplied by `(1000 - 40 * rain) / 1000`. The planner sees the same wind and rain (golfers compensate through the lattice); it does not see mishits. Weather values come from the save (a seeded weather schedule keyed by game day: `H32(save_secret, epoch, game_day, 0x57)` chooses from a table owned by the weather feature), never from a wall clock.

## 11. Pace of play inputs

Per golfer-hole time in seconds: 40 per ball flight, +30 if the shot is played from a bunker, +90 for a water penalty, +150 for an out of bounds penalty, 25 per putt, plus walking `distance_flown_cy * 6 // 1000` (about 0.6 s per yard). `time_s` is recorded per golfer. The rating engine uses the band C mean. The tee sheet and queue system (a different workstream) consumes `time_s` per hole per band as `hole_seconds[band]`; it must not re-run the sim.

## 12. Deterministic ordering

1. Holes are rated in hole index order (ascending `slot_id`, then course order).
2. Golfers run in ascending `gid`. A golfer's shots are strictly sequential.
3. Cost-table cache keys `(band, x // 400, y // 400, lie)` are only looked up, never iterated.
4. Candidates are scanned in index order, lowest adjusted cost wins, ties to lowest index.
5. Clubs are scanned from index 11 (lob wedge) to 0, first that fits.
6. Features are tested rects then circles per type. Tree lookup visits 10 yd buckets by bucket x ascending then bucket y ascending, and inside a bucket trees in ascending `(x, y)`. The smallest `t_pm` wins; on equal `t_pm` the tree visited first wins.
7. Sorting always breaks ties by index ascending.
8. Nothing depends on frame time, thread count, or platform.

## 13. Result record and hash

Per golfer record: `gid`, `strokes` (capped), `flags`, `time_s`, `first` (landing point of the first ball flight after resolution, cy; `(0,0)` if none). Flags: 1 forced penalty, 2 chosen-risk penalty, 4 pickup, 8 tree hit, 16 chose a risk, 32 variance penalty.

Sim result hash (MH-HASH64). Byte string: ASCII `engine_version` + `|` + ASCII `sim_version` + `|` + `i32le(hole_seed)` + `i32le(golfer_count)`; then for each golfer in `gid` order `i32le(gid) i32le(strokes) i32le(flags) i32le(time_s) i32le(first_x) i32le(first_y)`. `i32le(v)` is the low 32 bits of `v` little endian (negatives in two's complement). Hash: two 32-bit FNV-1a lanes over the whole byte string, lane 0 with offset basis `0x811C9DC5`, lane 1 with `0x9747B28C`, prime 16777619 both, printed as `%08x%08x` (lane 0 first). This is an integrity and equality check, not a security hash: the server compares its own re-simulation, it does not trust a client hash.

The rating result also carries: `engine_version`, `sim_version`, `hole_seed`, the six band means (x100), and the axis values.

## 14. Performance budget (measured on the reference model only)

The Python reference does about 50,000 to 62,000 ball-flight evaluations per hole (most in cost tables) and takes 0.7 to 0.8 s per hole on a desktop. GDScript on a low-end phone is likely several times slower. Budget target to be confirmed by Gate 0 measurement: official hole rating at most 250 ms and a full 18 hole course at most 5 s on the benchmark phone, time-sliced across frames (not threads). Levers if it misses: coarser cache cell (8 yd), 5 lateral columns instead of 7, cache tables across golfers (already), re-rate only changed holes (already required by the cache key in `rating-engine.md`), and preview mode with N = 30.

## 15. Test vectors (also in fixture `08_determinism_stability.json`)

| Call | Expected |
| --- | --- |
| `H32(1, 2, 3)` | see fixture 08 (`hash_vectors`) |
| `H32(0, 0, 0, 0)` | see fixture 08 |
| `H32(-1, 4294967295, 7)` | see fixture 08 (both args reduce to 0xFFFFFFFF) |
| `hash64("abc")` | see fixture 08 |
| `hash64("")` | see fixture 08 |
| hash of the 256 `Z` values as `i32le` | see fixture 08 (`z256_hash`) |
| `hole_seed(0x12345678, 1, 7)` | see fixture 08 |

The GDScript implementation must reproduce every vector and the golden sim hash byte for byte on desktop, Android and iPhone before any other rating test is meaningful.

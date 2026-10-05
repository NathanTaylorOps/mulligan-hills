# Personal golf model: envelope prototype 0.1

5 October 2026. Provisional coefficients, not locked balance. Separate from official MHSIM/MHRATE. This first reference computes carry/error envelopes, not landing geometry, flight, putting cup capture, RNG, Luck outcomes or a playable round. No runtime integration yet.

Profile has exactly seven integer attributes 0..1000: power, accuracy, touch, recovery, shaping, composure, luck. Reject bools, floats, missing/extra fields and unsupported profile versions. Return independent snapshots.

Units: centiyards for distance, permille for modifiers. Straight full-shot maximum carry = base carry * (600 + power*400//1000)//1000. For rough/deep/bunker, multiply by carry modifier `base + recovery*(1000-base)//2000` (bases 800/600/700). Bad-lie spread modifier = `base - recovery*(base-1000)//2000` (bases 1500/2200/1800). Tee/fairway/fringe modifiers 1000. Thus max Recovery halves bad-lie disadvantages; it never removes them or grants a fairway bonus.

For desired distance <=800cy, both error axes use Touch. Above it, lateral spread is `130 - accuracy*90//1000`, depth spread `60 - touch*35//1000`. Short-shot lateral/depth both use `80 - touch*60//1000`. Pressure adds `pressure*(1000-composure)//1000` to spread multiplier, with pressure restricted to 0..150; pressure cannot increase carry. Final available carry is at least 1cy to avoid a zero-distance envelope at tiny valid inputs. Error scales equal effective distance * axis spread//1000 * lie spread//1000 * pressure multiplier//1000, minimum 1cy for a nonzero shot.

Safe recovery is available only from rough/deep/bunker. It caps distance at 6000cy and reduces both error scales to 700 permille; it does not guarantee avoiding obstacles. Putting only from green: max distance 3000cy, lateral/depth rates `60-touch*50//1000` and `100-touch*80//1000`; Power/Accuracy/Recovery do not affect putt envelopes. Shaping and Luck are stored but deliberately have no envelope effect: meaningful path/outcome models are subsequent work. No fake fade/draw/punch buttons.

## Required cases written before implementation

1. Profile boundary 0/1000 values accepted; invalid scalar types rejected.
2. Missing/extra attributes/version rejected; copied snapshot cannot mutate source.
3. Power cannot reduce clear-ground carry across all 1001 values.
4. Accuracy cannot increase full-shot lateral error across all values.
5. Touch cannot increase short-shot/putting error across all values.
6. Recovery improves bad-lie carry and the lie spread multiplier but never grants a fairway bonus. At a fixed reachable target, absolute error cannot increase. When a formerly unreachable target gains carry, absolute error may grow because the shot travels farther; test the multiplier separately at overreaching distances.
7. Safe recovery reduces error and sacrifices distance, only from bad lies.
8. Composure cannot worsen pressure error; pressure cannot change carry.
9. Putt ignores Power and Accuracy; invalid lie/style/ranges rejected.
10. Preview pure/repeatable; Shaping/Luck do not silently alter this limited model.

After these pass, generate fixed numeric vectors and port envelopes to typed GDScript. Then implement versioned committed outcomes, geometry/penalties/cup capture, deterministic seeded draws, saved profile/training and exploit-resistant settlement. This reference alone does not validate game feel, campaign duration, styles or Luck.

## Committed shot prototype 0.1 (formulas before code)

`MHPERSONAL-SHOT-0.1` reuses validated official primitive geometry and integer unit/rdiv/tree interception, but does not change the official sim. Inputs: immutable hole definition, copied profile, ball coordinates/lie, target, round seed uint32, shot index1..1000000, style and bounded pressure. Tee lie is valid only at the tee; otherwise nonhazard lies must match geometry, with DEEP accepted at a tree-backoff position within 3 yards of a tree. Green requires putt. Aim/start coords limited to +/-120000cy, zero-length aim rejected. All geometry coordinate/count scalars are exact integers (integral floats and bools refused). Hole slot is integer1..18, elevation metadata int32, feature types strings and each feature has at most one primitive shape; tree rectangles require count and tree circles are refused. Bad/finished round management is outside this single-shot API.

Automatic club: search shortest-to-longest existing base carries, choosing first whose personal envelope can reach target, otherwise longest. Safe-recovery reach remains capped60yd. Putt has no club index (-1). Use existing PCG32 reference seeded with round_seed, stream `shot_index*8+channel`: channel0 lateral,1 depth; Gaussian Q16 noise scales envelope errors using floor division by65536. Fresh stream per committed shot/channel makes previews independent of draws and reload reproducible. No wind, rain, roll, mishit, curved styles or Luck breaks in this first outcome version.

Along distance = max(0, effective+depth error), lateral = lateral error; convert to integer destination with established 1024-unit direction/rdiv. Straight uses existing club tree-height cutoff. Safe recovery uses cutoff1000 (entire route checked). Putt is a sampled ground path at intervals <=25cy. Every ground segment checks exact inclusive rectangle/circle hazard intersection with integer arithmetic, including zero-width strips, so sampling cannot jump water/OB. Cup capture for putts only when a sample comes within15cy of cup and total travel <= remaining distance to closest cup sample +100cy (prototype slow finish). Airborne shots never capture the cup by crossing it. Trees use official conservative straight-path intersection; no final terrain-height trajectory claim.

Water/OB from either style uses a clearly labelled prototype stroke-and-distance reset: original ball/lie, penalty1, penalty_kind water1/OB2. Unlike official AI water backtracking, this deliberately simple personal rule is separately versioned and reported. Tree impact backs off <=100cy; nonhazard/nongreen landing becomes DEEP. Each outcome reports destination, lie, club, penalty/kind, tree flag, holed and committed index. Round stroke counting, pickup, storage and reward settlement remain outside this step.

Required cases before code: (1) fixed seeded straight result; (2) same seed/index/profile gives same result after intervening preview; (3) advancing index changes seeded errors; (4) water landing resets and adds one penalty; (5) OB landing same; (6) tree hit stops and backs off; (7) green putt can hole with slow cup approach; (8) fast pass over cup does not hole; (9) putting cannot cross a water/OB strip to reach a safe endpoint; (10) airborne overflight of cup cannot hole; (11) strict scalar/style/lie/geometry inputs reject without mutation; (12) envelope and copied inputs remain unchanged. Numeric golden cases must be retained for later typed-port parity.

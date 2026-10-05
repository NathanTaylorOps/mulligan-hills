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

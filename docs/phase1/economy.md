# Phase 1: Economy (`game/core/economy/`)

Status: code and simulation written, Python simulation RUN, GDScript and gdUnit4 tests **NOT YET RUN** (Godot cannot run in the sandbox; CI validates).
Owner paths: `game/core/economy/`, `game/tests/economy/`, `tools/reference/economy/`, `docs/phase1/economy.md`, plus the runtime copy `game/data/economy_params.json`.

## README block

**Purpose.** Cash, green fees, hourly income, upkeep, payback-targeted prices (DEC-050), bankruptcy detection, the free bank loan with a reputation penalty, and the token-gated recovery and speed hooks (DEC-052, DEC-053). Integer cents only. No floats, no RNG, no store code.

**Public API.**
- `MHEconomyParams.load_default()` reads `res://data/economy_params.json` (constants, per-building effects, the added-income and price tables). `is_loaded()`, `error()`, `c("key")`.
- `MHEconomyModel` (all `static`, pure): `wtp_cents`, `acceptance_permille`, `attract_permille`, `arrivals_milli`, `split_hour`, `day_estimate`, `suggest_fee_cents`, `payback_price`, `parcel_cost_cents`, `hole_cost_cents`, `members_target_milli`, `speed_tokens_for_days`.
- `MHEconomy` (state): `create_from_defs(params, defs)`, `tick_hour()`, `spend`, `earn`, `can_afford`, `set_green_fee`, `suggest_fee`, `set_course(holes, rating, parcels)`, `set_tier`, `set_demand_modifier`, `price_cents`, `purchase_tier`, `daily_upkeep`, `estimate_day`, `is_bankrupt`, `recovery_options(tokens)`, `take_bank_loan`, `recover_with_tokens(ledger)`, `apply_token_recovery`, `can_afford_speed(ledger, days)`, `to_dict` / `from_dict`, signal `cash_changed`.
- Money is cents. Prices and upkeep in `buildings.json` are whole dollars, so `price_cents = dollars * 100`.

**Clock contract.** Call `tick_hour()` once per `MHGameClock.EV_HOUR` event. A day is 11 hours (the clock's 660 minutes), 15 real minutes at 1x. The earlier attempt assumed 12 hours; that was wrong and is fixed. A test asserts `MHEconomy.HOURS_PER_DAY == MHGameClock.HOURS_PER_DAY`.

**How tests run.** gdUnit4 headless, `game/tests/economy/test_economy_model.gd` and `test_economy_state.gd`. Golden vectors: `game/tests/economy/golden/economy_golden.json`, produced by the Python reference. Regenerate everything:

```
cd tools/reference/economy
python3 selftest.py          # python reference checks
python3 sim.py all 30        # full balance report (about 1 minute); saved copy: sim_report.txt
python3 gen_golden.py        # rewrites economy_params.json, game/data/economy_params.json and the golden file
```

**Gate 0 / Phase 1 items addressed.** Economy tuning (DEC-049, DEC-050, DEC-051, DEC-052 income per game hour), bankruptcy rule (open question Q8, option "free loan"), DEC-053 hooks as pure logic.

## What was built

| Path | What |
| --- | --- |
| `tools/reference/economy/mh_economy.py` | Integer reference of the model and state machine. The simulation drives this exact code. |
| `tools/reference/economy/sim.py` | Player-behaviour simulation, calibration, report. Float and random are used only for player behaviour. |
| `tools/reference/economy/make_params.py` | The base constants and calibration targets (edit numbers here). |
| `tools/reference/economy/economy_params.json` | Tuned constants plus derived tables (generated). |
| `tools/reference/economy/gen_golden.py`, `selftest.py`, `sim_report.txt` | Golden generator, self checks, saved report. |
| `game/core/economy/mh_economy_params.gd`, `mh_economy_model.gd`, `mh_economy.gd` | The GDScript core. |
| `game/data/economy_params.json` | Runtime copy of the tuned constants (generated). |
| `game/tests/economy/` | Two test suites and the golden file. |

The earlier cut-off attempt (12-hour day, float-free core but invented per-tier percentages, scratch scripts) was inspected. Kept: the hourly tick with arrears, bankruptcy, loan and token recovery structure, the acceptance curve `1 / (1 + (fee/wtp)^2)`, exact hourly splitting. Replaced: day length, the multiplicative demand effects (they made the added-income table depend on course size), the `upkeep_ppm` formula (buildings now use the `upkeep_per_day` already in `buildings.json`), and all scratch scripts.

## The model in plain words

- **Golfers.** Arrivals per day = base + per-hole term (grows with `(rating/50)^1.5`) + extra golfers from buildings, times reputation and an events modifier. Each arrival accepts the fee with probability `1000 / (1 + (fee/wtp)^2)`, where wtp (willingness to pay) = holes x (10 + 5 x rating) cents. At fee = wtp, half accept. Capacity is a per-hour tee cap: 5 groups per hour x 3 golfers (DEC-052 12-minute interval) = 15 per hour, 165 per day. Fractions are carried hour to hour, so nothing is lost to rounding.
- **Income per hour.** Green fees, ancillary spend per golfer (Pro shop, Range, Restaurant, Cart barn), flat income (Pool and spa, Lodging, Homes, Landmark, scaled by rating/50), member dues ($3 per member per day).
- **Upkeep per hour.** Buildings: `upkeep_per_day` of the standing tier from `buildings.json`, read as the TOTAL for that tier (not an increment). Course: $30 per hole and $12 per parcel per day, cut by up to 60% by Maintenance. Unpaid upkeep becomes arrears; bankrupt at 2.0 days of arrears (and at least $1,000).
- **Fee.** `$5` to `$250`. The ancillary spend makes the revenue-best fee low early (about $6 with all tier 1 buildings) and high late ($56 at tier 5). `suggest_fee()` returns the revenue-maximising fee.
- **Prices (DEC-050).** `price = target payback days x net added daily income`. "Net added daily income" is the extra income a tier brings, minus the tier's own extra upkeep, at a reference course for that tier (gate holes and rating, every other building one tier lower, best fee). Targets 6/8/10/12/15 are unchanged (all 50 entries in `buildings.json` already carry them).
- **Bankruptcy.** Free bank loan: no interest, 10 days of upkeep plus arrears (clamped $5,000 to $50,000), repaid from 25% of each hour's revenue, reputation 15 points lower (demand multiplier 1000 to 850, recovers 0.3 points per day, so about 50 days), at most 3 loans. Token recovery: 3 tokens debited from `MHTokenLedger`, arrears cleared, upkeep suspended 5 days, no cash granted.
- **Speed hook.** The clock drains 1, 2, 4 tokens per real minute at 2x, 4x, 8x, so every sped-up game day costs 7.5 tokens at any speed. `speed_tokens_for_days` mirrors that for UI and tests; the clock still does the draining.

## Added daily income per tier (for the buildings agent)

This is the table `buildings.json` lacks. It is in `economy_params.json` as `added_daily_income_dollars` and `price_dollars`, and `MHBuildingDefs.price_for(id, tier, added)` reproduces the price exactly (a test checks every entry). Whole dollars per game day, net of the tier's own upkeep.

| Building | T1 | T2 | T3 | T4 | T5 |
| --- | --- | --- | --- | --- | --- |
| clubhouse | 56 | 75 | 114 | 63 | 79 |
| pro_shop | 45 | 61 | 91 | 51 | 41 |
| driving_range | 39 | 68 | 111 | 131 | 130 |
| restaurant | 52 | 68 | 103 | 65 | 46 |
| pool_spa | 45 | 73 | 117 | 118 | 109 |
| cart_barn | 20 | 29 | 45 | 50 | 39 |
| maintenance | 20 | 32 | 53 | 20 | 20 |
| lodging | 51 | 68 | 102 | 56 | 45 |
| homes | 56 | 75 | 113 | 63 | 50 |
| landmark | 68 | 91 | 136 | 112 | 144 |

Resulting prices in dollars (target days x added): tier 1 about $120 to $410, tier 2 $230 to $730, tier 3 $450 to $1,360, tier 4 $240 to $1,570, tier 5 $300 to $2,160. All 50 building steps together cost **$36,975**. A floor of $20 per day applies to the added income (Cart barn and Maintenance would otherwise price near zero).

Notes for the buildings agent:
1. Do not hard-code prices. Read `target_payback_days` from `buildings.json` and the table above, or call `MHEconomy.price_cents(building_index, tier, target_days)`.
2. `upkeep_per_day` is treated as the total upkeep of the standing tier. If you meant an increment, tell the economy owner.
3. If anyone edits `upkeep_per_day`, gates, parcels or targets in `buildings.json`, re-run `python3 tools/reference/economy/gen_golden.py`. The golden estimate tests will fail until that is done, which is intentional.
4. Building order in `economy_params.json` (`building_ids`) equals the order in `buildings.json`; a test checks it.

## Headline balance findings

Method: 30 simulated players per cell, 720 game days (= 180 real hours = 3 hours a day for 2 months at 1x), 4 skill cohorts (low, mid, high, expert; weights 25/40/25/10) and 6 habit types. The skill model is the weakest assumption: rating grows toward a personal ceiling (46, 56, 66, 78) with a half-life of 60 to 130 game days. Full output: `tools/reference/economy/sim_report.txt`.

**1. Progress is gated by course rating, not by cash, from tier 4 on.** Median day that all ten buildings reach each tier (real play hours = day / 4):

| Cohort | T3 | T4 | T5 |
| --- | --- | --- | --- |
| low (ceiling 46) | day 161 (40 h) | never | never |
| mid (56) | day 101 (25 h) | day 241 (60 h) | never |
| high (66) | day 93 (23 h) | day 169 (42 h) | day 293 (73 h) |
| expert (78) | day 87 (22 h) | day 153 (38 h) | day 243 (61 h) |

T2 for every building is done by day 30 (the wait is the first Homes parcel). The mid-skill T4 day and the high-skill T5 day did not move in any sensitivity run (start cash, parcel prices; those runs used 10 players per cell, so medians differ by a few days from the main table), which shows they are set by the rating gates (52 and 62). Only the high-skill T4 day moves, and only with cheaper land. If rating growth is slower than assumed, they move later; if players design better than assumed, earlier. With the assumed skill mix, **about 65% of players can never buy tier 5 and about 25% never buy tier 4.**

**2. Money piles up after the last reachable tier, massively.** Median cash at day 720: mid $3.4M, high $4.5M, expert $6.1M, with net income of $7.7k to $13k per game day and nothing left to buy. A mid player has nothing to spend on after about day 240, which is a third of the 2-month window. "Pile days" (nothing bought while holding more than 30 days of gross income) are about 400 of 720 for every cohort. This is the biggest balance problem and it needs a cash sink (see questions).

**3. Cash starves in the early middle.** The 40,000 dollar start cash is gone by about day 5 (median) after buying all tier 1 and 2 buildings ($7,800 in total) and a few holes. Days 30 to 100 then yield only 4 to 13 purchases (about 20 purchases happen in the first 30 days). The reason is land: tier 3 needs 3 more parcels ($99,750) plus 4 holes ($45,000), which at about $2k net per day takes about 70 days. The parcel schedule in `buildings.json` ($25,000 growing 30% per parcel, $1.41M for all 11 purchases) is back-loaded: tier 5 needs about $1.07M of land.

**4. Land is almost the entire cost of the game.** Buildings total $37k (payback pricing makes them cheap), holes about $190k for 12, parcels $1.41M. Payback pricing therefore does not create a spending curve by itself; the parcel schedule does.

**5. Tiers 4 and 5 are thin earners.** Their upkeep (T5 total $7,980 per day for all ten) eats most of their gross, so net added income at tiers 4 and 5 is $20 to $144 per building per day and prices are small. They work as gates and prestige, not as investments. I chose this shape because cash is not the constraint there (finding 1); raising it only adds to the pile (finding 2).

**6. Bankruptcy is rare.** 0 of 30 for careful, casual, sticky, greedy-spender and cheap-fee players over 720 days. 3 of 30 for a player who sets the $250 maximum fee and keeps it (each recovered with one loan, no tokens). A 30-day demand collapse to 25% never bankrupts anyone; a total shutdown (0% demand) for 30 or 60 days bankrupts at most 1 of 20 zero-reserve spenders. The loan and token paths are a seldom-used safety net.

**7. Time-skips are worth real money late.** One sped-up game day costs 7.5 tokens at any speed and is worth the day's net: about $270 per token at the tier 2 stage, $560 at tier 3, $990 at tier 4, $1,440 at tier 5. Tokens never buy cash directly, but a skipped day is cash. Given finding 2, late skipping buys nothing the player can use; early skipping is where the leverage is.

**8. Revenue-best fee is low early.** At tier 1 the best fee is about $6 (ancillary spend dominates), at tier 3 $16, at tier 5 $56. The tee cap (165 golfers per day) is reached only by the strongest courses (about 145 per day at tier 5), so there is no real "pace and queue" cost yet. The review's concern (the revenue-best fee is the floor) is half true early, not late.

**9. Demo cut.** Nine holes, Clubhouse tier 2, Pro shop tier 2, Range tier 2, Restaurant tier 1: the last demo purchase lands at day 90 to 109 (22 to 27 real hours), then $850 to $1,500 per day piles up. The demo wall is a long way in, with cash accumulating silently against it.

**10. First purchase.** The player can buy on the first minute (cash is 5 times what tier 1 and 2 cost). The requirement "first purchase within about 5 minutes" is met trivially; start cash is not the binding constraint, parcels are. Sensitivity: start cash $10k delays tier 3 by about 20 days (mid), $80k advances it by about 22 days.

Sensitivity of tier timing to the parcel schedule (median day, mid / high): file schedule T3 101 / 93, T4 232 / 170; 25,000 x 115% T3 87 / 81, T4 232 / 132; 12,500 x 115% T3 70 / 52, T4 232 / 126. A flatter schedule fixes the dry spell without touching the late game.

## Assumptions (all invented, all in `make_params.py`)

- Skill model: rating ceilings 46/56/66/78, half-life 60 to 130 game days, rating grows with game days (not with play actions). Cohort weights 25/40/25/10.
- Golfer demand: base 44 golfers, plus 2.0 per hole x `(rating/50)^1.5`; willingness to pay `holes x (10 + 5 x rating)` cents; acceptance curve `1/(1+(fee/wtp)^2)`; hourly demand profile 6,8,9,10,10,9,9,10,10,9,6 (relative); group size 3; 5 tee groups per hour.
- Building effects: the per-tier effects (extra golfers, ancillary cents, flat income, upkeep cut) are the RESULT of calibrating each building to a net-income target per tier (`tier_total_net_dollars` 450/600/900/500/400 split by weights 10/8/7/9/8/3/3/9/10/12). The targets, not the effect numbers, are the design intent.
- Holes cost $10,000 growing 8% per hole; upkeep $30 per hole and $12 per parcel per day; Maintenance cuts that by up to 60%.
- Members: caps 40/80/140/220/320 by Clubhouse tier, scaled by `(rating - 28) / 30`, moving 3% of the gap per day; dues $3 per day.
- Tournaments: local needs 14 holes, rating 52, Clubhouse 3, costs $25,000, takes 5 days; regional needs 18 holes, rating 62, Clubhouse 4, costs $60,000. (The tournament spec is not written; these only affect when the bot unlocks tier 5.)
- Parcel bundles: a bot buying a tier also buys any parcels the tier's `min_parcels_owned` requires, golf parcels first.
- Players act once per game day, up to 4 purchases, ranked by income gained per cost (careful, casual, sticky, cheap) or by price (greedy spender).
- Tokens: a simulated player holds 12 tokens at the start and earns 2 per week.
- Demand shock hook: `set_demand_modifier(permille)` is the only input the events agent needs; it scales arrivals, not flat income or ancillary rules.

## Interface differences from `docs/spec/interfaces/economy.md`

- Integer **cents** instead of integer dollars (hourly income at game scale is a few dollars).
- No `settle_day`, `MHDayLedger`, `MHClubState`, `MHResult`: the hourly tick returns a dictionary, errors are int codes (`OK`, `ERR_INSUFFICIENT`, `ERR_INVALID`, `ERR_BANKRUPT`, `ERR_NOT_AVAILABLE`). A daily ledger is the sum of 11 tick results; a test checks the arithmetic.
- `mode()` (Relaxed, Standard, Tycoon, Sandbox) is not implemented: nobody has defined what a mode changes. See questions.
- `buy_parcel` is not in the economy: `MHLandModel.buy` returns the price and the caller spends it (`spend(price_cents)`); the economy mirrors the price rule (test checks they agree).
- Remote config clamping is not implemented (no remote config reader exists yet). Everything is read from one params file.

## How it is tested (NOT YET RUN in Godot)

- `test_economy_model.gd`: params load and reject garbage, building order equals `buildings.json`, hours per day equals the clock, golden vectors for wtp, acceptance, attraction, arrivals, hourly split (sums exactly), members, parcel cost (equals `MHLandModel`), hole cost, payback price, speed tokens, course upkeep, six full day estimates and fee suggestions, every one of the 50 prices against `MHBuildingDefs.price_for`.
- `test_economy_state.gd`: start state, spend and earn rules, no negative cash, fee clamps, suggested fee beats the extremes, day roll, ledger arithmetic (cash change equals revenue minus upkeep paid), upkeep paid exactly over a day, golden 3-day trace (33 hourly states), golden collapse to bankruptcy then free loan then recovery, token recovery through a real `MHTokenLedger` (refused with too few tokens, grants no cash), speed hook, `purchase_tier`, save round trip through JSON and bad-input rejection, deterministic replay.
- Python: `selftest.py` (RUN, passes) and the simulation (RUN).

## Unverified (GDScript, check on first CI run)

- Parse of every file; typed loop variables over packed arrays (`for v: int in hour_profile`), `for _i: int in range(...)`, `Object.set()` used in `MHEconomy.from_dict`, `PackedInt32Array.duplicate()`, `Array(PackedInt64Array)` in the tests.
- That `JSON.parse_string` hands back integral floats that `int()` reads exactly (they are far below 2^53).
- That `MHFixed.isqrt` is the exact floor square root for the `attract_permille` vectors (Python uses its own exact Newton version; both are exact floors).
- Integer-division warnings: all division goes through `MHEconomyModel.idiv`, which carries the `integer_division` ignore. If CI treats other warnings as errors, report them.
- Python and GDScript parity is by hand-mirroring plus golden vectors; a divergence would show as a golden failure, not silently.

## Risks and follow-ups

- The whole income model is invented. It is calibrated to a design intent, not measured. Closed-test data (session length, retention, how fast players really improve rating) will move everything; rerun `sim.py` and `gen_golden.py`.
- The skill and rating-growth model decides finding 1. If rating improves with real play time rather than game days, time-skips would not accelerate it.
- Cash piles up after the last reachable tier (finding 2). No sink exists in the spec beyond tournaments and renovation, which have no numbers.
- `upkeep_per_day` is a placeholder and dominates tier 4 and 5 economics; changing it changes prices.
- The loan is "free" (no interest) per DEC-053 wording. A repeat bankrupt player gets up to 3 loans and then only the token path. Needs product confirmation.
- No difficulty modes, no tournament income, no wages, no member churn events; all are hooks for later.
- Save format: `MHEconomy.to_dict()` carries `v = 1`; the save module must include it and call `from_dict`.

## Questions for Nathan

1. **What should the typical 2-month player have achieved by day 720?** Today a mid-skill player finishes all they can reach (tier 4) by about day 240 and a high-skill player finishes tier 5 by day 290. Do you want the content to last the full 2 months (then the rating gates and costs must be pushed out roughly 2 to 3 times), or are you happy to have a "done" point and then cash sits idle?
2. **Is it acceptable that most players never reach tier 5?** With the 62 average-hole-score gate, about 65% of simulated players cannot. Options: keep it as an aspirational goal, lower the tier 5 gate to about 58, or add something to buy that does not need a high score.
3. **What should late-game cash be spent on?** Candidates: course renovation and hole redesign fees, tournaments, staff wages, upgrading Homes (the replace-an-old-home mechanic), a cosmetic or prestige sink. None has numbers yet. A sink worth $5,000 to $10,000 per game day would absorb the late income.
4. **Land prices.** Do you want the parcel schedule flatter ($25,000 growing 15% instead of 30%)? It removes the 70-day dry spell before tier 3 and moves tier 4 for high-skill players 40 days earlier, and the total land bill drops from $1.41M to about $0.6M. This is a decision for `buildings.json`, not the economy.
5. **Start cash.** $40,000 is about 5 times what the first two tiers cost, so it is not the constraint. $20,000 delays tier 3 by about 10 days. Keep $40,000?
6. **Bankruptcy loan.** Confirm the shape: no interest, repaid from a quarter of income, 15% demand penalty that fades over about 50 days, at most 3 loans. And confirm 3 tokens is the right price for the token recovery.
7. **Time-skips.** A sped-up game day costs 7.5 tokens at every speed, and early in the game a token is worth about $270 of income, late $1,440. Is that the intended exchange rate, and should speed-ups be blocked while the club is bankrupt or after the last reachable tier?
8. **Difficulty modes (Relaxed, Standard, Tycoon, Sandbox).** What should each change? A simple option is a multiplier on upkeep and on demand; say which you want and I will add it as one parameter.
9. **Does the course feel alive?** Early the course sees about 25 golfers per day (1 to 3 per hour), 90 with all tier 1 buildings, 145 at the top; capacity is 165. If early courses should look busier, lower the fee optimum or raise base arrivals.

## For Nathan

Nothing to run or install. Decisions are in the questions above; the most valuable are 1, 3 and 4.

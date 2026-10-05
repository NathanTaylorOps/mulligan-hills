# Phase 1: Economy (`game/core/economy/`)

Status: DEC-070/071 now use a 25-minute day and about 50 running hours. Full Python simulation median 49.6 hours; see `economy_audit.md` for assumptions and verification limits. Prices remain DEC-069. Earlier balance analysis below is historical: its old hours target and tier-4 renovation statements are superseded. Godot changes await CI.
Owner paths: `game/core/economy/`, `game/tests/economy/`, `tools/reference/economy/`, `docs/phase1/economy.md`, plus the runtime copy `game/data/economy_params.json`.

## README block

**Purpose.** Cash, green fees, hourly income, upkeep, payback-targeted prices (DEC-050), bankruptcy detection, the free bank loan with a reputation penalty, and the token-gated recovery and speed hooks (DEC-052, DEC-053). Integer cents only. No floats, no RNG, no store code.

**Public API.**
- `MHEconomyParams.load_default()` reads `res://data/economy_params.json` (constants, per-building effects, the added-income and price tables). `is_loaded()`, `error()`, `c("key")`.
- `MHEconomyModel` (all `static`, pure): `wtp_cents`, `acceptance_permille`, `attract_permille`, `arrivals_milli`, `split_hour`, `day_estimate`, `suggest_fee_cents`, `payback_price`, `parcel_cost_cents`, `hole_cost_cents`, `members_target_milli`, `speed_tokens_for_days`, `renovation_cost_cents`, `renovation_dem_milli`, `renovation_upkeep_cents`.
- `MHEconomy` (state): `create_from_defs(params, defs)`, `tick_hour()`, `spend`, `earn`, `can_afford`, `set_green_fee`, `suggest_fee`, `set_course(holes, rating, parcels)`, `set_tier`, `set_demand_modifier`, `price_cents`, `purchase_tier`, `renovation_available`, `renovation_cost`, `purchase_renovation`, `daily_upkeep`, `estimate_day`, `is_bankrupt`, `recovery_options(tokens)`, `take_bank_loan`, `recover_with_tokens(ledger)`, `apply_token_recovery`, `can_afford_speed(ledger, days)`, `to_dict` / `from_dict`, signal `cash_changed`.
- Money is cents. Prices and upkeep in `buildings.json` are whole dollars, so `price_cents = dollars * 100`.

**Clock contract.** Call `tick_hour()` once per `MHGameClock.EV_HOUR` event. A day is 11 hours (the clock's 660 minutes), 15 real minutes at 1x. The earlier attempt assumed 12 hours; that was wrong and is fixed. A test asserts `MHEconomy.HOURS_PER_DAY == MHGameClock.HOURS_PER_DAY`.

**How tests run.** gdUnit4 headless, `game/tests/economy/test_economy_model.gd` and `test_economy_state.gd`. Golden vectors: `game/tests/economy/golden/economy_golden.json`, produced by the Python reference. Regenerate everything:

```
cd tools/reference/economy
python3 sim.py write --base     # make_params.py -> economy_params.json (calibrates the effects)
python3 gen_golden.py           # rewrites game/data/economy_params.json and the golden file
python3 selftest.py             # python reference checks
python3 sim.py all 60 > sim_report.txt   # full balance report (about 10 minutes on 2 cores)
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
- **Upkeep per hour.** Buildings: `upkeep_per_day` of the standing tier from `buildings.json`, read as the TOTAL for that tier (not an increment). Course: $60 per hole and $25 per parcel per day, cut by up to 60% by Maintenance. Unpaid upkeep becomes arrears; bankrupt at 2.0 days of arrears (and at least $1,000).
- **Fee.** `$5` to `$250`. The ancillary spend makes the revenue-best fee low early (about $6 with all tier 1 buildings) and high late ($56 at tier 5). `suggest_fee()` returns the revenue-maximising fee.
- **Prices (DEC-050).** `price = target payback days x net added daily income`. "Net added daily income" is the extra income a tier brings, minus the tier's own extra upkeep, at a reference course for that tier (gate holes and rating, every other building one tier lower, best fee). Targets are now 10/12/16/50/80 days for tiers 1 to 5 (all 50 entries in `buildings.json`). Tiers 4 and 5 are calibrated to a larger net income (`tier_total_net_dollars` 3,500 and 6,000 across the ten buildings), so they are real, expensive investments.
- **Bankruptcy.** Free bank loan: no interest, 10 days of upkeep plus arrears (clamped $5,000 to $50,000), repaid from 25% of each hour's revenue, reputation 15 points lower (demand multiplier 1000 to 850, recovers 0.3 points per day, so about 50 days), at most 3 loans. Token recovery: 3 tokens debited from `MHTokenLedger`, arrears cleared, upkeep suspended 5 days, no cash granted.
- **Renovation (the late-game sink, DEC-069).** Once the course has 18 holes and every building is at tier 4 or higher, the player can buy repeatable renovation levels (max 12). Level n costs $150,000 x 1.3^n, adds +8% arrivals per level and adds $200 per day of upkeep per level. Cash goes in, demand and income come out, so it is a sink that still feels like progress.
- **Tournaments.** Hosting costs $25,000 (local) or $60,000 (regional); success pays sponsor reward plus entry fees plus ticket sales (DEC-065). Revenue is computed in `MHTournamentSim`, not in the economy tick.
- **Speed hook.** The clock drains 1, 2, 4 tokens per real minute at 2x, 4x, 8x, so every sped-up game day costs 7.5 tokens at any speed. `speed_tokens_for_days` mirrors that for UI and tests; the clock still does the draining.

## Added daily income per tier (for the buildings agent)

This is the table `buildings.json` lacks. It is in `economy_params.json` as `added_daily_income_dollars` and `price_dollars`, and `MHBuildingDefs.price_for(id, tier, added)` reproduces the price exactly (a test checks every entry). Whole dollars per game day, net of the tier's own upkeep.

| Building | T1 | T2 | T3 | T4 | T5 |
| --- | --- | --- | --- | --- | --- |
| clubhouse | 56 | 75 | 113 | 443 | 759 |
| pro_shop | 45 | 61 | 91 | 355 | 607 |
| driving_range | 39 | 68 | 110 | 310 | 582 |
| restaurant | 52 | 68 | 103 | 400 | 683 |
| pool_spa | 45 | 73 | 117 | 354 | 607 |
| cart_barn | 20 | 29 | 45 | 133 | 227 |
| maintenance | 20 | 32 | 53 | 133 | 227 |
| lodging | 51 | 68 | 102 | 398 | 683 |
| homes | 56 | 75 | 113 | 443 | 759 |
| landmark | 68 | 91 | 136 | 531 | 911 |

Prices (target days x added): tier 1 $200 to $680, tier 2 $348 to $1,092, tier 3 $720 to $2,176, tier 4 $6,650 to $26,550, tier 5 $18,160 to $72,880. Totals per tier across the ten buildings: $4,520, $7,680, $15,728, $175,000, $483,600. All 50 steps together cost **$686,528**. A floor of $20 per day applies to the added income.

Notes for the buildings agent:
1. Do not hard-code prices. Read `target_payback_days` from `buildings.json` and the table above, or call `MHEconomy.price_cents(building_index, tier, target_days)`.
2. `upkeep_per_day` is treated as the total upkeep of the standing tier. If you meant an increment, tell the economy owner.
3. If anyone edits `upkeep_per_day`, gates, parcels or targets in `buildings.json`, re-run `python3 sim.py write --base` and `python3 tools/reference/economy/gen_golden.py`. The golden estimate tests will fail until that is done, which is intentional.
4. Building order in `economy_params.json` (`building_ids`) equals the order in `buildings.json`; a test checks it.

## Headline balance findings (after DEC-069)

Method: 60 simulated players per skill profile (15 per habit cell), 400 game days, four skill profiles (novice, casual, competent, expert; weights 15/45/30/10) and six habit types. Real hours use an assumed speed mix of 60% of days at 1x, 25% at 2x, 15% at 4x, which is 12.1 real minutes per game day. The skill model is still the weakest assumption: rating moves from 34 toward a personal ceiling (58, 68, 76, 84) with a half-life of 12 to 50 game days. Full output: `tools/reference/economy/sim_report.txt`.

**1. Targets met for casual-but-competent players.** Median day that all ten buildings are at tier 5 and the course has 18 holes:

| Profile | T3 | T4 | T5 (p10 / p50 / p90) |
| --- | --- | --- | --- |
| novice (ceiling 58) | 32 | 104 | never (0 of 60) |
| casual (68) | 29 | 78 | 120 / 126 / 136 |
| competent (76) | 26 | 68 | 105 / 109 / 114 |
| expert (84) | 23 | 59 | 91 / 94 / 100 |

Weighted by habit (casual, careful, sticky, greedy, cheap): **casual-but-competent players (non-novice) finishing in days 100 to 150: 84.7%; by day 150: 92.6%; before day 100: 7.9%; by day 400: 100%.** Finishers (all players) p10/p50/p90: day 94/119/153, which is 19/24/31 hours at the assumed speed mix, or 23.5/29.8/38 hours if every day ran at 1x. Including novices, 72% finish in range and 85% ever finish.

**2. T4 and T5 are now cash-gated.** With unlimited cash the same bot reaches T4/T5 on day 39/103 (casual), 23/60 (competent), 19/42 (expert). The actual days are 78/126, 68/109 and 59/94, so cash decides the pace. Exception: novices, whose rating ceiling of 58 cannot meet the tier 5 gate of 62.

**3. Late-game cash sink works.** Day-400 median cash is $0.74M (casual), $0.36M (competent) and $1.3M (expert), against $3.4M to $6.1M before. The bot reaches renovation level 8 to 9 of 12 and spends $4M to $5.4M on it. Late net income is $17k to $23k per day. Cash still builds slowly after day 150 for competent and expert players, which is acceptable; the sink is deep but not infinite.

**4. Early cash no longer starves.** Start cash is $50,000. The bot still spends nearly all of it by about day 5 (that is what the money is for), but it can buy on 10 days between days 6 and 30 (was 2), makes 34 purchases by day 30 (was 21), and the longest wait between purchases is roughly halved. Land is $8,000 growing 15% per parcel ($195k for all of it); 12 holes cost $107k ($5,000 growing 10%).

**5. Land schedule sensitivity (casual T5 day).** $8,000 x 115% (chosen): 126. $8,000 x 130%: 147. $12,000 x 115%: 140. The old $25,000 x 130%: 285.

**6. Start cash sensitivity (casual T5 day).** $20k: 137, $30k: 135, $50k: 126, $80k: 118.

**7. Habits.** Sticky (never changes the fee) T5 day about 149; cheap-fee about 181; gouger (maximum fee forever) about 374 and only 22 of 30 finish. Careful, casual and greedy-spender players finish at 124 to 128. A fee advisor in the UI would pull the slow habits in.

**8. Bankruptcy is rare.** 0 bankruptcies in every habit cell and in every stress shock (30-day demand collapse to 25%, total shutdown for 30 or 60 days).

**9. Time-skips.** A sped-up game day costs 7.5 tokens at any speed. Value of a token: $227 (T2 stage), $497 (T3), $1,263 (T4), $2,387 (T5). With earned-only tokens (DEC-064: 2 per daily login, 3 per challenge, 1 per achievement) the player cannot afford many skipped days, so the 12.1 minutes per day assumption is optimistic. At pure 1x the median finisher needs about 30 hours.

**10. Demo cut.** Nine holes, Clubhouse 2, Pro shop 2, Range 2, Restaurant 1. With the $50,000 start cash all seven demo steps are bought on day 2 (0.4 hours). A demo-specific start cash of $25,000 puts the wall at about 8.9 hours (casual), $15,000 at about 12 hours. No such parameter exists yet.

**11. Old parameters on the new bot.** Casual T5 day about 216 and expert 164 with the old prices and skill model; the previous report found about 65% of players never reached T5 because of the slow skill model.

## Assumptions (all invented, all in `make_params.py`)

- Skill model: start rating 34, ceilings 58/68/76/84 (novice, casual, competent, expert), half-life 30 to 50, 24 to 42, 18 to 32 and 12 to 24 game days, rating grows with game days (not with play actions). Weights 15/45/30/10. Habit weights: casual 35%, careful 20%, sticky 20%, greedy 20%, cheap 5%. Speed mix 60% 1x, 25% 2x, 15% 4x (12.1 real minutes per game day).
- Golfer demand: base 44 golfers, plus 2.0 per hole x `(rating/50)^1.5`; willingness to pay `holes x (10 + 5 x rating)` cents; acceptance curve `1/(1+(fee/wtp)^2)`; hourly demand profile 6,8,9,10,10,9,9,10,10,9,6 (relative); group size 3; 5 tee groups per hour.
- Building effects: the per-tier effects (extra golfers, ancillary cents, flat income, upkeep cut) are the RESULT of calibrating each building to a net-income target per tier (`tier_total_net_dollars` 450/600/900/3500/6000 split by weights 10/8/7/9/8/3/3/9/10/12). The targets, not the effect numbers, are the design intent.
- Holes cost $5,000 growing 10% per hole; start cash $50,000; members join at 6% of the gap per day; upkeep $60 per hole and $25 per parcel per day; Maintenance cuts that by up to 60%.
- Members: caps 40/80/140/220/320 by Clubhouse tier, scaled by `(rating - 28) / 30`, moving 3% of the gap per day; dues $3 per day.
- Tournaments: local needs 14 holes, rating 52, Clubhouse 3, costs $25,000, takes 5 days; regional needs 18 holes, rating 62, Clubhouse 4, costs $60,000. Revenue on success is reward + entry fee x field + tickets (see `tournaments.json`). The bot hosts local or regional only when a tier 5 upgrade waits on it, and national or major only as a sink after tier 5. Pace score and staff requirements are assumed met.
- Renovation: base $150,000, growth 30% per level, 12 levels, opens at 18 holes and every building at tier 4, +8% demand and +$200 per day upkeep per level. The bot renovates after tier 5 is complete or from day 160.
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

- `test_economy_model.gd`: params load and reject garbage, building order equals `buildings.json`, hours per day equals the clock, golden vectors for wtp, acceptance, attraction, arrivals, hourly split (sums exactly), members, parcel cost (equals `MHLandModel`), hole cost, payback price, speed tokens, course upkeep, six full day estimates and fee suggestions, every one of the 50 prices against `MHBuildingDefs.price_for`, the renovation constants, and tournament host costs against `tournaments.json`.
- `test_economy_state.gd`: start state, spend and earn rules, no negative cash, fee clamps, suggested fee beats the extremes, day roll, ledger arithmetic (cash change equals revenue minus upkeep paid), upkeep paid exactly over a day, golden 3-day trace (33 hourly states), golden collapse to bankruptcy then free loan then recovery, token recovery through a real `MHTokenLedger` (refused with too few tokens, grants no cash), speed hook, `purchase_tier`, the renovation sink (golden scenario, opens at tier 4, stops at the maximum, survives save), save round trip through JSON and bad-input rejection, deterministic replay.
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
- The renovation sink is a design placeholder (DEC-069). The spec has no renovation feature; if a real one is designed, re-fit `renov_*` in `make_params.py`.
- `upkeep_per_day` is a placeholder and dominates tier 4 and 5 economics; changing it changes prices.
- The loan is "free" (no interest) per DEC-053 wording. A repeat bankrupt player gets up to 3 loans and then only the token path. Needs product confirmation.
- No difficulty modes, no wages or staff costs, no member churn events; all are hooks for later.
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

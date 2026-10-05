# Phase 1: tournaments (`game/core/tournaments/`)

Status: 4 Oct 2026. Code and tests written, **NOT YET RUN**: Godot cannot start in the authoring sandbox, so no GDScript here has been parsed or executed. Golden numbers in the tests were produced by an independent Python mirror of the algorithm (scratch script, not committed; it uses `tools/reference/determinism/mh_rng.py`), so the logic is checked and only the GDScript itself is unverified. Expect small parse fixes on the first CI run.

Owner paths: `game/core/tournaments/`, `game/core/mh_data_json.gd` (shared loader), `game/tests/tournaments/`, `game/tests/mh_test_edit.gd` (test helper), runtime copy `game/data/tournaments.json` (byte identical to `docs/spec/data/tournaments.json`; after any change run `cp docs/spec/data/tournaments.json game/data/tournaments.json`).

## README block

**Purpose.** DEC-010 and DEC-027: tournaments are the climax of the loop and the gate to every tier-5 building. Four levels (local, regional, national, major). This module decides who may host, runs the calendar of one event (prepare, run, resolve), draws the weather condition and the field result from a seeded PCG32, and returns the money, reputation and prestige effects as data. It never touches cash, the clock or the save: the caller applies what it returns.

**Public API.**
- `MHDataJson` (`game/core/mh_data_json.gd`): `load_file`, `parse_text`, `normalize` (JSON floats to ints, fractional numbers are an error), `is_int_in`, `is_int_array`.
- `MHTournamentDefs`: `load_from_file/text/dict`, `level_ids()`, `level_data(id)`, `entry(id)`, `level_int(id, key)`, `prestige_params()`, `scoring()`, `evaluation()`, `purse()`, `conditions()`, `condition_by_id`, `default_pars()`, `spectator_capacity(clubhouse_tier)`, static `level_rank(id)` (1 to 4) and `level_from_rank`.
- `MHTournamentRules` (static, pure): `entry_report(defs, level, view) -> MHGateReport`, `highest_eligible_level`, `snapshot_score(defs, daily_scores)`, `facility_permille`, `unfair_holes`, `satisfaction_permille`, `event_prestige_permille`, `prestige_points_awarded`, `purse_table`, `cancel_refund`.
- `MHTournamentSim` (static, pure): `event_id(level, start_day)`, `event_seed(secret, event_id, slot)`, `draw_condition`, `pars_for`, `run_field`, `evaluate(defs, level, ctx) -> Dictionary`.
- `MHTournamentState` (the one stateful class): `can_start`, `start`, `advance`, `cancel`, `finish`, `acknowledge`, `status_for`, `course_locked`, `in_cooldown`, `highest_hosted_level`, `has_hosted_at_least(level)` (the tier 5 gate test), `to_save_block/from_save_block` (exactly `save.schema.json` `progress.tournaments`), `to_dict/from_dict` (adds the two counters).
- `MHKillSwitch.is_on(kill_switches, key)` in `game/core/challenges/` (see `challenges.md`); the tournament feature flag is the `tournaments` key.

**The club view** passed to `entry_report`, `can_start` and `start` is a Dictionary: `holes` (valid non-dead holes), `avg_hole_score` (0 to 100), `pace_score` (0 to 100), `staff`, `tiers` (building id to purchased tier). Money is whole DOLLARS, as in the data file (the economy keeps cents: multiply by 100).

## Rules as implemented

Entry (per level, from the data): minimum holes, average hole score, pace score, building tiers (all capped at tier 4 by the loader, so a tier 5 building can never be a prerequisite), staff, spectator capacity. Spectators come from the Clubhouse tier (tier 1 gives 0, tier 2 gives 50, tier 3 gives 150, tier 4 gives 400, tier 5 gives 800; see `spectator_capacity`). The report rows are `[key, met, have, need]`, keys `holes, avg_hole_score, pace_score, building:<id>, staff, spectators`, the same shape the building gates and `MHGameStateView.tournaments()` use.

Calendar (days are the game day counter): `start` on day D takes the host cost (caller pays `result.cost`), stores the snapshot score and sets status `preparing`; the course is locked (`course_locked()`) for the whole event. After `prep_days` the status becomes `running`; on day D + prep + duration the event is resolved: the caller calls `MHTournamentSim.evaluate(...)` then `state.finish(...)`. `cancel` works only while preparing and refunds `cancel_refund_pct` (50) of the host cost. After `finish` the record stays with status `done` or `failed` until `acknowledge()` (so the result card can show), and the cooldown runs from the resolve day (`cooldown_days`, plus `cooldown_extra_days` after a failure).

Snapshot score (anti makeover): the last `snapshot_window_days` (14) daily course scores, at least `sustained_min_days` (10) of them, result `min(latest, lower median)`. Fewer than 10 days gives 0.

Outcome (`evaluate`): failure triggers listed per level in the data. `slow_pace` if pace score is more than `pace_fail_margin` (10) under the level's minimum; `low_snapshot_score` if the snapshot is more than `score_fail_margin` (3) under the level's minimum average hole score; `unfair_hole` if at least 2 holes have fairness under 30; `bad_conditions` if the drawn condition needs a higher Maintenance tier than the club has. Any trigger fails the event: cash loss, reputation loss, longer cooldown, no hosted level recorded. Success pays reward cash and reputation, records the level, and awards club prestige points = `prestige_base` x event prestige / 1000.

Event prestige (0 to 1000) = weights 450 course (snapshot score), 200 pace, 200 facilities (Clubhouse, Restaurant, Pro shop, Cart barn, Maintenance, each capped at tier 4), 150 field satisfaction (1000 minus the condition penalty minus 100 per unfair hole).

Field and ranking: the field has `field_size` NPC players with skills drawn in `[skill_min, skill_max]`; each plays the event holes with a deterministic score model (formula in the header of `mh_tournament_sim.gd`). Ranking: total strokes, then last 9, 6, 3, 1 holes (countback), then lowest `H32(event_seed, player_id)` (rating spec 12: no coin flip). The purse (40% of host cost, split by `places_permille`, remainder to first) is paid OUT OF the host cost, so the economy takes the host cost once.

Determinism: event seed `MHRMath.tournament_seed(save_secret, event_id, slot_id)` = `H32(secret, event_id, slot, 0x7E)`; event id = `start_day x 4 + level rank - 1`. The condition uses PCG32 stream 1 (one `bounded(total weight)`), the field uses stream 2. No clock, no `randi`, no float. Same inputs always give the same result (tests pin 7 golden results).

## Wiring (for the integration task)

- `MHGateView.hosted_level = state.highest_hosted_level()` feeds the existing tier 5 gate in `MHUnlockRules`.
- `MHGameStateView.tournaments()` row: `level`, `status = state.status_for(defs, level, day, view)`, `host_cost`, `reward_cash`, `reward_reputation`, `cooldown_days` (use `cooldown_days_left`), `rows = entry_report(...).rows`.
- Intent `tournament_host {level}`: `state.start(defs, level, day, view, cash, MHKillSwitch.is_on(switches, "tournaments"), MHTournamentRules.snapshot_score(defs, recent_daily_course_scores))`, then take `result.cost` from the economy.
- On each `EV_DAY`: `if state.advance(defs, day):` build the ctx (`event_seed = MHTournamentSim.event_seed(save_secret, state.event_id(), slot_id)`, `snapshot_score = state.active.snapshot_score`, current `pace_score`, per hole `fairness` 0 to 100, `maintenance_tier`, `tiers`, `pars`, `total_yards`), `var res = MHTournamentSim.evaluate(defs, state.active.level, ctx)`, `state.finish(defs, day, res)`, then apply `res.cash_delta`, `res.reputation_delta`, and `progression.add_bonus_prestige(res.prestige_points)`; call `progression.observe_tournaments(state)` and `refresh()`.
- Save: `progress.tournaments = state.to_save_block()`. The counters (`hosted_count`, `attempted_count`) have no field in the schema (see risks).
- Token reward for the result place (ledger rule `tournament_result` 10 / 6 / 4 / 1) is not wired: the player does not enter the field in this model, see question 3.

## Tests (`game/tests/tournaments/`)

`test_tournament_defs.gd` (load, order, tier cap, validation failures, game copy equals docs copy), `test_tournament_rules.gd` (checklist rows, snapshot score edge cases, facility points, prestige golden 522, purse sums, refund), `test_tournament_sim.gd` (seeds, condition goldens and a 2000 seed distribution, 7 full golden results, every failure trigger at its boundary, countback and hash tie-break), `test_tournament_state.gd` (lifecycle, refusals in order, cancel, cooldown, save block shape, JSON round trip, bad blocks). Helper `tournament_fixture.gd`.

## NOT YET RUN

Every `.gd` file and test above. Verified in Python only: the draw order, the field model, the failure triggers, prestige and purse arithmetic.

## Unverified assumptions

- Godot APIs used: `FileAccess.get_file_as_string`, `JSON.parse_string` (whole numbers arrive as float and are normalized), `Array.insert/slice/pop_back/resize/reverse`, `Dictionary` equality by value (`==`), `String.sha256_text`, typed `for x: Type in` loops, `@warning_ignore_start`. gdUnit4: `assert_array(...).contains_exactly`, `assert_str(...).is_not_empty()`, `assert_int(...).is_between/is_greater/is_less`.
- `MHRng.gauss_q16` has sd about 37837 (stated in its header); the field model relies on it.
- `MHGateReport` and `MHBuildingDefs.level_rank` exist as read in this checkout.

## Risks and follow-ups

1. Save schema: `progress.tournaments` has no place for `hosted_count` and `attempted_count`, which the achievements read (`tournaments_hosted`, `tournaments_attempted`). `from_save_block` raises them to at least the number of hosted levels, so a save without them still works but loses the extra counts. Needs a schema field (or store `MHProgression.to_dict()` beside the save).
2. Balance is untouched placeholder data. With the shipped numbers skill barely matters for who wins locally (hole noise dominates); winners are about 1 to 11 strokes under par depending on the level. The field result is cosmetic in v1 (it does not change pay or reputation), so this is safe, but it should be tuned before a results screen shows it.
3. `economy_params.json` carries `tournament_cost_cents` of $25,000 (local) and $60,000 (regional) from the economy simulation; `tournaments.json` says $10,000 and $25,000. The economy bot's tier 5 timing was tuned with the first pair. Reconcile when the economy is re-run.
4. `rating-engine.md` section 11 differs from the data file (24 pros of skill 1000, prestige at least 400 as the gate, cooldown 30 and 60 days, cancel gives a 30 day cooldown). This module follows `tournaments.json` because it is the later and more complete data. The rating spec's `MHRTournament.sustained/prestige` are untouched and unused here.
5. The remote kill switch (`tournaments`) blocks only NEW events. If it were left off, nobody could reach tier 5. Decide whether switching it off should also relax the tier 5 gate.
6. No staff count source exists yet (`staff` in the view); the economy has no wages. Pass 0 only if no staff concept exists, which would block every level (local needs 4).
7. `last_result` is not saved: after a reload on a `done` or `failed` record the result card has nothing to show; call `acknowledge()` then.

## For Nathan

Questions (defaults are in the code and docs, answers change tuning or wording only):
1. Success rule for the tier 5 gate: any successful event of that level (current), or the older "prestige at least 400" rule? A failed event never counts either way.
2. Cancelling a prepared event refunds half of the host cost and applies no cooldown (the data has `cancel_refund_pct` only). Do you want the 30 day cooldown from the rating spec as well?
3. The data has no per-player entry fee and the player does not play in their own tournament. Is that right? If you want entry fees or ticket sales as income, or the player as one of the field, say so and I will add it.
4. Prestige points for success are `prestige_base` scaled by how good the event was (about half at the placeholder numbers). Prefer the full `prestige_base` on any success?

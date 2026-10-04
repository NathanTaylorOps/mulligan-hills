# Phase 1: buildings, unlock rules and land

Status: written 29 Sep 2026. NOT YET RUN: no Godot here, CI has not seen any of this GDScript. Only the Python validator was run.

## 1. What was built

Data (schema_version bumped 1 to 2, breaking):
- `docs/spec/data/buildings.json`, `docs/spec/data/buildings.schema.json` (updated to DEC-048, 050, 055, 056).
- `docs/spec/data/validate.py`: cost-multiplier check replaced by checks for the decisions above, plus a check that `game/data/buildings.json` equals the spec file. This file is outside the buildings paths; the old cost check had to go, so it was edited minimally.
- `game/data/buildings.json`: byte copy for the runtime (`docs/` and `tests/` are not exported to Android). Whenever the spec file changes, copy it: `cp docs/spec/data/buildings.json game/data/buildings.json`. validate.py and a gdUnit test both fail if the two differ.

Code (`game/core/`, integers only, no float maths after JSON load):
- `buildings/mh_building_defs.gd` `MHBuildingDefs`: loads and validates the catalogue (10 buildings, 5 tiers, prerequisite deadlock/cycle check, integral-number check), accessors, `price_for(id, tier, added_daily_income)`.
- `buildings/mh_unlock_rules.gd` `MHUnlockRules`: static `check_gate`, `next_tier`, `purchasable`, `parcels_required`, `demo_locked`, `demo_unreachable`.
- `buildings/mh_gate_view.gd` `MHGateView`: snapshot input (holes, average score, parcels, members, hosted level, tiers, demo flag). `set_from_hole_scores` applies the dead-hole rule.
- `buildings/mh_gate_report.gd` `MHGateReport`: `met`, `demo_locked`, rows `[key, met, have, need]`.
- `land/mh_land_model.gd` `MHLandModel`: 16 parcels, ownership, adjacency, prices, hole and home-slot capacity, heavy-building parcel requirement, save restore (`load_owned`).

Tests: `game/tests/buildings/test_building_defs.gd`, `game/tests/buildings/test_unlock_rules.gd`, `game/tests/land/test_land_model.gd`.

Not built (still the old draft in `docs/spec/interfaces/buildings.md`): `MHBuildings` (purchase, specialisation choice, demolition and persistence rule, save block). It needs the economy and save modules.

## 2. Rules as encoded

- 10 buildings x 5 tiers. Tier gates: average hole score 32 / 42 / 52 / 62 for tiers 2 to 5, holes 6 / 10 / 14 / 18. Tier 1 has no course gate.
- Dead hole: score below 25. Dead holes do not count toward the hole gates. The average is taken over all holes given, dead ones included, so they still drag it down (my reading; see questions).
- Tier 3: one other building at tier 2. Tier 4: two others at tier 3 and 50 members. Fixed links unchanged (Restaurant 3 needs Clubhouse 3, Lodging 3 needs Restaurant 3, Pro shop 4 needs Driving range 3, Homes 4 needs Clubhouse 4, Landmark 5 needs Homes 3).
- Tier 5: a hosted tournament (local; Landmark needs regional). No VIP donor field exists any more. Tournament prerequisites stay at tier 4 or lower (checked by validate.py against `tournaments.json`).
- Tiers are bought in order (tier T needs T-1 standing).
- Price: no fixed costs. `target_payback_days` per tier, placeholder 6 / 8 / 10 / 12 / 15. Price = target days x added daily income, and the economy supplies the income. `price_for` does the multiplication.
- Demo: 9 holes (`demo.max_holes`), tier caps Clubhouse 3, Pro shop 2, Driving range 2, Restaurant 1, all others 0. Only enforced when `MHGateView.demo` is true.
- Land: 16 parcels on a 4x4 grid, id = row * 4 + col:

```
 0 G   1 G   2 G   3 H
 4 G   5 G*  6 G*  7 G
 8 F*  9 G*  10 G* 11 G
 12 F  13 G  14 G  15 H      G golf, F facility, H homes, * start plot
```
  Start plot = parcels 5, 6, 8, 9, 10 (4 golf + 1 facility = 6 holes). A parcel is buyable only if it shares an edge with an owned parcel; otherwise free choice. Price of the n-th purchase = 25000 grown by 130 percent n times (integer, truncating), same numbers as `remote_config.example.json`. `recommended_next` suggests golf first, then facility, then homes, lowest id.
- Hole capacity = owned golf parcels x 3 / 2 (12 golf parcels = 18 holes). Home capacity = homes parcels x 3, max 6.
- Heavy buildings (Driving range, Pool and spa, Lodging, Homes, Landmark) need one extra parcel at tiers 2 to 5. Encoded in the data as `min_parcels_owned`: light 5 / 5 / 8 / 11 / 14, heavy 5 / 6 / 9 / 12 / 15 (a total-owned count, not a specific parcel kind).
- Homes need at least one owned homes parcel (`needs_parcel_kind`). Homes hold up to 6 home slots (`home_slots.max_slots`); upgrading a tier replaces the standing homes with the newer bigger model, never adds slots (`upgrade_mode: replace`; the rule text is documentation, the slot bookkeeping belongs to `MHBuildings`).

## 3. How it is tested

Run (works, Python only): `python3 docs/spec/data/validate.py` -> ALL PASS on 29 Sep 2026 (schema valid, buildings.json valid, gates, payback, heavy parcels, demo caps, land layout, runtime copy, 50 tiers reachable).

NOT YET RUN: the three gdUnit4 suites. They cover: catalogue loads and values; garbage, non-integer and cycle rejection; runtime copy equals spec file; every tier passes with an exactly-met view and fails when each numeric requirement, specific prerequisite and the tournament level is one short; demo caps; heavy parcel rule; Homes parcel kind; all 50 tiers reachable in order; dead-hole rule; land layout, start plot, neighbours, adjacency, price curve, full buy-out order (11 purchases, 18-hole and 6-slot capacity), save restore validation, determinism.

CI: tests sit in `game/tests/buildings/` and `game/tests/land/`, picked up by `res://` recursion. Expected failure risks if CI is red: GDScript typing details (see section 5).

## 4. Known open conflict, pinned by a test

DEC-055 gives the demo Clubhouse tier 3, but tier 3 needs 10 holes and the demo caps at 9 holes, so a demo player cannot reach it. `MHUnlockRules.demo_unreachable` returns `["clubhouse:3"]` and `test_demo_unreachable_pins_known_conflict` asserts exactly that. When Nathan decides, change the data or the cap and update the test to expect an empty array.

## 5. Unverified assumptions

- `@warning_ignore("integer_division")` above functions using `/` on ints (GDScript has no `//`).
- `const LEVELS: Array = [...]` and `"x" in LEVELS` parse and work as written.
- gdUnit4 asserts used: `assert_array(...).is_equal(...)` with `PackedInt32Array` and with plain arrays, `assert_int(...).is_greater`, `assert_bool(...).override_failure_message(...)`.
- `JSON.stringify(x, "", true)` sorts keys (used to compare the two data files).
- `ProjectSettings.globalize_path("res://")` plus `../docs/spec/data/buildings.json` is readable in CI (repo checkout layout). The test fails loudly if it is not.
- The loader accepts both int and float JSON numbers; Godot 4 returns floats for JSON numbers (per the data README).

## 6. Risks and follow-ups

- Other files still carry the old model and are not mine to edit: `remote_config.schema.json` and example (`cost_multiplier_x100`, `building_cost_scale_pct`), `tournaments.json` (local tournament gate `min_avg_hole_score` 30 on the old scale, now below the tier 2 to 4 gates it sits between), `docs/spec/interfaces/buildings.md` (25/30/36/42, costs, `MHBuildings` draft), `docs/spec/data/README.md` rules 8 and 9 (3 holes per parcel, 9 max).
- Schema version bump to 2: any loader or save data that read v1 must be updated. Nothing in the repo besides these files read it.
- Parcel prices are duplicated between this file and remote config (`parcel_base_cost`, `parcel_growth_pct`); remote config should win at runtime once it is wired.
- `MHBuildings` (purchase, persistence, demolition blocking) is the next piece and depends on the economy interface.

## 7. For Nathan

Nothing to run. When the low-end phone tells us the map size, only the parcel sizes change, not this data (the model counts parcels, not metres).

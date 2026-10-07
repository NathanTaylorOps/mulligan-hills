# Staff, grounds condition and pests (DEC-073)

Status: CURRENT MECHANIC / PROVISIONAL BALANCE. Parameters live in `docs/spec/data/staff.json` with a runtime copy in `game/data/staff.json`. `tools/reference/staff/` provides independent deterministic reference coverage and `game/core/staff/` contains the runtime implementation. Current execution evidence belongs in `docs/VERIFICATION.md`; balance values remain subject to simulation and playtesting.

All money is integer cents, all ratios are permille, all division is floor division of non-negative operands (or `MHStaffMath.fdiv`). No float in `game/core/staff`.

## 1. Design rules (what this module may and may not do)

1. The official rating (MHSIM-1.0.0, DEC-076) is unchanged. Staff and condition never enter `MHRatingEngine`. Changing that needs a versioned rating (MHSIM-2).
2. No circular gate (DEC-027). Tournament `entry.min_staff` is met by employees that need only tier 1 to 5 buildings, never by a tournament.
3. Staff are optional to start with, required to grow (DEC-073): without them the course decays, pests rise and arrivals fall, but nothing is locked.
4. The player can always do the work personally (section 8), at a price in their time instead of cash.
5. Everything is deterministic: same inputs and same day sequence give the same state. Incident rolls use `MHRMath.h32d(secret, day, parcel, 0x57)`.
6. Staff changes the economy only through one narrow interface (section 11). `game/core/economy` is not edited.

## 2. Roles and buildings

One role per building. A role needs its building standing (tier >= 1) to be hired, and the number of that role is capped by the tier.

| Role | Building | Kind | Wage/day (trainee) | Cap by tier 1..5 | Pace pts each / max |
|---|---|---|---|---|---|
| groundskeeper | maintenance | grounds | $22.00 | 2 3 4 6 8 | 0 / 0 |
| wildlife_ranger | maintenance | pest | $28.00 | 0 1 2 3 4 | 0 / 0 |
| marshal | clubhouse | station | $20.00 | 1 1 2 2 2 | 3 / 9 |
| caddie | cart_barn | station | $20.00 | 1 1 2 2 2 | 3 / 6 |
| pro_shop_assistant | pro_shop | station | $19.00 | 1 1 2 2 2 | 0 / 0 |
| range_attendant | driving_range | station | $18.00 | 1 1 2 2 2 | 0 / 0 |
| server | restaurant | station | $18.00 | 1 1 2 2 2 | 0 / 0 |
| spa_attendant | pool_spa | station | $24.00 | 1 1 2 2 2 | 0 / 0 |
| housekeeper | lodging | station | $19.00 | 1 1 2 2 2 | 0 / 0 |
| concierge | homes | station | $30.00 | 1 1 2 2 2 | 0 / 0 |
| guide | landmark | station | $25.00 | 1 1 2 2 2 | 0 / 0 |

Kinds: grounds and pest roles work parcels (areas). Station roles work a building and have no areas. The roster is capped at 120 employees. Legacy `club.staff` groups: greenkeepers (groundskeeper, ranger), marshals (marshal, caddie), pro_shop_staff (pro_shop_assistant, range_attendant), caterers (server, spa_attendant, housekeeper, concierge, guide).

The maintenance building is where grounds work comes from. Tier 1 maintenance allows 2 keepers and no ranger, so a new club can mow but cannot patrol.

## 3. Grades, hiring and wages

Grade comes from tenure (days employed), so it is never stored.

| Grade | Tenure from | Wage factor | Work factor |
|---|---|---|---|
| trainee | 0 | 1.000 | 1.000 |
| regular | 20 days | 1.250 | 1.300 |
| veteran | 60 days | 1.500 | 1.700 |

- Wage = floor(base x factor / 1000). Work rises faster than the wage, so keeping people pays (about 13% cheaper per work point at veteran).
- Hire cost = 5 days of the trainee wage (`hire_cost_days`), taken once via `economy.spend`.
- Affordability gate: cash >= hire cost + 3 days of (current payroll + the new trainee's wage) (`hire_reserve_days`). Reason code `cash` otherwise.
- Wages are paid hourly: the day's payroll is split exactly over the 11 game hours (`split_hour`, remainder to the earliest hours) and taken with `economy.incur_loss`. Firing is free and instant.
- Total payroll if every role were filled at trainee wages is small next to the economy: the full-roster sim ends at about $837 a day against $10k+ net a day at day 100.

## 4. Area model (grounds and pest roles)

The land is the 4x4 parcel grid of `buildings.json` (`land`): parcel id = row x 4 + col, kinds golf, facility, homes. An employee works up to 6 parcels (`max_areas_per_employee`), all owned. The employee's daily points are split evenly over the owned areas, remainder to the lowest parcel ids.

- `assign(serial, areas)` errors: no_employee, not_area_role, too_many_areas, bad_area, duplicate_area, not_owned. Nothing changes on an error.
- `auto_assign` gives every area-less grounds or pest employee up to 4 parcels, least covered first (golf, then facility, then homes, ties lowest id). Players who never open the assignment screen still get a working club.
- Parcels that stop being owned are ignored in the split, not removed from `areas`.
- Mapping to the terrain: the 128x128 dev patch has 32x32 = 1024 cells per parcel. `parcel_of_cell(cx, cy, w, h) = (cy*4/h)*4 + (cx*4/w)`, -1 outside the patch. It works for any patch size, so the real map size (DEC-056, pending device test) changes nothing here.

## 5. Condition and pests per parcel

State per parcel (16 entries each): condition 0..1000 (start 700), pest 0..1000 (start 100). Once per game day (`EV_DAY`, after the day's hourly accounting), for each owned parcel in ascending id:

1. Pest growth: `20 + (1000 - cond)/20` per day while pest < 500 (the natural cap); above the cap it falls by 15 a day.
2. Ranger control: pest falls by the control points assigned to the parcel (150 x work factor per ranger, split over areas).
3. Condition: decay by parcel kind (golf 60, facility 30, homes 20) against grounds work (keeper 240 x work factor, split over areas). Work above decay raises condition; below decay lowers it, but a parcel left untended does not fall under 400 from decay alone.
4. Pest damage: condition falls by `pest/25`, never under the hard floor 250.
5. Incident roll (section 6).

One keeper at trainee level (240 points) covers four golf parcels exactly at the decay rate (4 x 60), which is why auto_assign spans 4.

## 6. Incidents and sightings (animal and pest interplay)

`h = h32d(secret, day, parcel, 0x57)`, `roll = h % 1000`, `kind index = h >> 10`.

- Negative incident when `roll < pest^2 / 20000` (about 1.2% a day at pest 500, 0 at pest 100), at most 3 per day. Kinds: burrowers (cond -140, pest +80), goose_flock (cond -60, pest +40), insect_swarm (cond -100, pest +120).
- A ranger covering the parcel with at least 30 control points that day "handles" it: both effects are cut to 25%.
- Otherwise, on a calm parcel (pest <= 150, cond >= 750), `roll >= 1000 - chance` is a positive sighting (deer, heron, fox) with chance 12 permille, +8 with a ranger. Sightings are flavour and a UI event; they carry no numbers yet.
- Pests and condition feed each other: low condition raises pest growth, high pest lowers condition and raises incident chance. Rangers break the loop from the pest side, keepers from the condition side. That is the DEC-073 reason to have both.
- Incident results are returned to the caller (`{parcel, kind, positive, handled}`) for the event feed and for `ai.incident_*` analytics if wanted.

## 7. Effects on the rest of the game

All are pure functions of the staff state and a view of the club.

| Output | Rule | Used for |
|---|---|---|
| demand permille | 1000 + condition term + pest term + service term, clamped 900..1080 | multiply into the economy demand modifier |
| condition term | (avg golf condition - 600) x 100 / 1000 | |
| pest term | -(avg pest over golf and facility parcels) x 40 / 1000 | |
| service term | only if at least one station building stands: (service avg - 500) x 60 / 1000 | |
| service avg | mean over standing station roles of min(1000, work sum / need); need = 1 staff at tiers 1..3, 2 at tiers 4..5 | |
| pace points | per marshal/caddie role: min(max, work sum x 3 / 1000) | added to the tournament pace score |
| satisfaction penalty | if avg golf condition < 600: min(150, (600 - avg) x 150 / 350) permille | tournament field satisfaction |
| overlay | beauty delta = (avg cond - 600) x 100 / 1000, fairness delta = -avg pest x 50 / 1000 | UI-only "condition adjusted" preview, never a score or a gate |

Rating axes: the official Beauty and Fairness axes stay geometry-only. The overlay shows the player what a condition-aware rating would say, so the later MHSIM-2 decision is informed. The overlay is never stored in the save and never fed to a gate.

## 8. Delegation versus personal maintenance

The player can mow and patrol by hand (the cells they cover in the grounds mode of the course editor or in play). The module only needs the cell count and the parcel's cells-per-parcel (1024 on the dev patch).

| | Staff | Player |
|---|---|---|
| Mowing | 240 x work factor a day per keeper, spread over up to 6 parcels | +300 condition per full pass of a parcel, max +600 per parcel per day |
| Patrol | 150 x work factor a day per ranger | -200 pest per full pass, max -400 per parcel per day |
| Cost | wages | player attention |
| Timing | arrives at the day change | at once |

Personal work is stronger per parcel and per day than one keeper, but it covers only what the player walks. A player who mows every owned golf parcel every day keeps condition near 1000 with no staff at all (sim policy `personal`: average condition 999). That is intended: DEC-073 says staff are required to grow, and the tournament gate (below) is what forces at least some hiring. Players who delegate fully (policy `full`) pay about $188k in wages over 260 days and finish about 10 days later.

## 9. Tournament gates

`tournaments.json` has `entry.min_staff` 4, 6, 10, 14 for the four levels. The count the gate sees is `gate_count`: employees with tenure >= 3 days (`tenure_gate_days`) whose building still stands. Three days stops a hire-and-fire exploit for the gate and costs nothing in normal play.

Reachability (no circular gate, DEC-027): with every building at tier 5 the caps add up to 8 + 4 + 2 x 9 = 30 employees, well above 14. Using only maintenance (tier 3 = 4 keepers + 2 rangers), clubhouse (tier 2 = 2 marshals) and a handful of tier 1 stations the first levels are reachable early (4 and 6 need about $400 a day in wages).

Wiring: `view["staff"] = staff.gate_staff_count(view)` before the gate check. `validate.py` checks that the caps can reach the highest `min_staff`.

## 10. Economy calibration

Tools: `tools/reference/staff/staff_sim.py` extends `tools/reference/economy` (20 runs per cell, 260 days; report in `staff_sim_report.txt`).

| Policy | Tier 5 day (casual p50) | Avg demand | Avg condition | Wages total |
|---|---|---|---|---|
| none (baseline, gate assumed met) | 126 | 1000 | n/a | $0 |
| minimal (14 hired, no assignment) | 134 | 948 | 328 | $61k |
| personal (14 hired + player work) | 125 | 1036 | 999 | $63k |
| grounds (keepers assigned) | 133 | 991 | 771 | $79k |
| full (all roles) | 136 | 1038 | 768 | $188k |

Pacing window (DEC-069/071, finish in days 100 to 150): none 83.7%, minimal 83.4%, personal 83.2%, grounds 82.4%, full 79.9%. The target holds for every realistic policy; only a player who hires everything is pushed later. Net income at day 100 is $9.9k to $12.2k a day against $11.9k for the baseline.

## 11. Economy interface (no edits to `game/core/economy`)

```
hire:    var r = staff.hire(role, day, view, economy.cash())   # r.ok, r.cost
         if r.ok: economy.spend(r.cost)
hourly:  var w = staff.pay_hour(hour_index)                    # 0..10
         economy.incur_loss(w)
daily:   var res = staff.on_day(day, view, secret)
         economy.set_demand_modifier(events_modifier * staff.demand_permille(view) / 1000)
gates:   view["staff"] = staff.gate_staff_count(view)
save:    club.staff_roster = staff.to_save_block()
         club.staff = staff.legacy_counts()
```

`incur_loss` can leave wage arrears if cash is short; the existing bankruptcy rules then apply. Whether unpaid staff should walk out is an open question (section 14).

## 12. Code map

`game/core/staff/`: `mh_staff_math.gd` (floor division, hour split), `mh_staff_view.gd` (club view: tiers, owned parcels, kinds), `mh_staff_defs.gd` (data loader and validation), `mh_staff_roster.gd` (hire, fire, assign, wages), `mh_staff_grounds.gd` (condition, pests, incidents, personal work), `mh_staff_effects.gd` (demand, pace, penalty, overlay), `mh_staff.gd` (facade, save block). Strings: `staff_strings_en.json` (draft).

## 13. Save

`save_version` is unchanged. The block `club.staff_roster` is OPTIONAL (a legacy save without it loads with an empty roster): `v`, `next_serial`, `last_day`, `employees` (max 120, each `serial, role, hired_day, tenure, areas`), four 16-integer arrays (`condition`, `pest`, `personal_work`, `personal_pest`) and `stats` (`hires, fires, wages_cents, incidents_hit, incidents_handled, sightings`). `from_save_block` is strict and atomic: any bad field rejects the whole block and leaves the state unchanged. The legacy `club.staff` counts are always written from the roster, so older readers still see a head count.

## 14. Open balance and integration questions

1. The current `mh_session_save.gd` (gameplay) rejects a non-zero `club.staff`; `game/ui` and `MHGameSession` use `staff = 0`. Both must change when the roster is wired.
2. Pace base: `min_pace_score` has no base source yet. Staff only adds points.
3. Should condition ever enter the official rating? Needs MHSIM-2 (versioned rating) first.
4. Wage arrears: should unpaid staff walk out, or only trigger the existing bankruptcy rule?
5. Veteran at 60 days: right length? And is "full delegation finishes 10 days later" acceptable, or should wages drop another 15%?
6. Draft role names (staff_strings_en.json) need a pass by the string owner.

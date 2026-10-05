# Interface: Buildings (`game/core/buildings/`, owner assigned in Phase 1)

## Implementation status (5 Oct 2026)
Built in `game/core/buildings/` and `game/core/land/` (Phase 1, see `docs/phase1/buildings.md`): `MHBuildingDefs` (loader, validation, `price_for`), `MHUnlockRules` (`check_gate`, `next_tier`, `purchasable`, demo locks), `MHGateView` (snapshot), `MHGateReport` (checklist rows) and `MHLandModel`. NOT built: `MHBuildings` below (purchase, specialisation, demolition blocking, save block), `MHEconomy` and `MHResult`; they remain drafts. The data file `docs/spec/data/buildings.json` (schema_version 2) is the source of truth, with a byte-identical runtime copy in `game/data/buildings.json`.

Locked numbers (DEC-048, DEC-050, DEC-055, DEC-056, DEC-063): average hole score gates 32 / 42 / 52 / 62 for tiers 2 to 5 and hole gates 6 / 10 / 14 / 18, tier 1 has no course gate. A hole counts toward the hole gate only if it is valid and not dead (score under 25); dead holes stay in the average. Prices are payback-targeted: price = `target_payback_days` (6 / 8 / 10 / 12 / 15, placeholders) x the tier's added daily income from the economy; there are no fixed costs in the data. Demo caps: 9 holes, Clubhouse tier 2, Pro shop 2, Driving range 2, Restaurant 1, all others 0.

```gdscript
class_name MHBuildings extends RefCounted
signal tier_purchased(building_id: String, tier: int)             # UI, audio, render
func load_catalog(json_text: String) -> MHResult                   # validates shape and prerequisite graph (acyclic, all 50 tiers reachable)
func tier_of(building_id: String) -> int                           # 0 = not built
func spec_of(building_id: String) -> String                        # "", "a" or "b"
func check_gate(building_id: String, tier: int, view: MHGateView) -> MHGateReport
func purchase(building_id: String, tier: int, view: MHGateView, economy: MHEconomy) -> MHResult   # gate check + spend + record, atomic
func choose_specialisation(building_id: String, spec: String) -> MHResult   # tier 3 only, once
func can_demolish(building_id: String) -> MHResult                 # false with the blocking dependency named
func can_remove_hole(hole_no: int) -> MHResult                     # false if a purchased tier depends on the hole count or score
func demo_limit(building_id: String) -> int                        # demo_max_tier from data
func to_save_block() -> Array                                      # `buildings` and `progress.purchased_tiers`
func from_save_block(buildings: Array, purchased: Array) -> MHResult
```
```gdscript
class_name MHGateView extends RefCounted   # snapshot handed in, so the check is pure
var holes: int                   # valid holes that are NOT dead
var avg_hole_score: int          # 0..100
var parcels_owned: int
var members: int
var parcels_by_kind: Dictionary  # "golf" / "facility" / "homes" -> owned count
var hosted_level: String         # highest tournament level hosted: "", "local", "regional", "national", "major"
var tiers: Dictionary            # building_id -> int (read only, copy)
var demo: bool                   # true = demo build, tiers above demo_max_tier are locked

class_name MHGateReport extends RefCounted
var met: bool
var demo_locked: bool            # locked only by the demo cap (UI shows the unlock flow)
var rows: Array                  # (was "checklist" in the draft) rows: [requirement_key: String, met: bool, have: int, need: int]; drives the "what is met and what is missing" card
```

## Rules
- Requirements: holes, average hole score, parcels owned, members, specific other-building tiers, any-N-others at tier T, hosted tournament (tier 5: local, Landmark needs regional). See `buildings.json`; fixed prerequisite links: Restaurant 3 needs Clubhouse 3; Lodging 3 needs Restaurant 3; Pro shop 4 needs Driving range 3; Homes 4 needs Clubhouse 4; Landmark 5 needs Homes 3. Tier 3: one other building at tier 2. Tier 4: two others at tier 3, 50 members.
- Tournament prerequisites never include a tier 5 building.
- Demo: tiers above `demo_max_tier` are shown locked with a preview, purchase returns `ERR_DEMO_LIMIT` (UI shows the unlock flow).
- Costs: `price = target_payback_days x added daily income` (DEC-050), computed by the economy. Remote config does not carry prices.

## Consumers
UI (upgrade card), economy, save, render (model selection by tier and spec), tournaments (facilities score).

## Contract tests
All 50 tiers reachable in order; every gate fails when one requirement is one short; persistence rule blocks demolition; demo limit; catalog validation rejects a cycle.

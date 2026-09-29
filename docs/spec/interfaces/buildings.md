# Interface: Buildings (`game/buildings/`, owner assigned in Phase 1)

Purpose: the 10 x 5 tier catalogue, gate checking, purchase, specialisation choice, persistence of gates. Reads `buildings.json` (schema `buildings.schema.json`). Gates are persistent: purchased tiers are recorded and their dependencies cannot be demolished.

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
var holes: int
var avg_hole_score: int          # 0..100
var parcels_owned: int
var members: int
var hosted_levels: PackedStringArray   # "local".."major"
var tiers: Dictionary            # building_id -> int (read only, copy)

class_name MHGateReport extends RefCounted
var met: bool
var checklist: Array             # rows: [requirement_key: String, met: bool, have: int, need: int]; drives the "what is met and what is missing" card
```

## Rules
- Requirements: holes, average hole score, parcels owned, members, specific other-building tiers, any-N-others at tier T, hosted tournament (tier 5). See `buildings.json`; fixed prerequisite links: Restaurant 3 needs Clubhouse 3; Lodging 3 needs Restaurant 3; Pro shop 4 needs Driving range 3; Homes 4 needs Clubhouse 4; Landmark 5 needs Homes 3. Tier 3: one other building at tier 2. Tier 4: two others at tier 3, 50 members.
- Tournament prerequisites never include a tier 5 building.
- Demo: tiers above `demo_max_tier` are shown locked with a preview, purchase returns `ERR_DEMO_LIMIT` (UI shows the unlock flow).
- Costs read through the economy's clamped params.

## Consumers
UI (upgrade card), economy, save, render (model selection by tier and spec), tournaments (facilities score).

## Contract tests
All 50 tiers reachable in order; every gate fails when one requirement is one short; persistence rule blocks demolition; demo limit; catalog validation rejects a cycle.

class_name MHGateView
extends RefCounted
## Snapshot of the player's course state handed to MHUnlockRules so gate checks are pure.

var holes: int = 0                  # valid holes that are NOT dead (see from_hole_scores)
var avg_hole_score: int = 0         # 0..100 integer average
var parcels_owned: int = 0
var parcels_by_kind: Dictionary = {}  # "golf" / "facility" / "homes" -> owned count
var members: int = 0
var hosted_level: String = ""       # "", "local", "regional", "national", "major"
var tiers: Dictionary = {}          # building_id -> purchased tier (0 or absent = not built)
var demo: bool = false              # true = demo build, tiers above demo_max_tier are locked


func tier_of(building_id: String) -> int:
	return int(tiers.get(building_id, 0))


func kind_count(kind: String) -> int:
	return int(parcels_by_kind.get(kind, 0))


## Build holes and avg_hole_score from raw per-hole scores (0..100).
## holes counts only scores >= dead_below (DEC-048). The average is over ALL holes given,
## so dead holes cannot be hidden by the count rule. Empty input gives 0 and 0.
@warning_ignore("integer_division")
func set_from_hole_scores(scores: Array, dead_below: int) -> void:
	var total: int = 0
	var alive: int = 0
	for s: Variant in scores:
		var v: int = int(s)
		total += v
		if v >= dead_below:
			alive += 1
	holes = alive
	avg_hole_score = 0 if scores.is_empty() else total / scores.size()

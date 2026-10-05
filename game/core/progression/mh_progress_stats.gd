class_name MHProgressStats
extends RefCounted
## The stats Dictionary the achievements and club prestige read. Every stat is a HIGH-WATER MARK: observe() only
## ever raises a value, so nothing can be un-earned (demolishing, selling or a bad day never lowers a stat).
## Names are the enum of docs/spec/data/achievements.schema.json. Integer only. JSON safe.
## tutorial_done is 0 or 1. level is written by MHProgression (derived from club prestige).

const SAVE_VERSION: int = 1
const STAT_KEYS: Array = [
	"holes_max", "holes_good_max", "best_hole_score", "best_course_score", "parcels_max", "members_max",
	"reputation_max", "lifetime_earned", "days_played", "buildings_built", "tier_sum", "tier5_count",
	"tournaments_hosted", "tournaments_attempted", "commissions_done", "commission_kinds", "challenges_completed",
	"challenges_attempted", "streak_best", "active_days", "cards_played", "tutorial_done", "golfers_finished", "level",
	"hosted_local", "hosted_regional", "hosted_national", "hosted_major", "best_axis", "tier_clubhouse",
	"tier_pro_shop", "tier_driving_range", "tier_restaurant", "tier_pool_spa", "tier_cart_barn", "tier_maintenance",
	"tier_lodging", "tier_homes", "tier_landmark",
]
## Stats that are not achievement conditions but feed club prestige.
const EXTRA_KEYS: Array = ["bonus_prestige"]
const MAX_VALUE: int = 1000000000

var _v: Dictionary = {}


static func is_known(key: String) -> bool:
	return STAT_KEYS.has(key) or EXTRA_KEYS.has(key)


func value_of(key: String) -> int:
	return int(_v.get(key, 0))


## Raises stats from a snapshot Dictionary {stat: int}. Unknown keys and non-integers are ignored, values are
## clamped to 0..1e9. Returns true when anything went up.
func observe(snapshot: Dictionary) -> bool:
	var changed: bool = false
	for k: Variant in snapshot.keys():
		var key: String = str(k)
		if not is_known(key):
			continue
		var raw: Variant = snapshot[k]
		var t: int = typeof(raw)
		var val: int = 0
		if t == TYPE_INT:
			val = raw
		elif t == TYPE_BOOL:
			val = 1 if bool(raw) else 0
		else:
			continue
		val = clampi(val, 0, MAX_VALUE)
		if val > value_of(key):
			_v[key] = val
			changed = true
	return changed


## Sets one stat to at least v.
func raise_to(key: String, v: int) -> bool:
	return observe({key: v})


## From purchased tiers {building_id: tier}: tier_<id>, tier_sum, tier5_count, buildings_built.
func observe_tiers(tiers: Dictionary) -> bool:
	var snap: Dictionary = {}
	var total: int = 0
	var fives: int = 0
	var built: int = 0
	for k: Variant in tiers.keys():
		var tier: int = clampi(int(tiers[k]), 0, 5)
		snap["tier_" + str(k)] = tier
		total += tier
		if tier >= 5:
			fives += 1
		if tier >= 1:
			built += 1
	snap["tier_sum"] = total
	snap["tier5_count"] = fives
	snap["buildings_built"] = built
	return observe(snap)


## From the tournament state: hosted_levels (Array of level ids), hosted and attempted counts.
func observe_hosted(hosted_levels: Array, hosted_count: int, attempted_count: int) -> bool:
	var snap: Dictionary = {
		"tournaments_hosted": hosted_count,
		"tournaments_attempted": attempted_count,
	}
	for l: Variant in hosted_levels:
		snap["hosted_" + str(l)] = 1
	return observe(snap)


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in _v.keys():
		out[str(k)] = int(_v[k])
	return {"v": SAVE_VERSION, "stats": out}


## Flat {stat name: int} for save.schema.json progress.stats (stats at zero are left out).
func to_save_block() -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in _v.keys():
		if int(_v[k]) > 0:
			out[str(k)] = int(_v[k])
	return out


## Loads the flat block written by to_save_block. Unknown names are dropped, a bad value rejects the whole block
## (returns false, nothing changed).
func from_save_block(block: Dictionary) -> bool:
	return from_dict({"v": SAVE_VERSION, "stats": block})


## Unknown stat keys are dropped, bad values reject the whole load (returns false, nothing changed).
func from_dict(d: Dictionary) -> bool:
	var errs: Array = []
	var norm: Variant = MHDataJson.normalize(d, errs, "$")
	if not errs.is_empty() or typeof(norm) != TYPE_DICTIONARY:
		return false
	var n: Dictionary = norm
	if int(n.get("v", 0)) != SAVE_VERSION or typeof(n.get("stats", null)) != TYPE_DICTIONARY:
		return false
	var src: Dictionary = n["stats"]
	var fresh: Dictionary = {}
	for k: Variant in src.keys():
		var key: String = str(k)
		if not is_known(key):
			continue
		if not MHDataJson.is_int_in(src[k], 0, MAX_VALUE):
			return false
		fresh[key] = int(src[k])
	_v = fresh
	return true

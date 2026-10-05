class_name MHPersonalEnvelope
extends RefCounted
## Integer mirror of tools/reference/personal_golf/model.py. Provisional balance.
@warning_ignore_start("integer_division")
const VERSION: String = "MHPERSONAL-ENVELOPE-0.1"
const ATTRIBUTES: Array[String] = ["power", "accuracy", "touch", "recovery", "shaping", "composure", "luck"]
const LIES: Array[String] = ["tee", "fairway", "fringe", "rough", "deep", "bunker", "green"]
const BAD: Dictionary = {"rough": [800, 1500], "deep": [600, 2200], "bunker": [700, 1800]}

static func profile(raw: Dictionary) -> Dictionary:
	if raw.size() != 8 or typeof(raw.get("v")) != TYPE_INT or raw["v"] != 1:
		return {}
	for key: String in ATTRIBUTES:
		if typeof(raw.get(key)) != TYPE_INT or raw[key] < 0 or raw[key] > 1000:
			return {}
	return raw.duplicate(true)

static func envelope(raw: Dictionary, desired: int, base: int, lie: String, style: String = "straight", pressure: int = 0) -> Dictionary:
	var p: Dictionary = profile(raw)
	if p.is_empty() or desired < 1 or desired > 120000 or base < 1 or base > 40000 or pressure < 0 or pressure > 150:
		return {}
	if not LIES.has(lie) or not ["straight", "safe_recovery", "putt"].has(style):
		return {}
	if (style == "putt") != (lie == "green") or (style == "safe_recovery" and not BAD.has(lie)):
		return {}
	var carry: int = base * (600 + int(p["power"]) * 400 / 1000) / 1000
	var disp: int = 1000
	if BAD.has(lie):
		var c: int = int(BAD[lie][0])
		var d: int = int(BAD[lie][1])
		carry = carry * (c + int(p["recovery"]) * (1000 - c) / 2000) / 1000
		disp = d - int(p["recovery"]) * (d - 1000) / 2000
	var lateral_pm: int
	var depth_pm: int
	if style == "putt":
		carry = 3000
		lateral_pm = 60 - int(p["touch"]) * 50 / 1000
		depth_pm = 100 - int(p["touch"]) * 80 / 1000
	elif desired <= 800:
		lateral_pm = 80 - int(p["touch"]) * 60 / 1000
		depth_pm = lateral_pm
	else:
		lateral_pm = 130 - int(p["accuracy"]) * 90 / 1000
		depth_pm = 60 - int(p["touch"]) * 35 / 1000
	if style == "safe_recovery":
		carry = mini(carry, 6000)
	carry = maxi(1, carry)
	var effective: int = mini(desired, carry)
	var multiplier: int = 1000 + pressure * (1000 - int(p["composure"])) / 1000
	var lateral: int = effective * lateral_pm / 1000 * disp / 1000 * multiplier / 1000
	var depth: int = effective * depth_pm / 1000 * disp / 1000 * multiplier / 1000
	if style == "safe_recovery":
		lateral = lateral * 700 / 1000
		depth = depth * 700 / 1000
	return {"model": VERSION, "carry_max_cy": carry, "effective_cy": effective, "lie_spread_pm": disp,
		"lateral_scale_cy": maxi(1, lateral), "depth_scale_cy": maxi(1, depth)}

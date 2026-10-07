class_name MHGolferCustomers
extends RefCounted
## Compact persistent state for the 128 public-course customers.
const COUNT: int = 128
const SAVE_VERSION: int = 1
const REGULAR_VISITS: int = 3
const REGULAR_MIN_SAT: int = 68
const MEMBER_EXTRA_VISITS: int = 2
const MEMBER_MIN_SAT: int = 76

var rows: Array = []

func _init() -> void:
	for i: int in range(COUNT):
		rows.append({"id": i, "visits": 0, "satisfaction": 50, "regular": false,
			"member_eligible": false, "member": false, "good_member_visits": 0})

func record_visit(id: int, score: int) -> Dictionary:
	if id < 0 or id >= COUNT:
		return {}
	var r: Dictionary = rows[id] as Dictionary
	var visits: int = int(r["visits"]) + 1
	var previous: int = int(r["satisfaction"])
	var sat: int = score if visits == 1 else (previous * 2 + clampi(score, 0, 100)) / 3
	r["visits"] = visits
	r["satisfaction"] = sat
	var became_regular: bool = false
	if not bool(r["regular"]) and visits >= REGULAR_VISITS and sat >= REGULAR_MIN_SAT:
		r["regular"] = true
		became_regular = true
	if bool(r["regular"]) and not bool(r["member"]) and not became_regular:
		if score >= MEMBER_MIN_SAT:
			r["good_member_visits"] = int(r["good_member_visits"]) + 1
		else:
			r["good_member_visits"] = 0
		r["member_eligible"] = int(r["good_member_visits"]) >= MEMBER_EXTRA_VISITS and sat >= MEMBER_MIN_SAT
	rows[id] = r
	return r.duplicate(true)

func accept_membership(id: int) -> bool:
	if id < 0 or id >= COUNT:
		return false
	var r: Dictionary = rows[id] as Dictionary
	if not bool(r["member_eligible"]):
		return false
	r["member"] = true
	r["member_eligible"] = false
	rows[id] = r
	return true

func to_dict() -> Dictionary:
	return {"v": SAVE_VERSION, "rows": rows.duplicate(true)}

static func from_dict(raw: Variant) -> MHGolferCustomers:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = raw as Dictionary
	if int(d.get("v", -1)) != SAVE_VERSION or typeof(d.get("rows", null)) != TYPE_ARRAY:
		return null
	var src: Array = d["rows"] as Array
	if src.size() != COUNT:
		return null
	var out: MHGolferCustomers = MHGolferCustomers.new()
	for i: int in range(COUNT):
		if typeof(src[i]) != TYPE_DICTIONARY:
			return null
		var r: Dictionary = src[i] as Dictionary
		var visits: int = int(r.get("visits", -1))
		var sat: int = int(r.get("satisfaction", -1))
		var good: int = int(r.get("good_member_visits", -1))
		if visits < 0 or sat < 0 or sat > 100 or good < 0:
			return null
		out.rows[i] = {"id": i, "visits": visits, "satisfaction": sat,
			"regular": bool(r.get("regular", false)), "member_eligible": bool(r.get("member_eligible", false)),
			"member": bool(r.get("member", false)), "good_member_visits": good}
	return out

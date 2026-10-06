class_name MHGolferRoster
extends RefCounted
## Persistent ordinary-customer identities. Deterministic from club save secret + identity id.

const FIRST: Array[String] = ["Alex","Ben","Casey","Dana","Eli","Frankie","Grace","Harper","Jamie","Jordan","Kai","Lee","Morgan","Nico","Parker","Quinn","Riley","Sam","Taylor","Zoe"]
const LAST: Array[String] = ["Adams","Brooks","Carter","Diaz","Evans","Foster","Green","Hayes","Irwin","Jones","Kim","Lane","Miller","Nguyen","Ortiz","Price","Reed","Singh","Turner","Young"]
const MAX_ROSTER: int = 128

var golfers: Dictionary = {}
var next_id: int = 0


func identity_for_admission(save_secret: int, admission_serial: int, day: int) -> Dictionary:
	# Roughly one in four admissions is a deterministic return opportunity once a roster exists.
	if not golfers.is_empty() and admission_serial % 4 == 0:
		var ids: Array = golfers.keys()
		ids.sort()
		var candidate: Dictionary = golfers[ids[posmod(admission_serial / 4 + day, ids.size())]]
		if _return_score(candidate) >= 45:
			return candidate.duplicate(true)
	if golfers.size() >= MAX_ROSTER:
		var existing: Array = golfers.keys()
		existing.sort()
		return (golfers[existing[posmod(admission_serial, existing.size())]] as Dictionary).duplicate(true)
	var id: int = next_id
	next_id += 1
	var h: int = MHRMath.h32d(save_secret, id, 0x474F4C46, 0x4552)
	var g: Dictionary = {"id": id, "name": "%s %s" % [FIRST[posmod(h, FIRST.size())], LAST[posmod(h >> 8, LAST.size())]],
		"preference": MHGolferPreference.archetype(h >> 16), "skill_band": 1 + posmod(h >> 20, 4),
		"visits": 0, "loyalty": 50, "best_satisfaction": -1, "worst_satisfaction": 101,
		"last_satisfaction": 50, "last_day": -1, "favorite_memory": "", "worst_memory": ""}
	golfers[id] = g
	return g.duplicate(true)


func record_visit(identity_id: int, day: int, satisfaction: int, memory: String) -> Dictionary:
	if not golfers.has(identity_id):
		return {}
	var g: Dictionary = golfers[identity_id]
	var sat: int = clampi(satisfaction, 0, 100)
	g["visits"] = int(g["visits"]) + 1
	g["last_day"] = day
	g["last_satisfaction"] = sat
	g["loyalty"] = clampi(int(g["loyalty"]) + MHRMath.rdiv(sat - 50, 5), 0, 100)
	if sat > int(g["best_satisfaction"]):
		g["best_satisfaction"] = sat
		g["favorite_memory"] = memory
	if sat < int(g["worst_satisfaction"]):
		g["worst_satisfaction"] = sat
		g["worst_memory"] = memory
	golfers[identity_id] = g
	return g.duplicate(true)


func _return_score(g: Dictionary) -> int:
	return clampi(int(g.get("loyalty", 50)) + MHRMath.rdiv(int(g.get("last_satisfaction", 50)) - 50, 2), 0, 100)


func to_dict() -> Dictionary:
	var rows: Array = []
	var ids: Array = golfers.keys()
	ids.sort()
	for id: Variant in ids:
		rows.append((golfers[id] as Dictionary).duplicate(true))
	return {"v": 1, "next_id": next_id, "golfers": rows}


func from_dict(raw: Dictionary) -> bool:
	if int(raw.get("v", 0)) != 1 or typeof(raw.get("golfers", null)) != TYPE_ARRAY:
		return false
	var rows: Array = raw["golfers"]
	if rows.size() > MAX_ROSTER:
		return false
	var restored: Dictionary = {}
	for v: Variant in rows:
		if typeof(v) != TYPE_DICTIONARY:
			return false
		var g: Dictionary = v
		for key: String in ["id","name","preference","skill_band","visits","loyalty","best_satisfaction","worst_satisfaction","last_satisfaction","last_day","favorite_memory","worst_memory"]:
			if not g.has(key):
				return false
		var id: int = int(g["id"])
		if id < 0 or restored.has(id) or int(g["preference"]) < 0 or int(g["preference"]) >= MHGolferPreference.COUNT 				or int(g["skill_band"]) < 1 or int(g["skill_band"]) > 4 or int(g["loyalty"]) < 0 or int(g["loyalty"]) > 100:
			return false
		restored[id] = g.duplicate(true)
	var ni: int = int(raw.get("next_id", 0))
	if ni < 0:
		return false
	golfers = restored
	next_id = ni
	return true

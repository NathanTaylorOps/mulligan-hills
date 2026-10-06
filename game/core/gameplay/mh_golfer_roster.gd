class_name MHGolferRoster
extends RefCounted
## Persistent ordinary-customer identities. Deterministic from club save secret + identity id.

const FIRST: Array[String] = ["Alex","Ben","Casey","Dana","Eli","Frankie","Grace","Harper","Jamie","Jordan","Kai","Lee","Morgan","Nico","Parker","Quinn","Riley","Sam","Taylor","Zoe"]
const LAST: Array[String] = ["Adams","Brooks","Carter","Diaz","Evans","Foster","Green","Hayes","Irwin","Jones","Kim","Lane","Miller","Nguyen","Ortiz","Price","Reed","Singh","Turner","Young"]
const MAX_ROSTER: int = 128
const MEMORY_LIMIT: int = 8
const ASSOCIATE_LIMIT: int = 8
const FACILITIES: Array[String] = ["clubhouse","driving_range","restaurant","pro_shop","pool_spa","lodging","homes","landmark"]

var golfers: Dictionary = {}
var next_id: int = 0


func group_for_admission(save_secret: int, admission_serial: int, day: int, size: int) -> Array:
	var out: Array = []
	var n: int = clampi(size, 1, 4)
	var anchor: Dictionary = identity_for_admission(save_secret, admission_serial, day)
	out.append(anchor)
	var used: Dictionary = {int(anchor["id"]): true}
	for i: int in range(1, n):
		var g: Dictionary = identity_for_admission(save_secret, admission_serial + i, day)
		var salt: int = 1
		while used.has(int(g["id"])) and salt < MAX_ROSTER:
			g = identity_for_admission(save_secret, admission_serial + i + salt * 104729, day)
			salt += 1
		used[int(g["id"])] = true
		g["group_id"] = int(anchor["group_id"])
		g["relationship_role"] = ["friend", "partner", "family"][posmod(int(g["id"]) + i, 3)]
		if golfers.has(int(g["id"])):
			golfers[int(g["id"])] = g.duplicate(true)
		link_associates(int(anchor["id"]), int(g["id"]))
		out.append((golfers[int(g["id"])] as Dictionary).duplicate(true))
	# Once an anchor has a social graph, vary future public parties among those known associates.
	if int(anchor.get("visits", 0)) > 0:
		var social: Array = public_party(int(anchor["id"]), n, admission_serial + day)
		if social.size() == n:
			for member_v: Variant in social:
				var member: Dictionary = member_v
				member["group_id"] = int(anchor["group_id"])
			return social
	return out


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
		"look_seed": MHRMath.h32d(save_secret, id, 0x4C4F4F4B, 1), "identity_type": "ordinary",
		"favorite_facility": FACILITIES[posmod(h >> 24, FACILITIES.size())], "favorite_hole_slot": -1,
		"social_circle_id": id, "group_id": -1, "relationship_role": ["friend","partner","family"][posmod(h >> 12, 3)],
		"member": false, "membership_status": "none", "associates": [], "home_interest": 0, "membership_interest": 0, "visits": 0, "loyalty": 50, "best_satisfaction": -1, "worst_satisfaction": 101,
		"last_satisfaction": 50, "last_day": -1, "favorite_memory": "", "worst_memory": "", "memories": []}
	golfers[id] = g
	return g.duplicate(true)


func link_associates(a_id: int, b_id: int) -> void:
	if a_id == b_id or not golfers.has(a_id) or not golfers.has(b_id):
		return
	for pair: Array in [[a_id, b_id], [b_id, a_id]]:
		var g: Dictionary = golfers[int(pair[0])]
		var associates: Array = (g.get("associates", []) as Array).duplicate()
		var other: int = int(pair[1])
		if not associates.has(other):
			associates.append(other)
			while associates.size() > ASSOCIATE_LIMIT:
				associates.pop_front()
		g["associates"] = associates
		golfers[int(pair[0])] = g


func public_party(anchor_id: int, desired_size: int, entropy: int) -> Array:
	if not golfers.has(anchor_id):
		return []
	var anchor: Dictionary = golfers[anchor_id]
	var ids: Array = (anchor.get("associates", []) as Array).duplicate()
	ids.sort()
	var out: Array = [anchor.duplicate(true)]
	var target: int = clampi(desired_size, 1, 4)
	if ids.is_empty():
		return out
	var start: int = posmod(entropy, ids.size())
	for step: int in range(ids.size()):
		if out.size() >= target:
			break
		var id: int = int(ids[(start + step) % ids.size()])
		if golfers.has(id):
			out.append((golfers[id] as Dictionary).duplicate(true))
	return out


func record_visit(identity_id: int, day: int, satisfaction: int, memory: String, hole_slot: int = 0, flags: int = 0) -> Dictionary:
	if not golfers.has(identity_id):
		return {}
	var g: Dictionary = golfers[identity_id]
	var sat: int = clampi(satisfaction, 0, 100)
	g["visits"] = int(g["visits"]) + 1
	g["last_day"] = day
	g["last_satisfaction"] = sat
	g["favorite_hole_slot"] = hole_slot if sat >= int(g.get("best_satisfaction", -1)) else int(g.get("favorite_hole_slot", -1))
	var memories: Array = g.get("memories", []) as Array
	memories.append({"day": day, "hole_slot": hole_slot, "satisfaction": sat, "flags": flags, "text": memory})
	while memories.size() > MEMORY_LIMIT:
		memories.pop_front()
	g["memories"] = memories
	g["loyalty"] = clampi(int(g["loyalty"]) + MHRMath.rdiv(sat - 50, 5), 0, 100)
	if sat > int(g["best_satisfaction"]):
		g["best_satisfaction"] = sat
		g["favorite_memory"] = memory
	if sat < int(g["worst_satisfaction"]):
		g["worst_satisfaction"] = sat
		g["worst_memory"] = memory
	# Strong repeat visits create interest/application intent; membership itself is a club decision.
	var interest: int = clampi(int(g.get("membership_interest", 0)) + maxi(0, sat - 60) / 4, 0, 100)
	g["membership_interest"] = interest
	if str(g.get("membership_status", "none")) == "none" and int(g["visits"]) >= 3 and int(g["loyalty"]) >= 72 and interest >= 35:
		g["membership_status"] = "interested"
	if str(g.get("membership_status", "none")) == "interested" and int(g["visits"]) >= 4 and interest >= 50:
		g["membership_status"] = "applied"
	g["member"] = str(g.get("membership_status", "none")) == "member"
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
		for key: String in ["id","name","preference","skill_band","look_seed","identity_type","favorite_facility","favorite_hole_slot","group_id","relationship_role","member","visits","loyalty","best_satisfaction","worst_satisfaction","last_satisfaction","last_day","favorite_memory","worst_memory","memories"]:
			if not g.has(key):
				return false
		if not g.has("associates"):
			g["associates"] = []
		if not g.has("social_circle_id"):
			g["social_circle_id"] = int(g["id"])
		if not g.has("membership_status"):
			g["membership_status"] = "member" if bool(g.get("member", false)) else "none"
		if not g.has("home_interest"):
			g["home_interest"] = 0
		if not g.has("membership_interest"):
			g["membership_interest"] = 0
		var id: int = int(g["id"])
		if id < 0 or restored.has(id) or int(g["preference"]) < 0 or int(g["preference"]) >= MHGolferPreference.COUNT 				or int(g["skill_band"]) < 1 or int(g["skill_band"]) > 4 or int(g["loyalty"]) < 0 or int(g["loyalty"]) > 100 \
				or typeof(g["memories"]) != TYPE_ARRAY or (g["memories"] as Array).size() > MEMORY_LIMIT:
			return false
		restored[id] = g.duplicate(true)
	# Validate the social graph only after every golfer id is known. Saves may never restore
	# self-links, duplicate links, dangling golfer ids, or more relationships than the model allows.
	for id_v: Variant in restored.keys():
		var id: int = int(id_v)
		var g: Dictionary = restored[id]
		if typeof(g.get("associates", null)) != TYPE_ARRAY:
			return false
		var associates: Array = g["associates"] as Array
		if associates.size() > ASSOCIATE_LIMIT:
			return false
		var seen_associates: Dictionary = {}
		for associate_v: Variant in associates:
			if not MHRValidate.is_int_value(associate_v):
				return false
			var associate_id: int = int(associate_v)
			if associate_id == id or not restored.has(associate_id) or seen_associates.has(associate_id):
				return false
			seen_associates[associate_id] = true
	var ni: int = int(raw.get("next_id", 0))
	# next_id is the next never-issued identity, so it must be strictly above every restored id.
	# Accepting a lower value would let the next new admission overwrite an existing golfer.
	var max_id: int = -1
	for id_v: Variant in restored.keys():
		max_id = maxi(max_id, int(id_v))
	if ni < 0 or ni <= max_id or ni > MAX_ROSTER:
		return false
	golfers = restored
	next_id = ni
	return true

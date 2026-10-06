class_name MHGolferRoster
extends RefCounted
## Persistent ordinary-customer identities. Deterministic from club save secret + identity id.

const FIRST: Array[String] = ["Alex","Ben","Casey","Dana","Eli","Frankie","Grace","Harper","Jamie","Jordan","Kai","Lee","Morgan","Nico","Parker","Quinn","Riley","Sam","Taylor","Zoe"]
const LAST: Array[String] = ["Adams","Brooks","Carter","Diaz","Evans","Foster","Green","Hayes","Irwin","Jones","Kim","Lane","Miller","Nguyen","Ortiz","Price","Reed","Singh","Turner","Young"]
const MAX_ROSTER: int = 128
const MEMORY_LIMIT: int = 8
const ASSOCIATE_LIMIT: int = 8
const REGULAR_VISITS: int = 5
const HAPPY_SATISFACTION: int = 70
const MEMBERSHIP_HAPPY_ROUNDS_AFTER_REGULAR: int = 2
const HOME_HAPPY_VISITS: int = 5
const FACILITIES: Array[String] = ["clubhouse","driving_range","restaurant","pro_shop","pool_spa","lodging","homes","landmark"]

var golfers: Dictionary = {}
var next_id: int = 0

## Relationship identity is persistent (associates/social_circle_id). group_id is presentation-only
## and must never be written back as the identity of a lasting friendship.


func group_for_admission(save_secret: int, admission_serial: int, day: int, size: int) -> Array:
	var out: Array = []
	var n: int = clampi(size, 1, 4)
	var anchor: Dictionary = identity_for_admission(save_secret, admission_serial, day)
	# Party identity is per admission, not part of the persistent social graph.
	var party_group_id: int = admission_serial
	anchor["group_id"] = party_group_id
	out.append(anchor)
	var used: Dictionary = {int(anchor["id"]): true}
	for i: int in range(1, n):
		var g: Dictionary = identity_for_admission(save_secret, admission_serial + i, day)
		var salt: int = 1
		while used.has(int(g["id"])) and salt < MAX_ROSTER:
			g = identity_for_admission(save_secret, admission_serial + i + salt * 104729, day)
			salt += 1
		used[int(g["id"])] = true
		# A visiting party gets a transient group id. Do not persist it into the golfer record:
		# the same associate can legitimately appear in a different party next visit.
		g["group_id"] = party_group_id
		g["relationship_role"] = ["friend", "partner", "family"][posmod(int(g["id"]) + i, 3)]
		link_associates(int(anchor["id"]), int(g["id"]))
		out.append(g.duplicate(true))
	# Once an anchor has returned, complete the deterministic friend pool and vary each public party.
	if int(anchor.get("visits", 0)) > 0:
		ensure_social_graph(save_secret)
		var social: Array = public_party(int(anchor["id"]), n, admission_serial + day)
		if social.size() == n:
			for member_v: Variant in social:
				var member: Dictionary = member_v
				member["group_id"] = party_group_id
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
		"member": false, "membership_status": "none", "associates": [], "home_interest": 0, "home_status": "none", "home_slot": -1, "membership_interest": 0,
		"happy_visit_streak": 0, "happy_rounds_as_regular": 0, "home_request": false, "visits": 0, "loyalty": 50, "best_satisfaction": -1, "worst_satisfaction": 101,
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



func ensure_social_graph(save_secret: int) -> void:
	# Once identities exist, give every golfer a deterministic pool of up to eight known people.
	# This is persistent relationship state; individual visiting parties remain transient subsets.
	if golfers.size() < 2:
		return
	var ids: Array = golfers.keys()
	ids.sort()
	for anchor_v: Variant in ids:
		var anchor_id: int = int(anchor_v)
		var candidates: Array = []
		for other_v: Variant in ids:
			var other_id: int = int(other_v)
			if other_id == anchor_id:
				continue
			var score: int = MHRMath.h32d(save_secret, anchor_id, other_id, 0x534F434C)
			candidates.append({"id": other_id, "score": score})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a["score"]) == int(b["score"]):
				return int(a["id"]) < int(b["id"])
			return int(a["score"]) < int(b["score"]))
		var limit: int = mini(ASSOCIATE_LIMIT, candidates.size())
		for i: int in range(limit):
			link_associates(anchor_id, int((candidates[i] as Dictionary)["id"]))



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



func club_guest_for_member(save_secret: int, member_id: int, admission_serial: int, day: int) -> Dictionary:
	if not golfers.has(member_id):
		return {}
	var member: Dictionary = golfers[member_id]
	if not bool(member.get("member", false)):
		return {}
	# A member occasionally invites one person from the wider character pool. The invitation
	# is deterministic from save state/day/serial so replaying a checkpoint cannot reroll it.
	var chance: int = posmod(MHRMath.h32d(save_secret, member_id, admission_serial, day), 100)
	if chance >= 30:
		return {}
	var guest: Dictionary = identity_for_admission(save_secret, admission_serial + 700001, day)
	if int(guest.get("id", -1)) == member_id:
		return {}
	guest["guest_of"] = member_id
	guest["relationship_role"] = "guest"
	guest["group_id"] = admission_serial
	return guest



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
	# Character progression is visit-based and observable: five visits establishes a regular.
	# From then on, two further happy rounds earn a membership application. A separate five-visit
	# happiness streak earns a request to buy a home; neither request is automatically approved.
	var happy: bool = sat >= HAPPY_SATISFACTION
	g["happy_visit_streak"] = int(g.get("happy_visit_streak", 0)) + 1 if happy else 0
	var visits: int = int(g["visits"])
	if visits > REGULAR_VISITS:
		g["happy_rounds_as_regular"] = int(g.get("happy_rounds_as_regular", 0)) + 1 if happy else 0
	else:
		g["happy_rounds_as_regular"] = 0
	var interest: int = clampi(int(g.get("membership_interest", 0)) + (maxi(0, sat - 60) / 4 if happy else 0), 0, 100)
	g["membership_interest"] = interest
	if str(g.get("membership_status", "none")) == "none" and visits >= REGULAR_VISITS:
		g["membership_status"] = "interested"
	if str(g.get("membership_status", "none")) == "interested" and int(g["happy_rounds_as_regular"]) >= MEMBERSHIP_HAPPY_ROUNDS_AFTER_REGULAR:
		g["membership_status"] = "applied"
	var home_gain: int = maxi(0, sat - HAPPY_SATISFACTION) / 5 if happy else 0
	if happy and str(g.get("favorite_facility", "")) == "homes":
		home_gain += 2
	g["home_interest"] = clampi(int(g.get("home_interest", 0)) + home_gain, 0, 100)
	if int(g["happy_visit_streak"]) >= HOME_HAPPY_VISITS and str(g.get("home_status", "none")) == "none":
		g["home_request"] = true
	g["member"] = str(g.get("membership_status", "none")) == "member"
	golfers[identity_id] = g
	return g.duplicate(true)




func member_count() -> int:
	var count: int = 0
	for g_v: Variant in golfers.values():
		if bool((g_v as Dictionary).get("member", false)):
			count += 1
	return count


func home_candidates(min_interest: int = 50) -> Array:
	var out: Array = []
	var ids: Array = golfers.keys()
	ids.sort()
	for id_v: Variant in ids:
		var g: Dictionary = golfers[id_v] as Dictionary
		if bool(g.get("home_request", false)) and int(g.get("home_interest", 0)) >= min_interest:
			out.append(g.duplicate(true))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("home_interest", 0)) == int(b.get("home_interest", 0)):
			return int(a["id"]) < int(b["id"])
		return int(a.get("home_interest", 0)) > int(b.get("home_interest", 0)))
	return out




func home_resident_count() -> int:
	var count: int = 0
	for g_v: Variant in golfers.values():
		if str((g_v as Dictionary).get("home_status", "none")) == "resident":
			count += 1
	return count


func assign_home(identity_id: int, slot: int) -> bool:
	if not golfers.has(identity_id) or slot < 0:
		return false
	var g: Dictionary = golfers[identity_id]
	if str(g.get("home_status", "none")) == "resident" or not bool(g.get("home_request", false)) or int(g.get("home_interest", 0)) < 50:
		return false
	for other_v: Variant in golfers.values():
		var other: Dictionary = other_v
		if str(other.get("home_status", "none")) == "resident" and int(other.get("home_slot", -1)) == slot:
			return false
	g["home_status"] = "resident"
	g["home_slot"] = slot
	g["home_request"] = false
	golfers[identity_id] = g
	return true



func membership_applications() -> Array:
	var out: Array = []
	var ids: Array = golfers.keys()
	ids.sort()
	for id_v: Variant in ids:
		var g: Dictionary = golfers[id_v] as Dictionary
		if str(g.get("membership_status", "none")) == "applied":
			out.append(g.duplicate(true))
	return out


func decide_membership(identity_id: int, accept: bool) -> bool:
	if not golfers.has(identity_id):
		return false
	var g: Dictionary = golfers[identity_id]
	if str(g.get("membership_status", "none")) != "applied":
		return false
	g["membership_status"] = "member" if accept else "declined"
	g["member"] = accept
	golfers[identity_id] = g
	return true



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
		if not g.has("home_status"):
			g["home_status"] = "none"
		if not g.has("home_slot"):
			g["home_slot"] = -1
		if not g.has("membership_interest"):
			g["membership_interest"] = 0
		if not g.has("happy_visit_streak"):
			g["happy_visit_streak"] = 0
		if not g.has("happy_rounds_as_regular"):
			g["happy_rounds_as_regular"] = 0
		if not g.has("home_request"):
			g["home_request"] = false
		var id: int = int(g["id"])
		var membership_status: String = str(g["membership_status"])
		var home_status: String = str(g["home_status"])
		var home_slot: int = int(g["home_slot"])
		if id < 0 or restored.has(id) or int(g["preference"]) < 0 or int(g["preference"]) >= MHGolferPreference.COUNT \
				or int(g["skill_band"]) < 1 or int(g["skill_band"]) > 4 or int(g["loyalty"]) < 0 or int(g["loyalty"]) > 100 \
				or int(g["membership_interest"]) < 0 or int(g["membership_interest"]) > 100 \
				or int(g["home_interest"]) < 0 or int(g["home_interest"]) > 100 \
				or not ["none", "interested", "applied", "member", "declined"].has(membership_status) \
				or bool(g["member"]) != (membership_status == "member") \
				or not ["none", "resident"].has(home_status) \
				or (home_status == "none" and home_slot != -1) or (home_status == "resident" and home_slot < 0) \
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
		# Relationships are stored as a friendship graph, so a restored edge must be reciprocal.
		for associate_v: Variant in associates:
			var other: Dictionary = restored[int(associate_v)] as Dictionary
			if not (other.get("associates", []) as Array).has(id):
				return false
	var occupied_home_slots: Dictionary = {}
	for g_v: Variant in restored.values():
		var resident: Dictionary = g_v
		if str(resident.get("home_status", "none")) != "resident":
			continue
		var slot: int = int(resident["home_slot"])
		if occupied_home_slots.has(slot):
			return false
		occupied_home_slots[slot] = true
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

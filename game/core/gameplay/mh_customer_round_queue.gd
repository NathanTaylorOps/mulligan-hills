class_name MHCustomerRoundQueue
extends RefCounted
## Presentation scheduler for economy-authorized customers across authoritative course holes.
## Admission/payment happen in MHEconomy. This class never changes cash or simulation outcomes.

const TEE_INTERVAL_S: float = 12.0
const MAX_VISIBLE_WAITING: int = 24
const MAX_COMPLETED_HISTORY: int = 64

var waiting: Array = []
var active: Dictionary = {} # Compatibility view: lowest party id currently active.
var active_parties: Dictionary = {}
var occupied_holes: Dictionary = {}
var completed: Array = []
var facility_visits: Array = []
var pending_facility_visits: Array = []
var next_tee_s: float = 0.0


func admit(rows: Array, hole_def: Dictionary, rating: Dictionary, ctx: Dictionary) -> void:
	for v: Variant in rows:
		var customer: Dictionary = (v as Dictionary).duplicate(true)
		# Authoritative session already resolved the round and customer outcome.
		# This queue only schedules playback; never re-simulate or mutate satisfaction/economy.
		var round: Dictionary = customer.get("round", {}) as Dictionary
		if not round.is_empty():
			waiting.append(customer)


func visible_waiting() -> Array:
	return waiting.slice(0, mini(waiting.size(), MAX_VISIBLE_WAITING)).duplicate(true)


func offscreen_waiting_count() -> int:
	return maxi(0, waiting.size() - MAX_VISIBLE_WAITING)


func queue_facility_visit(customer: Dictionary, facility_instance_id: String, now_s: float) -> Dictionary:
	# Queuing a destination is not the same as arriving there. The dwell timer begins only
	# when presentation reports physical arrival through begin_facility_visit().
	if facility_instance_id == "":
		return {}
	var visit: Dictionary = {"identity": (customer.get("identity", {}) as Dictionary).duplicate(true),
		"facility_instance_id": facility_instance_id, "group_id": int((customer.get("identity", {}) as Dictionary).get("group_id", -1)),
		"serial": int(customer.get("serial", 0)), "hole_slot": int(customer.get("hole_slot", -1)), "queued_s": now_s}
	pending_facility_visits.append(visit)
	return visit


func begin_facility_visit(serial: int, now_s: float) -> Dictionary:
	for i: int in range(pending_facility_visits.size()):
		var pending: Dictionary = pending_facility_visits[i]
		if int(pending.get("serial", -1)) != serial:
			continue
		pending_facility_visits.remove_at(i)
		var visit: Dictionary = pending.duplicate(true)
		visit["start_s"] = now_s
		visit["end_s"] = now_s + 8.0 + float(posmod(serial, 8))
		facility_visits.append(visit)
		return visit.duplicate(true)
	return {}


func active_facility_visits(now_s: float) -> Array:
	var out: Array = []
	var keep: Array = []
	for v: Variant in facility_visits:
		var visit: Dictionary = v
		if now_s < float(visit["end_s"]):
			keep.append(visit)
			out.append(visit.duplicate(true))
	facility_visits = keep
	return out


func advance(now_s: float) -> Dictionary:
	var events: Array = advance_all(now_s)
	return {} if events.is_empty() else events[0] as Dictionary


func advance_all(now_s: float) -> Array:
	var events: Array = []
	_start_waiting_parties(now_s, events)
	var ids: Array = active_parties.keys()
	ids.sort()
	for party_v: Variant in ids:
		var party_id: int = int(party_v)
		if not active_parties.has(party_id):
			continue
		var state: Dictionary = active_parties[party_id] as Dictionary
		if bool(state.get("transitioning", false)):
			continue
		var elapsed: float = now_s - float(state["started_s"])
		var all_done: bool = true
		var hole_index: int = int(state.get("hole_index", 0))
		for customer_v: Variant in state.get("customers", []):
			var customer: Dictionary = customer_v
			var round: Dictionary = _playback_round(customer, hole_index)
			var timeline: Dictionary = MHAIRoundTimeline.state(round.get("events", []) as Array, elapsed)
			if not bool(timeline.get("done", false)):
				all_done = false
				break
		if not all_done:
			continue
		var party_customers: Array = state.get("customers", []) as Array
		var current_slot: int = int((party_customers[0] as Dictionary).get("hole_slot", -1))
		occupied_holes.erase(current_slot)
		var next_hole: int = hole_index + 1
		if _party_has_hole(party_customers, next_hole):
			var next_party: Array = _party_for_hole(party_customers, next_hole)
			state["transition_from_hole_slot"] = current_slot
			state["transition_hole_index"] = next_hole
			state["transition_customers"] = next_party
			state["transitioning"] = true
			active_parties[party_id] = state
			events.append({"kind": "hole_transition", "party_id": party_id, "hole_index": next_hole,
				"customers": next_party.duplicate(true), "customer": (next_party[0] as Dictionary).duplicate(true)})
		else:
			var done_party: Array = _party_for_hole(party_customers, hole_index)
			for done_v: Variant in done_party:
				completed.append((done_v as Dictionary).duplicate(true))
			while completed.size() > MAX_COMPLETED_HISTORY:
				completed.pop_front()
			active_parties.erase(party_id)
			events.append({"kind": "finished", "party_id": party_id, "customers": done_party,
				"customer": (done_party[0] as Dictionary).duplicate(true)})
	_sync_active_compat()
	return events


func _start_waiting_parties(now_s: float, events: Array) -> void:
	if waiting.is_empty() or now_s < next_tee_s:
		return
	var cursor: int = 0
	while cursor < waiting.size():
		var first: Dictionary = waiting[cursor] as Dictionary
		var party_id: int = int(first.get("party_id", first.get("serial", 0)))
		var party: Array = []
		var end: int = cursor
		while end < waiting.size() and int((waiting[end] as Dictionary).get("party_id", (waiting[end] as Dictionary).get("serial", 0))) == party_id:
			party.append(waiting[end] as Dictionary)
			end += 1
		var slot: int = int(first.get("hole_slot", -1))
		if not occupied_holes.has(slot):
			for _i: int in range(end - cursor):
				waiting.remove_at(cursor)
			var state: Dictionary = first.duplicate(true)
			state["party_id"] = party_id
			state["customers"] = party
			state["started_s"] = now_s
			state["hole_index"] = 0
			active_parties[party_id] = state
			occupied_holes[slot] = party_id
			events.append({"kind": "started", "party_id": party_id, "customers": party.duplicate(true), "customer": first.duplicate(true)})
			next_tee_s = now_s + TEE_INTERVAL_S
			return # Global tee cadence: at most one new party starts per interval.
		cursor = end


func begin_next_hole(now_s: float, party_id: int = -1) -> Dictionary:
	if party_id < 0:
		party_id = int(active.get("party_id", -1))
	if not active_parties.has(party_id):
		return {}
	var state: Dictionary = active_parties[party_id] as Dictionary
	if not bool(state.get("transitioning", false)):
		return {}
	var next_hole: int = int(state.get("transition_hole_index", -1))
	var next_party: Array = state.get("transition_customers", []) as Array
	if next_hole < 0 or next_party.is_empty():
		return {}
	var slot: int = int((next_party[0] as Dictionary).get("hole_slot", -1))
	if occupied_holes.has(slot):
		return {} # Tee congestion: wait until the party ahead clears this hole.
	state["hole_index"] = next_hole
	state["started_s"] = now_s
	state["customers"] = next_party
	state["transitioning"] = false
	state.erase("transition_from_hole_slot")
	state.erase("transition_hole_index")
	state.erase("transition_customers")
	state.merge((next_party[0] as Dictionary), false)
	active_parties[party_id] = state
	occupied_holes[slot] = party_id
	_sync_active_compat()
	return {"kind": "hole_started", "party_id": party_id, "hole_index": next_hole,
		"customers": next_party.duplicate(true), "customer": (next_party[0] as Dictionary).duplicate(true)}


func transition_from_hole(party_id: int) -> int:
	if not active_parties.has(party_id):
		return -1
	return int((active_parties[party_id] as Dictionary).get("transition_from_hole_slot", -1))


func _sync_active_compat() -> void:
	if active_parties.is_empty():
		active = {}
		return
	var ids: Array = active_parties.keys()
	ids.sort()
	active = (active_parties[ids[0]] as Dictionary).duplicate(true)


func visual_state(now_s: float) -> Dictionary:
	if active.is_empty():
		return {"done": true}
	var customers: Array = active.get("customers", [])
	if customers.is_empty():
		return {"done": true}
	var round: Dictionary = _playback_round(customers[0] as Dictionary, int(active.get("hole_index", 0)))
	return MHAIRoundTimeline.state(round.get("events", []) as Array, now_s - float(active["started_s"]))


static func _playback_round(customer: Dictionary, hole_index: int) -> Dictionary:
	var holes: Array = customer.get("course_round", []) as Array
	if hole_index >= 0 and hole_index < holes.size():
		return (holes[hole_index] as Dictionary).get("round", {}) as Dictionary
	return customer.get("round", {}) as Dictionary


static func _party_has_hole(customers: Array, hole_index: int) -> bool:
	if customers.is_empty():
		return false
	return hole_index < ((customers[0] as Dictionary).get("course_round", []) as Array).size()


static func _party_for_hole(customers: Array, hole_index: int) -> Array:
	var out: Array = []
	for customer_v: Variant in customers:
		var customer: Dictionary = (customer_v as Dictionary).duplicate(true)
		var holes: Array = customer.get("course_round", []) as Array
		if hole_index >= 0 and hole_index < holes.size():
			var hole: Dictionary = holes[hole_index] as Dictionary
			customer["hole_slot"] = int(hole.get("hole_slot", customer.get("hole_slot", -1)))
			customer["round"] = (hole.get("round", {}) as Dictionary).duplicate(true)
		out.append(customer)
	return out


static func satisfaction(round: Dictionary, par: int = 3) -> int:
	var strokes: int = int(round.get("strokes", maxi(par, 3) + 6))
	var flags: int = int(round.get("flags", 0))
	var score: int = 90 - maxi(0, strokes - maxi(par, 1)) * 10
	if flags & 8:
		score -= 5
	if flags & (1 | 2 | 32):
		score -= 12
	if flags & 4:
		score -= 20
	return clampi(score, 0, 100)


static func reaction(score: int, flags: int) -> String:
	if flags & 4:
		return "That hole beat me up."
	if flags & (1 | 2 | 32):
		return "Brutal penalty, but I want another crack at it."
	if score >= 85:
		return "Great hole. I'd play that again."
	if score >= 65:
		return "Tough, but fair."
	return "That was rough."

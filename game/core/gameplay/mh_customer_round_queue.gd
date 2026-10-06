class_name MHCustomerRoundQueue
extends RefCounted
## Presentation scheduler for economy-authorized customers across authoritative course holes.
## Admission/payment happen in MHEconomy. This class never changes cash or simulation outcomes.

const TEE_INTERVAL_S: float = 12.0
const MAX_VISIBLE_WAITING: int = 24
const MAX_COMPLETED_HISTORY: int = 64

var waiting: Array = []
var active: Dictionary = {}
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
	var event: Dictionary = {}
	if active.is_empty() and not waiting.is_empty() and now_s >= next_tee_s:
		var first: Dictionary = waiting.pop_front() as Dictionary
		var party_id: int = int(first.get("party_id", first.get("serial", 0)))
		var party: Array = [first]
		while not waiting.is_empty() and int((waiting[0] as Dictionary).get("party_id", (waiting[0] as Dictionary).get("serial", 0))) == party_id:
			party.append(waiting.pop_front() as Dictionary)
		active = first.duplicate(true)
		active["party_id"] = party_id
		active["customers"] = party
		active["started_s"] = now_s
		active["hole_index"] = 0
		next_tee_s = now_s + TEE_INTERVAL_S
		event = {"kind": "started", "customers": party.duplicate(true), "customer": first.duplicate(true)}
	if not active.is_empty():
		var elapsed: float = now_s - float(active["started_s"])
		var all_done: bool = true
		var hole_index: int = int(active.get("hole_index", 0))
		for customer_v: Variant in active.get("customers", []):
			var customer: Dictionary = customer_v
			var round: Dictionary = _playback_round(customer, hole_index)
			var state: Dictionary = MHAIRoundTimeline.state(round.get("events", []) as Array, elapsed)
			if not bool(state.get("done", false)):
				all_done = false
				break
		if all_done:
			var party_customers: Array = active.get("customers", []) as Array
			var next_hole: int = hole_index + 1
			if _party_has_hole(party_customers, next_hole):
				active["hole_index"] = next_hole
				active["started_s"] = now_s
				var next_party: Array = _party_for_hole(party_customers, next_hole)
				active["customers"] = next_party
				active.merge((next_party[0] as Dictionary), false)
				event = {"kind": "hole_started", "hole_index": next_hole, "customers": next_party.duplicate(true),
					"customer": (next_party[0] as Dictionary).duplicate(true)}
			else:
				var done_party: Array = party_customers.duplicate(true)
				for done_v: Variant in done_party:
					completed.append((done_v as Dictionary).duplicate(true))
				while completed.size() > MAX_COMPLETED_HISTORY:
					completed.pop_front()
				active = {}
				event = {"kind": "finished", "customers": done_party, "customer": (done_party[0] as Dictionary).duplicate(true)}
	return event


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

class_name MHCustomerRoundQueue
extends RefCounted
## Presentation scheduler for economy-authorized customers on one authoritative hole.
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


func queue_facility_visit(customer: Dictionary, facility_id: String, now_s: float) -> Dictionary:
	# Queuing a destination is not the same as arriving there. The dwell timer begins only
	# when presentation reports physical arrival through begin_facility_visit().
	if facility_id == "":
		return {}
	var visit: Dictionary = {"identity": (customer.get("identity", {}) as Dictionary).duplicate(true),
		"facility": facility_id, "group_id": int((customer.get("identity", {}) as Dictionary).get("group_id", -1)),
		"serial": int(customer.get("serial", 0)), "queued_s": now_s}
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
		active = waiting.pop_front() as Dictionary
		active["started_s"] = now_s
		next_tee_s = now_s + TEE_INTERVAL_S
		event = {"kind": "started", "customer": active.duplicate(true)}
	if not active.is_empty():
		var round: Dictionary = active["round"]
		var elapsed: float = now_s - float(active["started_s"])
		var state: Dictionary = MHAIRoundTimeline.state(round["events"] as Array, elapsed)
		if bool(state.get("done", false)):
			var done: Dictionary = active.duplicate(true)
			completed.append(done)
			while completed.size() > MAX_COMPLETED_HISTORY:
				completed.pop_front()
			active = {}
			event = {"kind": "finished", "customer": done}
	return event


func visual_state(now_s: float) -> Dictionary:
	if active.is_empty():
		return {"done": true}
	var round: Dictionary = active["round"]
	return MHAIRoundTimeline.state(round["events"] as Array, now_s - float(active["started_s"]))


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

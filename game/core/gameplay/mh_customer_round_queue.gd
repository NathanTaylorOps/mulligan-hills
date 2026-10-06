class_name MHCustomerRoundQueue
extends RefCounted
## Presentation scheduler for economy-authorized customers on one authoritative hole.
## Admission/payment happen in MHEconomy. This class never changes cash or simulation outcomes.

const TEE_INTERVAL_S: float = 12.0
const MAX_WAITING: int = 24

var waiting: Array = []
var active: Dictionary = {}
var completed: Array = []
var facility_visits: Array = []
var next_tee_s: float = 0.0


func admit(rows: Array, hole_def: Dictionary, rating: Dictionary, ctx: Dictionary) -> void:
	for v: Variant in rows:
		if waiting.size() >= MAX_WAITING:
			break
		var customer: Dictionary = (v as Dictionary).duplicate(true)
		# Authoritative session already resolved the round and customer outcome.
		# This queue only schedules playback; never re-simulate or mutate satisfaction/economy.
		var round: Dictionary = customer.get("round", {}) as Dictionary
		if not round.is_empty():
			waiting.append(customer)


func queue_facility_visit(customer: Dictionary, facility_id: String, now_s: float) -> Dictionary:
	if facility_id == "":
		return {}
	var visit: Dictionary = {"identity": (customer.get("identity", {}) as Dictionary).duplicate(true),
		"facility": facility_id, "group_id": int((customer.get("identity", {}) as Dictionary).get("group_id", -1)),
		"start_s": now_s, "end_s": now_s + 8.0 + float(int(customer.get("serial", 0)) % 8)}
	facility_visits.append(visit)
	return visit


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
			active = {}
			event = {"kind": "finished", "customer": done}
	return event


func visual_state(now_s: float) -> Dictionary:
	if active.is_empty():
		return {"done": true}
	var round: Dictionary = active["round"]
	return MHAIRoundTimeline.state(round["events"] as Array, now_s - float(active["started_s"]))


static func satisfaction(round: Dictionary) -> int:
	var strokes: int = int(round.get("strokes", 9))
	var flags: int = int(round.get("flags", 0))
	var score: int = 90 - maxi(0, strokes - 3) * 10
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

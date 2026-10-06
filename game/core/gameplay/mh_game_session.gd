class_name MHGameSession
extends RefCounted
## Live integer-only coordinator. Wall time and elapsed microseconds are supplied by the scene.
## UI intents are rechecked here; prices and eligibility never come from a button's arguments.
## Course input is validated RHI, not the different dm/polygon save format.
@warning_ignore_start("integer_division")

signal changed()
signal autosave_requested()

var clock: MHGameClock = MHGameClock.new()
var ledger: MHTokenLedger = MHTokenLedger.new()
var economy: MHEconomy
var defs: MHBuildingDefs
var land: MHLandModel
var bridge: MHProgressBridge
var demo: bool = true
var club_name: String = "Mulligan Hills"
var staff: int = 0 # No staffing rules exist yet. Do not invent employees to unlock tournaments.
var save_secret: int = 0
var rating_epoch: int = 0
var unix_now: int = 0
var recent_scores: Array = []
var practice: MHPracticeRound = null
## Transient presentation queue. Economy remains authoritative for admission and payment; this only exposes paid arrivals.
var _pending_customers: Array = [] # authoritative paid customers awaiting hourly outcome resolution
var _customer_serial: int = 0
var customer_feedback_sum: int = 0
var customer_feedback_count: int = 0
var customer_outcomes: Array = [] # immutable authoritative records; presentation never mutates economy/roster
var golfer_roster: MHGolferRoster = MHGolferRoster.new()
var building_placements: Dictionary = {} # instance_id -> terrain-aware freeform placement record
var _next_building_instance_id: int = 1
var _holes: Array = []
var _ratings: Array = []
var _course: Dictionary = {}


static func create() -> MHGameSession:
	var s: MHGameSession = MHGameSession.new()
	s.defs = MHBuildingDefs.load_default()
	var params: MHEconomyParams = MHEconomyParams.load_default()
	if not s.defs.is_loaded() or not params.is_loaded() or not MHRParams.ensure_loaded():
		return null
	s.economy = MHEconomy.create_from_defs(params, s.defs)
	s.land = MHLandModel.create(s.defs)
	s.bridge = MHProgressBridge.create()
	if s.economy == null or not s.bridge.is_ready():
		return null
	s._apply_course()
	s._sync_progress()
	return s


func hole_definitions() -> Array:
	return _holes.duplicate(true)


## Checkpoint restore re-rates designs without charging construction or granting achievement rewards.
## This is used only on a fresh, unexposed session after the save boundary validates it.
func restore_course(hole_defs: Array) -> bool:
	if not _holes.is_empty() or not _ratings.is_empty():
		return false
	var cap: int = mini(defs.hole_cap(), land.hole_capacity())
	if demo:
		cap = mini(cap, defs.demo_max_holes())
	if hole_defs.size() > cap:
		return false
	var seen: Dictionary = {}
	for row: Variant in hole_defs:
		if typeof(row) != TYPE_DICTIONARY:
			return false
		var h: Dictionary = row
		var check: Dictionary = MHRatingEngine.validate_input({"schema": 1, "engine": MHRatingEngine.RATING_VERSION, "hole": h})
		if not bool(check["ok"]) or not MHRValidate.is_int_value(h.get("slot_id", null)):
			return false
		var slot: int = int(h["slot_id"])
		if slot < 0 or slot >= defs.hole_cap() or seen.has(slot):
			return false
		seen[slot] = true
	var rated: Dictionary = MHRatingEngine.rate_course(hole_defs, {"save_secret": save_secret, "rating_epoch": rating_epoch})
	for row: Variant in rated["holes"]:
		if not bool((row as Dictionary).get("valid", false)):
			return false
	_holes = hole_defs.duplicate(true)
	_ratings = (rated["holes"] as Array).duplicate(true)
	_course = (rated["course"] as Dictionary).duplicate(true)
	return true


func hole_results() -> Array:
	return _ratings.duplicate(true)


func course_result() -> Dictionary:
	return _course.duplicate(true)


func hole_scores() -> Array:
	var out: Array = []
	for v: Variant in _ratings:
		var r: Dictionary = v
		if bool(r.get("valid", false)):
			out.append(int(r["score"]))
	return out


func tiers() -> Dictionary:
	var out: Dictionary = {}
	for v: Variant in economy.params.building_ids:
		var id: String = str(v)
		out[id] = economy.tier_of(economy.params.building_index(id))
	return out


func gate_view() -> MHGateView:
	var g: MHGateView = MHGateView.new()
	g.set_from_hole_scores(hole_scores(), defs.dead_hole_score_below())
	# Whole scores are rounded for display. 24.9 rounds to 25 but remains a dead hole.
	g.holes = 0
	for v: Variant in _ratings:
		var r: Dictionary = v
		if bool(r.get("valid", false)) and not bool(r.get("dead", true)):
			g.holes += 1
	g.members = economy.members()
	g.tiers = tiers()
	g.demo = demo
	g.hosted_level = bridge.tournaments.highest_hosted_level()
	land.fill_view(g)
	return g


func pace_score() -> int:
	# Same course pace statistic used by the rating engine, converted to a 0..100 score.
	# Until the authoritative pace-to-entry conversion exists, zero keeps the gate honest.
	return 0


func _club_view() -> Dictionary:
	var g: MHGateView = gate_view()
	return {"holes": g.holes, "avg_hole_score": g.avg_hole_score, "pace_score": pace_score(),
		"staff": staff, "tiers": g.tiers}


func _sync_progress() -> void:
	bridge.update_inputs(economy.day, unix_now, economy.cash / 100, _club_view(), recent_scores, {}, club_name)
	var best: int = 0
	for v: Variant in hole_scores():
		best = maxi(best, int(v))
	var result: Dictionary = bridge.observe_club({"holes_max": hole_scores().size(), "holes_good_max": gate_view().holes,
		"best_hole_score": best, "best_course_score": int(_course.get("course_x10", 0)) / 10,
		"members_max": economy.members(), "parcels_max": land.owned_count(),
		"lifetime_earned": economy.total_revenue / 100, "days_played": economy.day}, tiers())
	_award_achievements(result)


func _award_achievements(result: Dictionary) -> void:
	for v: Variant in result.get("new_achievements", []):
		ledger.grant_earned("achievement", str(v))


func _apply_course() -> void:
	economy.set_course(hole_scores().size(), int(_course.get("course_x10", 0)) / 10, land.owned_count())


## Replace the entire course after editing. New slots cost money; redesigning existing slots is free.
## Validation, caps, lock, affordability and full rating succeed before any state changes.
func submit_course(hole_defs: Array) -> Dictionary:
	if bridge.tournaments.course_locked():
		return _result(false, "tournament_locked")
	var cap: int = mini(defs.hole_cap(), land.hole_capacity())
	if demo:
		cap = mini(cap, defs.demo_max_holes())
	if hole_defs.size() > cap or hole_defs.size() < _holes.size():
		return _result(false, "hole_cap")
	var seen: Dictionary = {}
	for v: Variant in hole_defs:
		if typeof(v) != TYPE_DICTIONARY:
			return _result(false, "invalid_hole")
		var h: Dictionary = v
		var validation: Dictionary = MHRatingEngine.validate_input({"schema": 1, "engine": MHRatingEngine.RATING_VERSION, "hole": h})
		if not bool(validation["ok"]):
			return _result(false, str(validation["code"]))
		if not h.has("slot_id") or not MHRValidate.is_int_value(h["slot_id"]):
			return _result(false, "invalid_slot")
		var slot: int = int(h["slot_id"])
		if slot < 0 or slot >= defs.hole_cap():
			return _result(false, "invalid_slot")
		if seen.has(slot):
			return _result(false, "duplicate_slot")
		seen[slot] = true
	for v: Variant in _holes:
		if not seen.has(int((v as Dictionary)["slot_id"])):
			return _result(false, "cannot_demolish")
	var cost: int = 0
	for n: int in range(_holes.size(), hole_defs.size()):
		cost += MHEconomyModel.hole_cost_cents(economy.params, n)
	if cost > 0 and not economy.can_afford(cost):
		return _result(false, "cash")
	var rated: Dictionary = MHRatingEngine.rate_course(hole_defs, {"save_secret": save_secret, "rating_epoch": rating_epoch})
	for v: Variant in rated["holes"]:
		if not bool((v as Dictionary).get("valid", false)):
			return _result(false, "invalid_rating")
	if cost > 0 and economy.spend(cost) != MHEconomy.OK:
		return _result(false, "cash")
	_holes = hole_defs.duplicate(true)
	_ratings = (rated["holes"] as Array).duplicate(true)
	_course = (rated["course"] as Dictionary).duplicate(true)
	_apply_course()
	_sync_progress()
	changed.emit()
	return _result(true)


## Process each clock hour once, including the final hour of a day. Daily history samples once per game day.
func advance(delta_us: int, wall_unix: int) -> void:
	var old_day: int = unix_now / 86400
	var old_tokens: int = ledger.earned
	unix_now = maxi(0, wall_unix)
	ledger.claim_daily_login(unix_now / 86400)
	var before: int = clock.total_minutes()
	var events: PackedInt32Array = clock.step(delta_us, ledger)
	var hourly: bool = false
	for i: int in range(0, events.size(), MHGameClock.EVENT_STRIDE):
		if events[i] != MHGameClock.EV_HOUR:
			continue
		var tick: Dictionary = economy.tick_hour()
		_queue__pending_customers(tick)
		_resolve_customer_hour()
		hourly = true
		if bool(tick["day_rolled"]):
			recent_scores.append(int(_course.get("course_x10", 0)) / 10)
			if recent_scores.size() > 14:
				recent_scores.remove_at(0)
		_sync_progress()
		_resolve_tournament()
	_sync_progress()
	# Clock.step has already advanced to the end of the frame. Save only after accounting catches up.
	if hourly:
		autosave_requested.emit()
	if before != clock.total_minutes() or old_tokens != ledger.earned or old_day != unix_now / 86400 or not events.is_empty():
		changed.emit()


func _queue__pending_customers(tick: Dictionary) -> void:
	var n: int = maxi(0, int(tick.get("golfers", 0)))
	if n == 0 or _holes.is_empty():
		return
	var fees: int = maxi(0, int(tick.get("fees", 0)))
	var ancillary: int = maxi(0, int(tick.get("ancillary", 0)))
	var fee_each: int = fees / n
	var anc_each: int = ancillary / n
	var remaining: int = n
	while remaining > 0:
		var group_size: int = mini(remaining, 1 + posmod(_customer_serial + economy.day, 4))
		var group: Array = golfer_roster.group_for_admission(save_secret, _customer_serial, economy.day, group_size)
		for identity_v: Variant in group:
			var identity: Dictionary = identity_v
			var hole_index: int = posmod(_customer_serial, _holes.size())
			_pending_customers.append({"serial": _customer_serial, "identity": identity, "group_size": group_size,
				"paid_fee": fee_each, "ancillary": anc_each, "admitted_day": economy.day, "admitted_hour": economy.hour,
				"hole_slot": int((_holes[hole_index] as Dictionary)["slot_id"])})
			_customer_serial += 1
			remaining -= 1


func _hole_index_for_slot(slot_id: int) -> int:
	for i: int in range(_holes.size()):
		if int((_holes[i] as Dictionary).get("slot_id", -1)) == slot_id:
			return i
	return -1


func _resolve_customer_hour() -> void:
	if _pending_customers.is_empty() or _holes.is_empty() or _ratings.is_empty():
		return
	var start: int = customer_outcomes.size()
	for admission_v: Variant in _pending_customers:
		var customer: Dictionary = (admission_v as Dictionary).duplicate(true)
		var identity: Dictionary = customer.get("identity", {}) as Dictionary
		var band: int = int(identity.get("skill_band", 1))
		var hole_index: int = _hole_index_for_slot(int(customer.get("hole_slot", -1)))
		if hole_index < 0:
			continue
		var hole: Dictionary = _holes[hole_index] as Dictionary
		var rating: Dictionary = _ratings[hole_index] as Dictionary
		var round: Dictionary = MHAIRoundRecord.play(hole, {"save_secret": save_secret, "rating_epoch": rating_epoch}, band, 0)
		if round.is_empty():
			continue
		var pref: int = int(identity.get("preference", MHGolferPreference.CASUAL))
		var base: int = MHCustomerRoundQueue.satisfaction(round, int(rating.get("par", 3)))
		var bonus: int = MHGolferPreference.bonus(pref, rating, round)
		var sat: int = clampi(base + bonus, 0, 100)
		customer["round"] = round
		customer["rating"] = rating.duplicate(true)
		customer["preference"] = pref
		customer["base_satisfaction"] = base
		customer["preference_bonus"] = bonus
		customer["satisfaction"] = sat
		customer["reaction"] = MHCustomerRoundQueue.reaction(sat, int(round.get("flags", 0)))
		customer["preference_reaction"] = MHGolferPreference.describe(pref, bonus)
		customer["identity"] = golfer_roster.record_visit(int(identity["id"]), economy.day, sat,
			str(customer["reaction"]), int(customer.get("hole_slot", 0)), int(round.get("flags", 0)))
		customer_outcomes.append(customer)
		customer_feedback_sum += sat
		customer_feedback_count += 1
	var count: int = customer_outcomes.size() - start
	if count > 0:
		var total: int = 0
		for i: int in range(start, customer_outcomes.size()):
			total += int((customer_outcomes[i] as Dictionary)["satisfaction"])
		var avg: int = MHRMath.rdiv(total, count)
		var delta: int = clampi(MHRMath.rdiv(avg - 50, 12), -4, 4)
		economy.reputation = clampi(economy.reputation + delta, economy.params.c("rep_floor_permille"), 1000)


func take__pending_customers(limit: int = 4) -> Array:
	var count: int = mini(maxi(limit, 0), customer_outcomes.size())
	var out: Array = []
	for _i: int in range(count):
		out.append(customer_outcomes.pop_front())
	return out


## Completed visible rounds move reputation slowly. 50/100 is neutral; one customer can move at most 4 permille.
## Existing MHEconomy arrivals/membership formulas then turn reputation into future demand.
## Customer outcomes are resolved exactly once by _resolve_customer_hour().
## Presentation receives immutable copies through take_customer_admissions() and has no mutation API.


func customer_feedback_average() -> int:
	if customer_feedback_count <= 0:
		return 0
	return MHRMath.rdiv(customer_feedback_sum, customer_feedback_count)


## Authoritative placement boundary. Presentation may preview arbitrary candidates, but only
## structurally valid records for purchased buildings enter session state.
func set_building_placement(building_id: String, placement: Dictionary) -> bool:
	var index: int = economy.params.building_index(building_id)
	if index < 0 or economy.tier_of(index) <= 0:
		return false
	if not _valid_building_placement_record(building_id, placement):
		return false
	# Legacy callers replace the first instance of a type. New callers can supply a stable instance_id.
	var instance_id: String = str(placement.get("instance_id", ""))
	if instance_id.is_empty():
		instance_id = first_building_instance_id(building_id)
	if instance_id.is_empty():
		instance_id = "building_%d" % _next_building_instance_id
		_next_building_instance_id += 1
	var stored: Dictionary = placement.duplicate(true)
	stored["building_id"] = building_id
	stored["instance_id"] = instance_id
	building_placements[instance_id] = stored
	changed.emit()
	return true


func first_building_instance_id(building_id: String) -> String:
	var ids: Array = building_placements.keys()
	ids.sort()
	for id_v: Variant in ids:
		var p: Dictionary = building_placements[id_v] as Dictionary
		if str(p.get("building_id", str(id_v))) == building_id:
			return str(id_v)
	return ""


func building_position(building_id: String) -> Vector3:
	var instance_id: String = first_building_instance_id(building_id)
	if instance_id.is_empty():
		return Vector3.INF
	var placement: Dictionary = building_placements[instance_id] as Dictionary
	if not _valid_building_placement_record(building_id, placement):
		return Vector3.INF
	var center: Array = placement["center_mm"] as Array
	return Vector3(float(int(center[0])) / 1000.0, float(int(placement["ground_mm"])) / 1000.0,
		float(int(center[1])) / 1000.0)


func restore_building_placements(raw: Variant) -> bool:
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	var restored: Dictionary = {}
	var rows: Dictionary = raw as Dictionary
	var next_instance: int = 1
	for key_v: Variant in rows.keys():
		if typeof(rows[key_v]) != TYPE_DICTIONARY:
			return false
		var placement: Dictionary = (rows[key_v] as Dictionary).duplicate(true)
		# Reader migration: old checkpoints were keyed by building type and had no instance identity.
		var building_id: String = str(placement.get("building_id", str(key_v)))
		var instance_id: String = str(placement.get("instance_id", ""))
		if instance_id.is_empty():
			instance_id = "building_%d" % next_instance
			next_instance += 1
		placement["building_id"] = building_id
		placement["instance_id"] = instance_id
		var index: int = economy.params.building_index(building_id)
		if index < 0 or economy.tier_of(index) <= 0 or restored.has(instance_id) or not _valid_building_placement_record(building_id, placement):
			return false
		restored[instance_id] = placement
	building_placements = restored
	_next_building_instance_id = next_instance
	return true

func _valid_building_placement_record(building_id: String, placement: Dictionary) -> bool:
	if str(placement.get("building_id", building_id)) != building_id:
		return false
	if not bool(placement.get("ok", false)):
		return false
	if typeof(placement.get("center_mm", null)) != TYPE_ARRAY or typeof(placement.get("size_m", null)) != TYPE_ARRAY:
		return false
	var center: Array = placement["center_mm"] as Array
	var size: Array = placement["size_m"] as Array
	if center.size() != 2 or size.size() != 2:
		return false
	for value: Variant in center:
		if not MHRValidate.is_int_value(value):
			return false
	for value: Variant in size:
		if not MHRValidate.is_int_value(value) or int(value) <= 0:
			return false
	if not MHRValidate.is_int_value(placement.get("ground_mm", null)) or not MHRValidate.is_int_value(placement.get("rotation_quarters", null)):
		return false
	var rotation: int = int(placement["rotation_quarters"])
	if rotation < 0 or rotation > 3:
		return false
	# World bounds are authoritative for this integration surface; half-footprint must remain inside it.
	var half_x_mm: int = int(size[0]) * 500
	var half_y_mm: int = int(size[1]) * 500
	if rotation % 2 == 1:
		var swap: int = half_x_mm
		half_x_mm = half_y_mm
		half_y_mm = swap
	var world_mm: int = 128000
	if int(center[0]) - half_x_mm < 0 or int(center[1]) - half_y_mm < 0 			or int(center[0]) + half_x_mm > world_mm or int(center[1]) + half_y_mm > world_mm:
		return false
	return true


func handle_intent(id: StringName, args: Dictionary) -> Dictionary:
	var out: Dictionary = _result(false, "unknown_intent")
	out["handled"] = false
	match id:
		&"set_speed":
			out = _result(clock.request_speed(int(args.get("speed", 1)), ledger.earned) == MHGameClock.SPEED_OK, "speed")
		&"toggle_pause":
			if clock.is_paused():
				clock.resume()
			else:
				clock.pause()
			out = _result(true)
		&"buy_tier":
			var bid: String = str(args.get("building", ""))
			var tier: int = int(args.get("tier", 0))
			if MHUnlockRules.check_gate(defs, bid, tier, gate_view()).met:
				out = _result(economy.purchase_tier(economy.params.building_index(bid), tier) == MHEconomy.OK, "cash")
			else:
				out = _result(false, "gate")
		&"buy_parcel":
			out = _result(false, "parcel")
			var parcel: int = int(args.get("parcel", -1))
			var price: int = land.next_price() * 100
			if land.check_buy(parcel) == "":
				# The parcel is allowed; a refusal now can only be cash ("cash", not the generic "parcel").
				out = _result(false, "cash")
				if economy.can_afford(price):
					if economy.spend(price) == MHEconomy.OK:
						land.buy(parcel)
						_apply_course()
						out = _result(true)
		&"set_green_fee":
			economy.set_green_fee(int(args.get("cents", economy.fee)))
			out = _result(true)
		&"recovery_loan":
			out = _result(economy.take_bank_loan() >= 0, "recovery")
		&"recovery_tokens":
			out = _result(economy.recover_with_tokens(ledger) == MHEconomy.OK, "recovery")
		&"tournament_host":
			out = _result(false, "recovery")
			_sync_progress()
			if not economy.is_bankrupt():
				out = bridge.host_tournament(str(args.get("level", "")))
				if bool(out.get("ok", false)):
					economy.spend(int(out["cost"]) * 100)
		&"tournament_acknowledge":
			bridge.tournaments.acknowledge()
			out = _result(true)
		&"daily_play":
			out = bridge.start_daily()
	_sync_progress()
	if bool(out.get("ok", false)):
		changed.emit()
	return out


## Rate the actual submitted design with today's official seed before consuming an attempt.
func submit_daily(hole_def: Dictionary) -> Dictionary:
	_sync_progress()
	var started: Dictionary = bridge.start_daily()
	if not bool(started.get("ok", false)):
		return started
	var validation: Dictionary = MHRatingEngine.validate_input({"schema": 1,
		"engine": MHRatingEngine.RATING_VERSION, "hole": hole_def})
	if not bool(validation["ok"]):
		return _result(false, str(validation["code"]))
	var challenge: Dictionary = started["challenge"]
	var r: Dictionary = MHRatingEngine.rate_hole(hole_def, {"hole_seed": int(challenge["sim_seed"])})
	var done: Dictionary = bridge.finish_daily_attempt({"valid": bool(r.get("valid", false)),
		"par": int(r.get("par", 0)), "length_yd": int(r.get("L", 0)), "score": int(r.get("score", 0)),
		"axes": {"accuracy": int(r.get("A", 0)) / 10, "imagination": int(r.get("I", 0)) / 10,
			"length": int(r.get("Len", 0)) / 10, "beauty": int(r.get("B", 0)) / 10,
			"fairness": int(r.get("F", 0)) / 10}})
	if bool(done.get("newly_completed", false)):
		ledger.grant_earned("challenge_complete", str(unix_now / 86400))
	_award_achievements(done.get("refresh", {}) as Dictionary)
	_sync_progress()
	changed.emit()
	return done


func _resolve_tournament() -> void:
	var pars: Array = []
	var fair: Array = []
	var yards: int = 0
	for v: Variant in _ratings:
		var r: Dictionary = v
		if bool(r.get("valid", false)):
			pars.append(int(r["par"]))
			fair.append(int(r["F"]) / 10)
			yards += int(r["L"])
	var result: Dictionary = bridge.resolve_tournament({"event_seed": MHTournamentSim.event_seed(
		save_secret, bridge.tournaments.event_id(), 0), "pace_score": pace_score(),
		"fairness": fair, "maintenance_tier": int(tiers().get("maintenance", 0)),
		"tiers": tiers(), "pars": pars, "total_yards": yards})
	if not bool(result.get("ok", false)):
		return
	var outcome: Dictionary = result["result"]
	var delta: int = int(outcome["cash_delta"]) * 100
	if delta >= 0:
		economy.earn(delta)
	else:
		economy.incur_loss(-delta)
	economy.reputation = clampi(economy.reputation + int(outcome["reputation_delta"]) * 10, 0, 1000)
	_award_achievements(result.get("refresh", {}) as Dictionary)


static func _result(ok: bool, reason: String = "") -> Dictionary:
	return {"handled": true, "ok": ok, "reason": "" if ok else reason}

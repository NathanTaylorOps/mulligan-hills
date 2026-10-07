class_name MHGameSession
extends RefCounted
## Live integer-only coordinator. Wall time and elapsed microseconds are supplied by the scene.
## UI intents are rechecked here; prices and eligibility never come from a button's arguments.
## Course input is validated RHI, not the different dm/polygon save format.
@warning_ignore_start("integer_division")

signal changed()
signal autosave_requested()
signal golfers_booked(count: int, customer_ids: Array, booked_minute: int)

var clock: MHGameClock = MHGameClock.new()
var ledger: MHTokenLedger = MHTokenLedger.new()
var economy: MHEconomy
var defs: MHBuildingDefs
var land: MHLandModel
var bridge: MHProgressBridge
var demo: bool = true
var club_name: String = "Mulligan Hills"
var staff: MHStaff
var staff_defs: MHStaffDefs
var save_secret: int = 0
var rating_epoch: int = 0
var unix_now: int = 0
var recent_scores: Array = []
var customers: MHGolferCustomers = MHGolferCustomers.new()
var practice: MHPracticeRound = null
var _holes: Array = []
var _ratings: Array = []
var _course: Dictionary = {}
var _hole_origins_dm: Array = []


static func create() -> MHGameSession:
	var s: MHGameSession = MHGameSession.new()
	s.defs = MHBuildingDefs.load_default()
	var params: MHEconomyParams = MHEconomyParams.load_default()
	if not s.defs.is_loaded() or not params.is_loaded() or not MHRParams.ensure_loaded():
		return null
	s.economy = MHEconomy.create_from_defs(params, s.defs)
	s.land = MHLandModel.create(s.defs)
	s.staff_defs = MHStaffDefs.load_default()
	s.staff = MHStaff.create(s.staff_defs)
	s.bridge = MHProgressBridge.create()
	if s.economy == null or s.staff == null or not s.bridge.is_ready():
		return null
	s._apply_course()
	s._sync_progress()
	return s


func hole_definitions() -> Array:
	return _holes.duplicate(true)


func hole_origins_dm() -> Array:
	return _hole_origins_dm.duplicate(true)


func set_hole_origins_dm(origins: Array) -> bool:
	if origins.size() != _holes.size():
		return false
	var clean: Array = []
	for value: Variant in origins:
		if typeof(value) != TYPE_ARRAY or (value as Array).size() != 2:
			return false
		var point: Array = value as Array
		if not MHRValidate.is_int_value(point[0]) or not MHRValidate.is_int_value(point[1]):
			return false
		clean.append([int(point[0]), int(point[1])])
	_hole_origins_dm = clean
	return true


func hole_world_points_m() -> Array:
	return MHCourseSpatial.course_points_m(_holes, _hole_origins_dm)


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
	# Staff is the first authoritative live pace contribution; future course-flow pace can add to this.
	return clampi(staff.pace_points(), 0, 100)

func staff_view() -> Dictionary:
	return MHStaffView.make(tiers(), land.owned_ids(), MHStaffView.kinds_from_defs(defs))

func staff_report() -> Dictionary:
	return staff.report(staff_view())

func customer_ids_for_booking(count: int, absolute_hour: int) -> Array:
	# Deterministic permutation over the fixed 128-person public roster. Identity belongs to the session,
	# never to rendering; 29 is coprime with 128 so a batch cannot repeat until the roster wraps.
	var out: Array = []
	var base: int = posmod(absolute_hour * 37 + save_secret, MHGolferCustomers.COUNT)
	for i: int in range(maxi(0, count)):
		out.append(posmod(base + i * 29, MHGolferCustomers.COUNT))
	return out

func customer_summary() -> Dictionary:
	return {"regulars": customers.regular_count(), "eligible": customers.eligible_count(),
		"named_members": customers.member_count(), "membership_capacity": economy.members()}

func accept_customer_membership(customer_id: int) -> bool:
	# The calibrated economy controls membership capacity; the RPG ledger controls who occupies those slots.
	if customers.member_count() >= economy.members():
		return false
	return customers.accept_membership(customer_id)

func record_customer_visit(customer_id: int, holes_played: int, wait_minutes: int) -> Dictionary:
	var report: Dictionary = staff_report()
	var experience: Dictionary = MHGolferExperience.evaluate(economy.rating, economy.fee, economy.suggest_fee(),
		economy.tiers, holes_played, wait_minutes)
	var penalty_pm: int = clampi(int(report.get("satisfaction_penalty_permille", 0)), 0, 1000)
	var condition: int = clampi(100 - penalty_pm / 10, 0, 100)
	experience["condition"] = condition
	experience["condition_penalty_permille"] = penalty_pm
	if penalty_pm > 0:
		experience["score"] = clampi(int(experience["score"]) * (1000 - penalty_pm) / 1000, 0, 100)
		var worst_key: String = str(experience.get("worst", "course"))
		var worst_value: int = int(experience.get(worst_key, 100))
		if condition < worst_value:
			experience["worst"] = "condition"
		experience["reaction"] = MHGolferExperience.reaction(int(experience["score"]), str(experience["best"]),
			"course condition" if str(experience["worst"]) == "condition" else str(experience["worst"]))
	var before: Dictionary = {}
	if customer_id >= 0 and customer_id < MHGolferCustomers.COUNT:
		before = (customers.rows[customer_id] as Dictionary).duplicate(true)
	var after: Dictionary = customers.record_visit(customer_id, int(experience["score"]))
	if after.is_empty():
		return {}
	return {"experience": experience, "before": before, "after": after}


func _club_view() -> Dictionary:
	var g: MHGateView = gate_view()
	return {"holes": g.holes, "avg_hole_score": g.avg_hole_score, "pace_score": pace_score(),
		"staff": staff.gate_staff_count(staff_view()), "tiers": g.tiers}


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
		var hole_rating: Dictionary = v as Dictionary
		if not bool(hole_rating.get("valid", false)):
			# Keep the stable reason code for existing callers, but expose the
			# actual RC/engine errors to Build UI and deterministic smoke tests.
			# Otherwise a perfectly valid schema error (e.g. radius RC006) is
			# indistinguishable from a simulated all-pickup RC007.
			var failure: Dictionary = _result(false, "invalid_rating")
			failure["rating_reasons"] = (hole_rating.get("reasons", []) as Array).duplicate()
			return failure
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
		var handled_hour: int = economy.hour
		var tick: Dictionary = economy.tick_hour()
		var booked: int = int(tick.get("golfers", 0))
		if booked > 0:
			var absolute_hour: int = economy.day * MHEconomy.HOURS_PER_DAY + handled_hour
			# Use the accounting hour boundary, not the frame-end clock: one large advance may process several hours.
			var booked_minute: int = economy.day * MHEconomy.HOURS_PER_DAY * 60 + handled_hour * 60
			golfers_booked.emit(booked, customer_ids_for_booking(booked, absolute_hour), booked_minute)
		var wage: int = staff.pay_hour(handled_hour)
		if wage > 0:
			economy.incur_loss(wage)
		hourly = true
		if bool(tick["day_rolled"]):
			var sv: Dictionary = staff_view()
			staff.on_day(economy.day, sv, save_secret)
			economy.set_demand_modifier(staff.demand_permille(sv))
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
		&"accept_membership":
			out = _result(accept_customer_membership(int(args.get("customer_id", -1))), "membership")
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

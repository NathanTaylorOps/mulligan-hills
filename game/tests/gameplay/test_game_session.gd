extends GdUnitTestSuite
## Integration regressions: clock/accounting boundaries, real UI values and forged purchase arguments.


func test_live_adapter_reads_cents_without_rounding_up() -> void:
	var s: MHGameSession = MHGameSession.create()
	assert_object(s).is_not_null()
	var view: MHLiveGameStateView = MHLiveGameStateView.new(s)
	s.economy.cash = 12399
	assert_int(view.cash()).is_equal(123)
	assert_int(view.tokens_paid()).is_equal(0)
	assert_int(view.hole_count()).is_equal(0)
	assert_int(view.course_score_x10()).is_equal(0)
	assert_int(view.added_daily_income("unknown", 1)).is_equal(0)


func test_hour_boundary_ticks_once_and_pause_does_not_tick() -> void:
	var s: MHGameSession = MHGameSession.create()
	s.clock.set_time(0, 59)
	var saved: Array = []
	s.autosave_requested.connect(func() -> void: saved.append([s.clock.hour_of_day(), s.economy.hour]))
	s.advance(2000000, 20000 * 86400)
	assert_int(s.economy.hour).is_equal(1)
	assert_int(saved.size()).is_equal(1)
	assert_int(int(saved[0][0])).is_equal(int(saved[0][1]))
	var cash: int = s.economy.cash
	s.handle_intent(&"toggle_pause", {})
	s.advance(120000000, 20000 * 86400)
	assert_int(s.economy.hour).is_equal(1)
	assert_int(s.economy.cash).is_equal(cash)
	assert_int(saved.size()).is_equal(1)


func test_day_roll_keeps_clock_and_economy_in_step() -> void:
	var s: MHGameSession = MHGameSession.create()
	for i: int in range(450):
		s.advance(2000000, 20000 * 86400)
	assert_int(s.clock.day()).is_equal(1)
	assert_int(s.economy.day).is_equal(1)
	assert_int(s.economy.hour).is_equal(0)
	assert_int(s.recent_scores.size()).is_equal(1)
	assert_bool(s.ledger.has_key("daily_login", "20000")).is_true()
	var tokens: int = s.ledger.earned
	s.advance(0, 20000 * 86400)
	assert_int(s.ledger.earned).is_equal(tokens)


func test_buy_parcel_ignores_forged_price_and_is_atomic() -> void:
	var s: MHGameSession = MHGameSession.create()
	var parcel: int = s.land.recommended_next()
	var price: int = s.land.next_price() * 100
	var cash: int = s.economy.cash
	var owned: int = s.land.owned_count()
	var result: Dictionary = s.handle_intent(&"buy_parcel", {"parcel": parcel, "price": 0})
	assert_bool(result["ok"]).is_true()
	assert_int(s.economy.cash).is_equal(cash - price)
	assert_int(s.land.owned_count()).is_equal(owned + 1)
	result = s.handle_intent(&"buy_parcel", {"parcel": parcel, "price": -999})
	assert_bool(result["ok"]).is_false()
	assert_int(s.economy.cash).is_equal(cash - price)


func test_unaffordable_parcel_does_not_change_ownership() -> void:
	var s: MHGameSession = MHGameSession.create()
	s.economy.cash = 0
	var owned: int = s.land.owned_count()
	assert_bool(s.handle_intent(&"buy_parcel", {"parcel": s.land.recommended_next()})["ok"]).is_false()
	assert_int(s.land.owned_count()).is_equal(owned)


func test_building_gate_cannot_be_bypassed_by_ui() -> void:
	var s: MHGameSession = MHGameSession.create()
	var cash: int = s.economy.cash
	assert_bool(s.handle_intent(&"buy_tier", {"building": "clubhouse", "tier": 5, "price": 0})["ok"]).is_false()
	assert_int(s.economy.cash).is_equal(cash)
	assert_int(s.economy.tier_of(0)).is_equal(0)


func test_invalid_course_has_no_financial_or_rating_side_effects() -> void:
	var s: MHGameSession = MHGameSession.create()
	var cash: int = s.economy.cash
	assert_bool(s.submit_course([{"slot_id": 0}])["ok"]).is_false()
	assert_int(s.economy.cash).is_equal(cash)
	assert_int(s.hole_results().size()).is_equal(0)


func test_rounded_dead_hole_cannot_unlock_buildings() -> void:
	var s: MHGameSession = MHGameSession.create()
	# Boundary data from the rating contract: display rounding must not decide eligibility.
	s._ratings = [{"valid": true, "score": 25, "score_pm": 249, "dead": true}]
	assert_int(s.gate_view().holes).is_equal(0)
	s._ratings = [{"valid": true, "score": 25, "score_pm": 250, "dead": false}]
	assert_int(s.gate_view().holes).is_equal(1)


func test_small_mandatory_loss_uses_existing_bankruptcy_policy() -> void:
	var s: MHGameSession = MHGameSession.create()
	s.economy.cash = 50
	assert_int(s.economy.incur_loss(100)).is_equal(MHEconomy.OK)
	assert_int(s.economy.cash).is_equal(0)
	assert_int(s.economy.arrears).is_equal(50)
	assert_bool(s.economy.is_bankrupt()).is_false()
	assert_int(s.economy.incur_loss(-1)).is_equal(MHEconomy.ERR_INVALID)
	assert_int(s.economy.arrears).is_equal(50)


func test_official_course_submission_charges_once_and_keeps_slot() -> void:
	var s: MHGameSession = MHGameSession.create()
	var hole: Dictionary = {"slot_id": 0, "tee": [0, 0], "green": [0, 350, 10],
		"features": [{"t": "fairway", "rect": [-40, 0, 40, 350]}]}
	var cash: int = s.economy.cash
	var price: int = s.economy.hole_cost_cents()
	assert_bool(s.submit_course([hole])["ok"]).is_true()
	assert_int(s.economy.cash).is_equal(cash - price)
	assert_int(s.economy.holes).is_equal(1)
	var view: MHLiveGameStateView = MHLiveGameStateView.new(s)
	assert_int(view.hole_count()).is_equal(1)
	assert_bool(view.hole_rating(1)["valid"]).is_true()
	var copy: Array = s.hole_results()
	copy.clear()
	assert_int(view.hole_count()).is_equal(1)
	hole["slot_id"] = 1
	assert_str(str(s.submit_course([hole])["reason"])).is_equal("cannot_demolish")
	assert_int(s.economy.cash).is_equal(cash - price)


func test_recognized_rejected_intent_does_not_fall_through() -> void:
	var s: MHGameSession = MHGameSession.create()
	s.economy.bankrupt = true
	var rejected: Dictionary = s.handle_intent(&"tournament_host", {"level": "local"})
	assert_bool(rejected["handled"]).is_true()
	assert_bool(rejected["ok"]).is_false()
	assert_str(str(rejected["reason"])).is_equal("recovery")
	assert_bool(s.handle_intent(&"not_a_game_intent", {})["handled"]).is_false()

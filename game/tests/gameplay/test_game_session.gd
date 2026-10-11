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
	assert_int(s.economy.hour).is_equal(0)
	s.advance(1000000, 20000 * 86400)
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
	for i: int in range(750):
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
	s.clock.pause()
	var hole: Dictionary = {"slot_id": 0, "tee": [0, 0], "green": [0, 350, 10],
		"features": [{"t": "fairway", "rect": [-40, 0, 40, 350]}]}
	var cash: int = s.economy.cash
	var price: int = s.economy.hole_cost_cents()
	assert_bool(s.submit_course([hole])["ok"]).is_true()
	assert_bool(s.clock.is_paused()).is_true()
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


func test_bank_loan_reports_success_and_preserves_no_cash_token_rule() -> void:
	var s: MHGameSession = MHGameSession.create()
	s.economy.arrears = 1000000
	s.economy.bankrupt = true
	var before: int = s.economy.loan_balance
	assert_bool(s.handle_intent(&"recovery_loan", {})["ok"]).is_true()
	assert_int(s.economy.loan_balance).is_greater(before)
	assert_bool(s.handle_intent(&"recovery_loan", {})["ok"]).is_false()


func test_live_editor_history_works_while_clock_paused() -> void:
	var s: MHGameSession = MHGameSession.create()
	s.clock.pause()
	var editor: MHTerrainEditor = MHTerrainEditor.new(MHHeightGrid.new(16, 16, 1000))
	var v: MHLiveGameStateView = MHLiveGameStateView.new(s)
	v.editor = editor
	var sink: MHLiveTerrainSink = MHLiveTerrainSink.new(editor)
	assert_bool(v.can_undo()).is_false()
	sink.begin_stroke()
	sink.apply_brush_at(8, 8)
	sink.apply_brush_at(10, 8)
	assert_bool(v.can_undo()).is_false()
	sink.end_stroke()
	assert_bool(v.can_undo()).is_true()
	assert_bool(editor.undo()).is_true()
	assert_bool(v.can_redo()).is_true()
	assert_bool(editor.redo()).is_true()
	assert_bool(s.clock.is_paused()).is_true()
	assert_int(s.clock.total_minutes()).is_equal(0)


func test_router_suppression_clears_latched_mouse_and_touch_state() -> void:
	var router: MHInputRouter = auto_free(MHInputRouter.new())
	router.machine = MHGestureStateMachine.new()
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	router._input(press)
	assert_int(router._mouse_mode).is_equal(MHInputRouter.MouseMode.ROTATE)
	router._ui_touches[0] = &"old"
	router._ui_mouse_region = &"old"
	router.accept_world_input = false
	press.pressed = false
	router._input(press)
	assert_int(router._mouse_mode).is_equal(MHInputRouter.MouseMode.NONE)
	assert_int(router._ui_touches.size()).is_equal(0)
	assert_str(str(router._ui_mouse_region)).is_equal("")
	router.accept_world_input = true
	router.world_input_allowed = func() -> bool: return false
	press.pressed = true
	router._input(press)
	assert_int(router._mouse_mode).is_equal(MHInputRouter.MouseMode.NONE)


func test_booking_identity_batch_is_unique_and_bounded_to_roster() -> void:
	var s: MHGameSession = MHGameSession.create()
	var ids: Array = s.customer_ids_for_booking(MHGolferCustomers.COUNT + 50, 17)
	assert_int(ids.size()).is_equal(MHGolferCustomers.COUNT)
	var seen: Dictionary = {}
	for value: Variant in ids:
		var id: int = int(value)
		assert_bool(id >= 0 and id < MHGolferCustomers.COUNT).is_true()
		assert_bool(seen.has(id)).is_false()
		seen[id] = true
	assert_int(s.customer_ids_for_booking(-4, 17).size()).is_equal(0)


func test_accepted_named_member_is_floor_for_declining_aggregate_membership() -> void:
	var s: MHGameSession = MHGameSession.create()
	var row: Dictionary = s.customers.rows[0] as Dictionary
	row["visits"] = MHGolferCustomers.REGULAR_VISITS + MHGolferCustomers.MEMBER_EXTRA_VISITS
	row["satisfaction"] = MHGolferCustomers.MEMBER_MIN_SAT
	row["regular"] = true
	row["member_eligible"] = true
	row["good_member_visits"] = MHGolferCustomers.MEMBER_EXTRA_VISITS
	s.economy.members_milli = 1000
	assert_bool(s.accept_customer_membership(0)).is_true()
	assert_int(s.customers.member_count()).is_equal(1)

	# The aggregate model is allowed to decline toward a lower target, but cannot erase an accepted person.
	s.economy.members_milli = MHEconomyModel.step_members_milli(s.economy.params, s.economy.members_milli, 0)
	assert_int(s.economy.members_milli).is_less(1000)
	s._reconcile_named_membership_floor()
	assert_int(s.economy.members_milli).is_equal(1000)


func test_invalid_customer_visit_is_rejected_without_mutating_ledger() -> void:
	var s: MHGameSession = MHGameSession.create()
	var before: Dictionary = s.customers.to_dict()
	assert_dict(s.record_customer_visit(-1, 3, 0)).is_empty()
	assert_dict(s.record_customer_visit(MHGolferCustomers.COUNT, 3, 0)).is_empty()
	assert_dict(s.customers.to_dict()).is_equal(before)

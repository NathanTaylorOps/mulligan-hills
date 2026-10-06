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


func test_live_session_exposes_staff_assignment_firing_and_equipment_sale() -> void:
	var s: MHGameSession = MHGameSession.create()
	var hired: Dictionary = s.hire_staff("groundskeeper")
	assert_bool(bool(hired["ok"])).is_true()
	var employee_serial: int = int(hired["serial"])
	var assignment: Dictionary = s.assign_staff(employee_serial, [0])
	assert_bool(bool(assignment["ok"])).is_true()
	assert_array((s.staff_system.roster.employee(employee_serial)["areas"] as Array)).is_equal([0])

	var bought: Dictionary = s.staff_system.equipment.add_unit("greens_mower")
	var equipment_serial: int = int(bought["serial"])
	assert_bool(s.assign_staff_equipment(equipment_serial, employee_serial)).is_true()
	assert_int(int((s.staff_system.equipment.units[0] as Dictionary)["assigned_employee"])).is_equal(employee_serial)
	assert_bool(s.fire_staff(employee_serial)).is_true()
	assert_int(int((s.staff_system.equipment.units[0] as Dictionary)["assigned_employee"])).is_equal(0)

	var cash_before_sale: int = s.economy.cash
	var expected_value: int = s.staff_system.equipment.sale_value(equipment_serial)
	var sold: Dictionary = s.sell_staff_equipment(equipment_serial)
	assert_bool(bool(sold["ok"])).is_true()
	assert_int(int(sold["value"])).is_equal(expected_value)
	assert_int(s.economy.cash).is_equal(cash_before_sale + expected_value)
	assert_int(s.staff_system.equipment.units.size()).is_equal(0)


func test_customer_satisfaction_feels_course_condition_without_changing_rating() -> void:
	var cared: MHGameSession = MHGameSession.create()
	var neglected: MHGameSession = MHGameSession.create()
	var hole: Dictionary = {"slot_id": 0, "tee": [0, 0], "green": [0, 60, 5],
		"features": [{"t": "fairway", "rect": [-8, 0, 8, 60]}]}
	assert_bool(bool(cared.submit_course([hole])["ok"])).is_true()
	assert_bool(bool(neglected.submit_course([hole])["ok"])).is_true()
	var cared_rating: Dictionary = cared.hole_results()[0]
	var neglected_rating: Dictionary = neglected.hole_results()[0]
	for parcel: int in range(MHStaffDefs.NPARCELS):
		if MHStaffView.is_owned(neglected.staff_view(), parcel) and MHStaffView.kind_of(neglected.staff_view(), parcel) == "golf":
			neglected.staff_system.grounds.condition[parcel] = 250
	var identity_a: Dictionary = cared.golfer_roster.identity_for_admission(cared.save_secret, 51, 0)
	var identity_b: Dictionary = identity_a.duplicate(true)
	cared._pending_customers = [{"serial": 51, "identity": identity_a, "hole_slot": 0}]
	neglected.golfer_roster.golfers[int(identity_b["id"])] = identity_b.duplicate(true)
	neglected.golfer_roster.next_id = maxi(neglected.golfer_roster.next_id, int(identity_b["id"]) + 1)
	neglected._pending_customers = [{"serial": 51, "identity": identity_b, "hole_slot": 0}]
	cared._resolve_customer_hour()
	neglected._resolve_customer_hour()
	assert_dict(cared.hole_results()[0]).is_equal(cared_rating)
	assert_dict(neglected.hole_results()[0]).is_equal(neglected_rating)
	assert_int(int((cared.customer_outcomes[0] as Dictionary)["condition_penalty"])).is_equal(0)
	assert_bool(int((neglected.customer_outcomes[0] as Dictionary)["condition_penalty"]) > 0).is_true()
	assert_bool(int((cared.customer_outcomes[0] as Dictionary)["satisfaction"]) >
		int((neglected.customer_outcomes[0] as Dictionary)["satisfaction"])).is_true()

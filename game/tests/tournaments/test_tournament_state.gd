extends GdUnitTestSuite
## MHTournamentState: the calendar state machine, cooldown, cancel, persistence. NOT YET RUN in Godot.


func _defs() -> MHTournamentDefs:
	return MHTournamentFixture.defs()


func _start_local(st: MHTournamentState, day: int, cash: int = 30000) -> Dictionary:
	return st.start(_defs(), "local", day, MHTournamentFixture.local_view(), cash, true, 40)


func _result(success: bool, level_id: String = "local") -> Dictionary:
	return {"level": level_id, "success": success, "cooldown_days": 10 if success else 15}


func test_fresh_state_is_idle() -> void:
	var st: MHTournamentState = MHTournamentState.new()
	assert_bool(st.is_active()).is_false()
	assert_bool(st.course_locked()).is_false()
	assert_str(st.highest_hosted_level()).is_equal("")
	assert_bool(st.has_hosted_at_least("local")).is_false()
	assert_int(st.event_id()).is_equal(-1)
	assert_int(st.resolve_day(_defs())).is_equal(-1)
	assert_bool(st.advance(_defs(), 50)).is_false()
	assert_str(st.status_for(_defs(), "local", 0, MHTournamentFixture.local_view())).is_equal("available")
	assert_str(st.status_for(_defs(), "local", 0, {})).is_equal("locked")


func test_start_takes_cost_and_locks_the_course() -> void:
	var st: MHTournamentState = MHTournamentState.new()
	var r: Dictionary = _start_local(st, 100)
	assert_bool(bool(r["ok"])).is_true()
	assert_int(int(r["cost"])).is_equal(25000)
	assert_int(int(r["event_id"])).is_equal(400)
	assert_bool(st.is_active()).is_true()
	assert_bool(st.course_locked()).is_true()
	assert_str(str(st.active["status"])).is_equal("preparing")
	assert_int(int(st.active["snapshot_score"])).is_equal(40)
	assert_int(st.resolve_day(_defs())).is_equal(104)
	assert_str(st.status_for(_defs(), "local", 100, MHTournamentFixture.local_view())).is_equal("active")
	assert_str(st.status_for(_defs(), "regional", 100, MHTournamentFixture.strong_view())).is_equal("locked")


func test_start_refusals_in_order() -> void:
	var st: MHTournamentState = MHTournamentState.new()
	var d: MHTournamentDefs = _defs()
	var view: Dictionary = MHTournamentFixture.local_view()
	assert_str(str(st.start(d, "nope", 0, view, 99999, true, 40)["reason"])).is_equal("unknown_level")
	assert_str(str(st.start(d, "local", 0, view, 99999, false, 40)["reason"])).is_equal("disabled")
	assert_str(str(st.start(d, "local", 0, {}, 99999, true, 40)["reason"])).is_equal("locked")
	assert_str(str(st.start(d, "local", 0, view, 24999, true, 40)["reason"])).is_equal("cash")
	assert_bool(st.is_active()).is_false()
	assert_bool(bool(st.start(d, "local", 0, view, 25000, true, 40)["ok"])).is_true()
	assert_str(str(st.start(d, "local", 1, view, 99999, true, 40)["reason"])).is_equal("busy")


func test_phases_over_the_days() -> void:
	var st: MHTournamentState = MHTournamentState.new()
	_start_local(st, 100)
	var d: MHTournamentDefs = _defs()
	assert_bool(st.advance(d, 101)).is_false()
	assert_str(str(st.active["status"])).is_equal("preparing")
	assert_bool(st.advance(d, 102)).is_false()
	assert_bool(st.advance(d, 103)).is_false()
	assert_str(str(st.active["status"])).is_equal("running")
	assert_bool(st.advance(d, 104)).is_true()
	assert_bool(st.course_locked()).is_true()


func test_finish_before_ready_is_refused() -> void:
	var st: MHTournamentState = MHTournamentState.new()
	_start_local(st, 100)
	var d: MHTournamentDefs = _defs()
	assert_bool(st.finish(d, 103, _result(true))).is_false()
	assert_bool(st.finish(d, 104, _result(true, "regional"))).is_false()
	assert_int(st.hosted_count).is_equal(0)
	assert_bool(st.finish(d, 104, _result(true))).is_true()


func test_success_records_level_cooldown_and_counts() -> void:
	var st: MHTournamentState = MHTournamentState.new()
	_start_local(st, 100)
	assert_bool(st.finish(_defs(), 104, _result(true))).is_true()
	assert_str(str(st.active["status"])).is_equal("done")
	assert_bool(st.course_locked()).is_false()
	assert_int(st.hosted_count).is_equal(1)
	assert_int(st.attempted_count).is_equal(1)
	assert_str(st.highest_hosted_level()).is_equal("local")
	assert_bool(st.has_hosted_at_least("local")).is_true()
	assert_bool(st.has_hosted_at_least("regional")).is_false()
	assert_int(st.cooldown_until_day).is_equal(114)
	assert_bool(st.in_cooldown(113)).is_true()
	assert_bool(st.in_cooldown(114)).is_false()
	assert_int(st.cooldown_days_left(110)).is_equal(4)
	assert_bool(bool(st.last_result["success"])).is_true()
	# still busy until the result is acknowledged
	assert_str(str(st.can_start(_defs(), "local", 120, MHTournamentFixture.local_view(), 99999, true)["reason"])).is_equal("busy")
	st.acknowledge()
	assert_bool(st.is_active()).is_false()
	assert_str(str(st.can_start(_defs(), "local", 113, MHTournamentFixture.local_view(), 99999, true)["reason"])).is_equal("cooldown")
	assert_str(st.status_for(_defs(), "local", 113, MHTournamentFixture.local_view())).is_equal("cooldown")
	assert_bool(bool(st.can_start(_defs(), "local", 114, MHTournamentFixture.local_view(), 99999, true)["ok"])).is_true()


func test_failure_counts_as_attempt_not_as_hosted() -> void:
	var st: MHTournamentState = MHTournamentState.new()
	_start_local(st, 10)
	assert_bool(st.finish(_defs(), 14, _result(false))).is_true()
	assert_str(str(st.active["status"])).is_equal("failed")
	assert_int(st.hosted_count).is_equal(0)
	assert_int(st.attempted_count).is_equal(1)
	assert_str(st.highest_hosted_level()).is_equal("")
	assert_int(st.cooldown_until_day).is_equal(29)
	assert_bool(st.has_hosted("local")).is_false()


func test_acknowledge_does_nothing_while_running() -> void:
	var st: MHTournamentState = MHTournamentState.new()
	_start_local(st, 10)
	st.acknowledge()
	assert_bool(st.is_active()).is_true()


func test_cancel_only_while_preparing_and_refunds_half() -> void:
	var d: MHTournamentDefs = _defs()
	var st: MHTournamentState = MHTournamentState.new()
	_start_local(st, 100)
	var r: Dictionary = st.cancel(d, 102)
	assert_bool(bool(r["ok"])).is_true()
	assert_int(int(r["refund"])).is_equal(12500)
	assert_bool(st.is_active()).is_false()
	assert_int(st.attempted_count).is_equal(0)
	assert_int(st.cooldown_until_day).is_equal(0)
	_start_local(st, 200)
	assert_bool(bool(st.cancel(d, 203)["ok"])).is_false()
	st.advance(d, 203)
	assert_bool(bool(st.cancel(d, 203)["ok"])).is_false()
	assert_bool(st.is_active()).is_true()
	assert_bool(bool(MHTournamentState.new().cancel(d, 5)["ok"])).is_false()


func test_hosting_regional_satisfies_the_local_gate_for_tier_five() -> void:
	var st: MHTournamentState = MHTournamentState.new()
	var d: MHTournamentDefs = _defs()
	var view: Dictionary = MHTournamentFixture.strong_view()
	var r: Dictionary = st.start(d, "regional", 0, view, 99999, true, 60)
	assert_bool(bool(r["ok"])).is_true()
	assert_bool(st.finish(d, 6, _result(true, "regional"))).is_true()
	assert_bool(st.has_hosted_at_least("local")).is_true()
	assert_bool(st.has_hosted_at_least("regional")).is_true()
	assert_bool(st.has_hosted_at_least("national")).is_false()
	assert_bool(st.has_hosted_at_least("junk")).is_false()


func test_gate_view_hosted_level_feeds_unlock_rules() -> void:
	var st: MHTournamentState = MHTournamentState.new()
	_start_local(st, 0)
	st.finish(_defs(), 4, _result(true))
	var gv: MHGateView = MHGateView.new()
	gv.hosted_level = st.highest_hosted_level()
	assert_int(MHBuildingDefs.level_rank(gv.hosted_level)).is_equal(1)


func test_full_loop_with_simulated_outcome() -> void:
	var d: MHTournamentDefs = _defs()
	var st: MHTournamentState = MHTournamentState.new()
	var started: Dictionary = _start_local(st, 100)
	var ctx: Dictionary = MHTournamentFixture.golden_ctx(MHTournamentSim.event_seed(1234, int(started["event_id"]), 1))
	ctx["snapshot_score"] = int(st.active["snapshot_score"])
	assert_bool(st.advance(d, st.resolve_day(d))).is_true()
	var res: Dictionary = MHTournamentSim.evaluate(d, "local", ctx)
	assert_bool(st.finish(d, st.resolve_day(d), res)).is_true()
	assert_int(st.attempted_count).is_equal(1)
	assert_int(st.hosted_count).is_equal(1 if bool(res["success"]) else 0)


func test_save_block_round_trip_matches_schema_shape() -> void:
	var st: MHTournamentState = MHTournamentState.new()
	_start_local(st, 100)
	st.advance(_defs(), 103)
	var blk: Dictionary = st.to_save_block()
	assert_int(blk.size()).is_equal(5)
	assert_bool(blk.has("hosted_levels")).is_true()
	assert_int(int(blk["hosted_count"])).is_equal(0)
	assert_int(int(blk["attempted_count"])).is_equal(0)
	assert_int(int(blk["cooldown_until_day"])).is_equal(0)
	var act: Dictionary = blk["active"]
	assert_str(str(act["level"])).is_equal("local")
	assert_int(int(act["start_day"])).is_equal(100)
	assert_str(str(act["status"])).is_equal("running")
	var st2: MHTournamentState = MHTournamentState.new()
	assert_bool(st2.from_save_block(blk)).is_true()
	assert_str(str(st2.active["status"])).is_equal("running")
	assert_bool(st2.course_locked()).is_true()
	# idle state has no "active" key
	assert_bool(MHTournamentState.new().to_save_block().has("active")).is_false()


func test_dict_round_trip_keeps_counters() -> void:
	var st: MHTournamentState = MHTournamentState.new()
	_start_local(st, 100)
	st.finish(_defs(), 104, _result(true))
	st.acknowledge()
	_start_local(st, 130)
	st.finish(_defs(), 134, _result(false))
	var d: Dictionary = st.to_dict()
	var st2: MHTournamentState = MHTournamentState.new()
	assert_bool(st2.from_dict(d)).is_true()
	assert_int(st2.hosted_count).is_equal(1)
	assert_int(st2.attempted_count).is_equal(2)
	assert_int(st2.cooldown_until_day).is_equal(st.cooldown_until_day)
	assert_str(st2.highest_hosted_level()).is_equal("local")
	assert_str(str(st2.active["status"])).is_equal("failed")
	# JSON round trip turns ints into floats; the loader must accept whole floats
	var parsed: Variant = JSON.parse_string(JSON.stringify(d))
	var st3: MHTournamentState = MHTournamentState.new()
	assert_bool(st3.from_dict(parsed as Dictionary)).is_true()
	assert_int(st3.attempted_count).is_equal(2)


func test_bad_blocks_are_rejected_without_changes() -> void:
	var st: MHTournamentState = MHTournamentState.new()
	_start_local(st, 100)
	var good: Dictionary = st.to_save_block()
	var other: MHTournamentState = MHTournamentState.new()
	assert_bool(other.from_save_block({"hosted_levels": ["galactic"], "cooldown_until_day": 0})).is_false()
	assert_bool(other.from_save_block({"hosted_levels": ["local", "local"], "cooldown_until_day": 0})).is_false()
	assert_bool(other.from_save_block({"hosted_levels": [], "cooldown_until_day": -1})).is_false()
	assert_bool(other.from_save_block({"hosted_levels": [], "cooldown_until_day": 1.5})).is_false()
	assert_bool(other.from_save_block({"hosted_levels": [], "cooldown_until_day": 0, "active": {"level": "local", "start_day": 1, "snapshot_score": 101, "status": "preparing"}})).is_false()
	assert_bool(other.from_save_block({"hosted_levels": [], "cooldown_until_day": 0, "active": {"level": "local", "start_day": 1, "snapshot_score": 5, "status": "weird"}})).is_false()
	assert_bool(other.is_active()).is_false()
	assert_int(other.hosted_levels.size()).is_equal(0)
	assert_bool(other.from_save_block(good)).is_true()
	assert_bool(other.from_dict({"v": 99})).is_false()
	assert_bool(other.is_active()).is_true()


func test_hosted_levels_are_kept_in_ladder_order() -> void:
	var st: MHTournamentState = MHTournamentState.new()
	assert_bool(st.from_save_block({"hosted_levels": ["national", "local"], "cooldown_until_day": 0})).is_true()
	assert_str(str(st.hosted_levels[0])).is_equal("local")
	assert_str(str(st.hosted_levels[1])).is_equal("national")
	assert_str(st.highest_hosted_level()).is_equal("national")
	# counters are raised to match the block
	assert_int(st.hosted_count).is_equal(2)
	assert_int(st.attempted_count).is_equal(2)


func test_save_block_carries_the_counters() -> void:
	var st: MHTournamentState = MHTournamentState.new()
	_start_local(st, 100)
	st.finish(_defs(), 104, _result(true))
	st.acknowledge()
	_start_local(st, 130)
	st.finish(_defs(), 134, _result(false))
	st.acknowledge()
	var blk: Dictionary = st.to_save_block()
	assert_int(int(blk["hosted_count"])).is_equal(1)
	assert_int(int(blk["attempted_count"])).is_equal(2)
	var st2: MHTournamentState = MHTournamentState.new()
	assert_bool(st2.from_save_block(blk)).is_true()
	assert_int(st2.hosted_count).is_equal(1)
	assert_int(st2.attempted_count).is_equal(2)
	# JSON round trip (whole floats)
	var parsed: Variant = JSON.parse_string(JSON.stringify(blk))
	var st3: MHTournamentState = MHTournamentState.new()
	assert_bool(st3.from_save_block(parsed as Dictionary)).is_true()
	assert_int(st3.attempted_count).is_equal(2)


func test_old_block_without_counters_keeps_current_counters_and_bad_counters_are_refused() -> void:
	var st: MHTournamentState = MHTournamentState.new()
	st.hosted_count = 3
	st.attempted_count = 5
	assert_bool(st.from_save_block({"hosted_levels": ["local"], "cooldown_until_day": 0})).is_true()
	assert_int(st.hosted_count).is_equal(3)
	assert_int(st.attempted_count).is_equal(5)
	var other: MHTournamentState = MHTournamentState.new()
	assert_bool(other.from_save_block({"hosted_levels": [], "cooldown_until_day": 0, "hosted_count": -1})).is_false()
	assert_bool(other.from_save_block({"hosted_levels": [], "cooldown_until_day": 0, "attempted_count": 1.5})).is_false()
	assert_int(other.hosted_count).is_equal(0)
	# a count below what the levels imply is raised
	assert_bool(other.from_save_block({"hosted_levels": ["local", "regional"], "cooldown_until_day": 0, "hosted_count": 0, "attempted_count": 0})).is_true()
	assert_int(other.hosted_count).is_equal(2)
	assert_int(other.attempted_count).is_equal(2)


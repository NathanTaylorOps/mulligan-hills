extends GdUnitTestSuite
## Adapter contract: MHGameStateView (read-only) and MHFakeGameStateView (sample data). NOT YET RUN.

const PREFIXES_FORBIDDEN: Array = ["set_", "buy_", "spend_", "earn_", "add_", "remove_", "delete_", "purchase", "grant_", "save_", "load_"]


func _method_names(script: Script) -> Array:
	var out: Array = []
	for m: Dictionary in script.get_script_method_list():
		out.append(str(m["name"]))
	return out


func test_base_class_is_read_only() -> void:
	var base: MHGameStateView = MHGameStateView.new()
	for n: Variant in _method_names(base.get_script()):
		var mname: String = str(n)
		for p: Variant in PREFIXES_FORBIDDEN:
			assert_bool(mname.begins_with(str(p))).override_failure_message("mutating method on the read-only view: " + mname).is_false()


func test_fake_adds_only_sample_or_private_methods() -> void:
	var fake: MHFakeGameStateView = MHFakeGameStateView.new()
	var base_names: Array = _method_names(MHGameStateView.new().get_script())
	for n: Variant in _method_names(fake.get_script()):
		var mname: String = str(n)
		var ok: bool = mname.begins_with("_") or mname.begins_with("sample_") or base_names.has(mname)
		assert_bool(ok).override_failure_message("fake exposes a non-contract method: " + mname).is_true()


func test_base_defaults_are_safe() -> void:
	var v: MHGameStateView = MHGameStateView.new()
	assert_int(v.cash()).is_equal(0)
	assert_int(v.tokens_total()).is_equal(0)
	assert_int(v.hole_count()).is_equal(0)
	assert_bool(v.hole_rating(1).is_empty()).is_true()
	assert_bool(v.building_defs() == null).is_true()
	assert_bool(v.land() == null).is_true()
	assert_bool(v.gate_view() != null).is_true()
	assert_bool(bool(v.daily_challenge()["enabled"])).is_false()
	assert_bool(bool(v.recovery_offer()["active"])).is_false()
	assert_int(v.tournaments().size()).is_equal(0)
	assert_int(MHBuildMenuModel.rows(v).size()).is_equal(0)


func test_fake_scalar_ranges() -> void:
	var v: MHFakeGameStateView = MHFakeGameStateView.new()
	assert_bool(v.cash() >= 0).is_true()
	assert_bool(v.day() >= 0).is_true()
	assert_bool(v.minute_of_day() >= 0 and v.minute_of_day() < MHFormat.DAY_MINUTES).is_true()
	assert_bool(MHGameStateView.SPEEDS.has(v.speed())).is_true()
	assert_int(v.tokens_total()).is_equal(v.tokens_earned() + v.tokens_paid())
	assert_bool(v.course_score_x10() >= 0 and v.course_score_x10() <= 1000).is_true()
	assert_int(v.hole_count()).is_equal(v.hole_scores().size())
	assert_str(v.club_name()).is_not_empty()


func test_fake_sample_numbers() -> void:
	var v: MHFakeGameStateView = MHFakeGameStateView.new()
	assert_int(v.hole_count()).is_equal(7)
	assert_int(v.course_score_x10()).is_equal(461)
	var g: MHGateView = v.gate_view()
	assert_int(g.holes).is_equal(6)
	assert_int(g.avg_hole_score).is_equal(46)
	assert_int(g.parcels_owned).is_equal(5)
	assert_int(g.tier_of("clubhouse")).is_equal(1)


func test_hole_rating_rows() -> void:
	var v: MHFakeGameStateView = MHFakeGameStateView.new()
	for h: int in range(1, v.hole_count() + 1):
		var r: Dictionary = v.hole_rating(h)
		for key: String in ["hole_no", "par", "length_yd", "valid", "dead", "score_pm", "accuracy_pm", "imagination_pm", "length_pm", "beauty_pm", "fairness_pm", "reasons"]:
			assert_bool(r.has(key)).override_failure_message("hole %d missing %s" % [h, key]).is_true()
		assert_int(int(r["hole_no"])).is_equal(h)
		for axis: String in ["score_pm", "accuracy_pm", "imagination_pm", "length_pm", "beauty_pm", "fairness_pm"]:
			assert_bool(int(r[axis]) >= 0 and int(r[axis]) <= 1000).is_true()
		for reason: Variant in r["reasons"]:
			var rd: Dictionary = reason
			for rk: String in ["code", "severity", "a", "b"]:
				assert_bool(rd.has(rk)).is_true()
	assert_bool(v.hole_rating(0).is_empty()).is_true()
	assert_bool(v.hole_rating(99).is_empty()).is_true()
	assert_bool(bool(v.hole_rating(7)["dead"])).is_true()
	assert_bool(bool(v.hole_rating(1)["dead"])).is_false()


func test_gate_view_is_a_copy() -> void:
	var v: MHFakeGameStateView = MHFakeGameStateView.new()
	var g: MHGateView = v.gate_view()
	g.tiers["clubhouse"] = 5
	g.holes = 99
	assert_int(v.tier_of("clubhouse")).is_equal(1)
	assert_int(v.gate_view().holes).is_equal(6)


func test_catalogue_land_and_income() -> void:
	var v: MHFakeGameStateView = MHFakeGameStateView.new()
	assert_bool(v.building_defs().is_loaded()).is_true()
	assert_bool(v.land() != null).is_true()
	assert_int(v.land().owned_count()).is_equal(5)
	assert_int(v.land().hole_capacity()).is_equal(6)
	assert_int(v.added_daily_income("clubhouse", 1)).is_equal(900)
	assert_int(v.added_daily_income("clubhouse", 2)).is_equal(1800)
	assert_int(v.added_daily_income("clubhouse", 0)).is_equal(0)
	assert_int(v.added_daily_income("clubhouse", 6)).is_equal(0)
	assert_int(v.added_daily_income("nope", 1)).is_equal(0)


func test_challenge_tournament_achievement_rows() -> void:
	var v: MHFakeGameStateView = MHFakeGameStateView.new()
	var d: Dictionary = v.daily_challenge()
	for key: String in ["enabled", "title_key", "desc_key", "attempts_left", "attempts_total", "target_score", "best_score", "streak_days", "ends_in_minutes", "board"]:
		assert_bool(d.has(key)).is_true()
	assert_int(v.tournaments().size()).is_equal(4)
	for t: Variant in v.tournaments():
		var td: Dictionary = t
		for key2: String in ["level", "status", "host_cost", "reward_cash", "reward_reputation", "cooldown_days", "rows"]:
			assert_bool(td.has(key2)).is_true()
		for row: Variant in td["rows"]:
			assert_int((row as Array).size()).is_equal(4)
	assert_bool(v.achievements().size() > 0).is_true()
	for a: Variant in v.achievements():
		var ad: Dictionary = a
		for key3: String in ["id", "category", "tier", "points", "hidden", "earned", "progress", "target"]:
			assert_bool(ad.has(key3)).is_true()
	for key4: String in ["active", "shortfall", "loan_amount", "reputation_penalty", "token_cost"]:
		assert_bool(v.recovery_offer().has(key4)).is_true()
	assert_bool(v.store_products().size() > 0).is_true()


func test_changed_signal_fires_on_sample_edits() -> void:
	var v: MHFakeGameStateView = MHFakeGameStateView.new()
	var hits: Array = [0]
	v.changed.connect(func() -> void: hits[0] = int(hits[0]) + 1)
	v.sample_set_cash(500)
	v.sample_set_tokens(1, 2)
	v.sample_set_demo(false)
	assert_int(int(hits[0])).is_equal(3)
	assert_int(v.cash()).is_equal(500)
	assert_int(v.tokens_total()).is_equal(3)
	assert_bool(v.is_demo()).is_false()

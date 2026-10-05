extends GdUnitTestSuite
## MHTournamentRules: entry checklist, snapshot score, facility points, prestige, purse. NOT YET RUN in Godot.


func test_exact_local_requirements_are_eligible() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	var rep: MHGateReport = MHTournamentRules.entry_report(d, "local", MHTournamentFixture.local_view())
	assert_bool(rep.met).is_true()
	assert_int(rep.rows.size()).is_equal(8)
	assert_bool(rep.row_met("holes")).is_true()
	assert_bool(rep.row_met("building:clubhouse")).is_true()
	assert_bool(rep.row_met("spectators")).is_true()


func test_each_missing_requirement_is_reported() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	var view: Dictionary = MHTournamentFixture.local_view()
	view["holes"] = 9
	view["pace_score"] = 49
	view["staff"] = 3
	view["tiers"] = {"clubhouse": 2, "cart_barn": 2, "maintenance": 1}
	var rep: MHGateReport = MHTournamentRules.entry_report(d, "local", view)
	assert_bool(rep.met).is_false()
	var missing: PackedStringArray = rep.missing_keys()
	assert_bool(missing.has("holes")).is_true()
	assert_bool(missing.has("pace_score")).is_true()
	assert_bool(missing.has("staff")).is_true()
	assert_bool(missing.has("building:clubhouse")).is_true()
	assert_bool(missing.has("building:maintenance")).is_true()
	assert_bool(missing.has("building:cart_barn")).is_false()
	# clubhouse tier 2 holds 150 spectators? tier 2 is index 1 = 50, so spectators are short as well
	assert_bool(missing.has("spectators")).is_true()
	assert_bool(missing.has("avg_hole_score")).is_false()


func test_row_shape_matches_gate_report() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	var rep: MHGateReport = MHTournamentRules.entry_report(d, "local", {})
	for r: Variant in rep.rows:
		var row: Array = r
		assert_int(row.size()).is_equal(4)
		assert_bool(typeof(row[0]) == TYPE_STRING).is_true()
		assert_bool(typeof(row[1]) == TYPE_BOOL).is_true()
	assert_bool(rep.met).is_false()


func test_unknown_level_never_eligible() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	var rep: MHGateReport = MHTournamentRules.entry_report(d, "world_cup", MHTournamentFixture.strong_view())
	assert_bool(rep.met).is_false()
	assert_bool(rep.row_met("unknown_level")).is_false()


func test_highest_eligible_level() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	assert_str(MHTournamentRules.highest_eligible_level(d, {})).is_equal("")
	assert_str(MHTournamentRules.highest_eligible_level(d, MHTournamentFixture.local_view())).is_equal("local")
	assert_str(MHTournamentRules.highest_eligible_level(d, MHTournamentFixture.strong_view())).is_equal("major")


func test_tier_five_clubhouse_gives_spectators_but_requirements_stay_tier_four() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	var view: Dictionary = MHTournamentFixture.strong_view()
	# tier 5 buildings are never asked for, so a tier 4 club is already complete
	assert_bool(MHTournamentRules.entry_report(d, "major", view).met).is_true()


func test_snapshot_score_needs_history() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	var short: Array = []
	for _i: int in range(9):
		short.append(50)
	assert_int(MHTournamentRules.snapshot_score(d, short)).is_equal(0)
	short.append(50)
	assert_int(MHTournamentRules.snapshot_score(d, short)).is_equal(50)


func test_snapshot_score_is_min_of_latest_and_median() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	# 14 days at 40 then a last-day makeover to 90: the median holds the score down
	var scores: Array = []
	for _i: int in range(14):
		scores.append(40)
	scores.append(90)
	assert_int(MHTournamentRules.snapshot_score(d, scores)).is_equal(40)
	# a bad last day lowers it
	var scores2: Array = []
	for _j: int in range(14):
		scores2.append(60)
	scores2.append(20)
	assert_int(MHTournamentRules.snapshot_score(d, scores2)).is_equal(20)


func test_snapshot_score_uses_only_the_window() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	var scores: Array = []
	for _i: int in range(30):
		scores.append(10)
	for _j: int in range(14):
		scores.append(55)
	assert_int(MHTournamentRules.snapshot_score(d, scores)).is_equal(55)


func test_snapshot_score_clamps_and_even_window_uses_lower_median() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	var scores: Array = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
	# 10 values, lower median is sorted[4] = 50, latest 100 -> 50
	assert_int(MHTournamentRules.snapshot_score(d, scores)).is_equal(50)
	var wild: Array = [500, 500, 500, 500, 500, 500, 500, 500, 500, 500]
	assert_int(MHTournamentRules.snapshot_score(d, wild)).is_equal(100)


func test_facility_permille_caps_at_tier_four() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	assert_int(MHTournamentRules.facility_permille(d, {})).is_equal(0)
	var full: Dictionary = {"clubhouse": 4, "restaurant": 4, "pro_shop": 4, "cart_barn": 4, "maintenance": 4}
	assert_int(MHTournamentRules.facility_permille(d, full)).is_equal(1000)
	var five: Dictionary = {"clubhouse": 5, "restaurant": 5, "pro_shop": 5, "cart_barn": 5, "maintenance": 5, "landmark": 5}
	assert_int(MHTournamentRules.facility_permille(d, five)).is_equal(1000)
	var half: Dictionary = {"clubhouse": 2, "restaurant": 2, "pro_shop": 2, "cart_barn": 2, "maintenance": 2}
	assert_int(MHTournamentRules.facility_permille(d, half)).is_equal(500)
	# a non-facility building does not count
	assert_int(MHTournamentRules.facility_permille(d, {"landmark": 4, "homes": 4})).is_equal(0)
	# golden club of the sim tests: clubhouse 3 + cart barn (not a facility? it is) 2 + maintenance 2 + restaurant 1
	var club: Dictionary = {"clubhouse": 3, "cart_barn": 2, "maintenance": 2, "restaurant": 1}
	assert_int(MHTournamentRules.facility_permille(d, club)).is_equal(400)


func test_unfair_holes_and_satisfaction() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	assert_int(MHTournamentRules.unfair_holes(d, [29, 30, 31, 0, 100])).is_equal(2)
	assert_int(MHTournamentRules.unfair_holes(d, [])).is_equal(0)
	var cond: Dictionary = d.condition_by_id("windy")
	assert_int(MHTournamentRules.satisfaction_permille(d, cond, 0)).is_equal(850)
	assert_int(MHTournamentRules.satisfaction_permille(d, cond, 2)).is_equal(650)
	var storm: Dictionary = d.condition_by_id("storm")
	assert_int(MHTournamentRules.satisfaction_permille(d, storm, 18)).is_equal(0)


func test_event_prestige_golden() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	# course 40, pace 60, facilities 400, satisfaction 950: (450*400 + 200*600 + 200*400 + 150*950) / 1000 = 522
	var club: Dictionary = {"clubhouse": 3, "cart_barn": 2, "maintenance": 2, "restaurant": 1}
	assert_int(MHTournamentRules.event_prestige_permille(d, 40, 60, club, 950)).is_equal(522)
	assert_int(MHTournamentRules.event_prestige_permille(d, 100, 100, {"clubhouse": 4, "restaurant": 4, "pro_shop": 4, "cart_barn": 4, "maintenance": 4}, 1000)).is_equal(1000)
	assert_int(MHTournamentRules.event_prestige_permille(d, 0, 0, {}, 0)).is_equal(0)
	assert_int(MHTournamentRules.prestige_points_awarded(d, "local", 522)).is_equal(52)
	assert_int(MHTournamentRules.prestige_points_awarded(d, "major", 1000)).is_equal(1500)
	assert_int(MHTournamentRules.prestige_points_awarded(d, "local", 5000)).is_equal(100)


func test_purse_table_sums_exactly() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	var t: Array = MHTournamentRules.purse_table(d, "local")
	assert_int(t.size()).is_equal(10)
	assert_int(int(t[0])).is_equal(1200)
	assert_int(int(t[1])).is_equal(720)
	assert_int(int(t[9])).is_equal(160)
	var sum: int = 0
	for v: Variant in t:
		sum += int(v)
	assert_int(sum).is_equal(4000)
	for lid: Variant in d.level_ids():
		var tbl: Array = MHTournamentRules.purse_table(d, str(lid))
		var s2: int = 0
		for v2: Variant in tbl:
			s2 += int(v2)
		assert_int(s2).is_equal(d.level_int(str(lid), "host_cost") * 40 / 100)
	assert_int(int(MHTournamentRules.purse_table(d, "major")[0])).is_equal(18000)


func test_cancel_refund() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	assert_int(MHTournamentRules.cancel_refund(d, "local")).is_equal(5000)
	assert_int(MHTournamentRules.cancel_refund(d, "major")).is_equal(75000)
	assert_int(MHTournamentRules.cancel_refund(d, "nope")).is_equal(0)

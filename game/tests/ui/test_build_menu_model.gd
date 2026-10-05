extends GdUnitTestSuite
## MHBuildMenuModel on sample data: 10 buildings x 5 tiers, locked reasons, cost from payback (DEC-050). NOT YET RUN.


func test_ten_rows_five_tiers() -> void:
	var v: MHFakeGameStateView = MHFakeGameStateView.new()
	var rows: Array = MHBuildMenuModel.rows(v)
	assert_int(rows.size()).is_equal(10)
	for r: Variant in rows:
		var d: Dictionary = r
		assert_int((d["tiers"] as Array).size()).is_equal(5)
		assert_bool(str(d["name_key"]).begins_with("building.")).is_true()


func test_cost_is_payback_days_times_income() -> void:
	var v: MHFakeGameStateView = MHFakeGameStateView.new()
	var c: Dictionary = MHBuildMenuModel.row(v, "clubhouse")
	assert_int(int(c["next_tier"])).is_equal(2)
	assert_int(int(c["payback_days"])).is_equal(12)
	assert_int(int(c["income"])).is_equal(1800)
	assert_int(int(c["cost"])).is_equal(21600)
	assert_bool(bool(c["cost_known"])).is_true()
	var p: Dictionary = MHBuildMenuModel.row(v, "pro_shop")
	assert_int(int(p["cost"])).is_equal(12000)
	for r: Variant in MHBuildMenuModel.rows(v):
		var d: Dictionary = r
		if bool(d["maxed"]):
			continue
		var defs: MHBuildingDefs = v.building_defs()
		var id: String = str(d["id"])
		var nxt: int = int(d["next_tier"])
		assert_int(int(d["cost"])).is_equal(defs.target_payback_days(id, nxt) * v.added_daily_income(id, nxt))


func test_statuses_in_demo() -> void:
	var v: MHFakeGameStateView = MHFakeGameStateView.new()
	assert_str(MHBuildMenuModel.status(MHBuildMenuModel.row(v, "clubhouse"))).is_equal("poor")
	assert_str(MHBuildMenuModel.status(MHBuildMenuModel.row(v, "pro_shop"))).is_equal("ready")
	assert_str(MHBuildMenuModel.status(MHBuildMenuModel.row(v, "restaurant"))).is_equal("ready")
	assert_str(MHBuildMenuModel.status(MHBuildMenuModel.row(v, "landmark"))).is_equal("demo")
	assert_str(MHBuildMenuModel.status(MHBuildMenuModel.row(v, "pool_spa"))).is_equal("demo")
	var lm: Dictionary = MHBuildMenuModel.row(v, "landmark")
	assert_bool(bool(lm["can_buy"])).is_false()
	var reasons: Array = lm["reasons"]
	assert_str(str((reasons[0] as Dictionary)["key"])).is_equal("build.req.demo")


func test_statuses_in_full_game_and_low_cash() -> void:
	var v: MHFakeGameStateView = MHFakeGameStateView.new()
	v.sample_set_demo(false)
	assert_str(MHBuildMenuModel.status(MHBuildMenuModel.row(v, "pool_spa"))).is_equal("ready")
	# Homes need an owned homes parcel; the start plot has none.
	var homes: Dictionary = MHBuildMenuModel.row(v, "homes")
	assert_str(MHBuildMenuModel.status(homes)).is_equal("locked")
	var keys: Array = []
	for r: Variant in homes["reasons"]:
		keys.append(str((r as Dictionary)["key"]))
	assert_bool(keys.has("build.req.parcel_kind")).is_true()
	v.sample_set_cash(100)
	var c: Dictionary = MHBuildMenuModel.row(v, "clubhouse")
	assert_bool(bool(c["met"])).is_true()
	assert_bool(bool(c["can_buy"])).is_false()
	assert_str(MHBuildMenuModel.status(c)).is_equal("poor")


func test_heavy_building_needs_extra_parcel() -> void:
	var v: MHFakeGameStateView = MHFakeGameStateView.new()
	v.sample_set_demo(false)
	v.sample_set_tier("driving_range", 1)
	var r: Dictionary = MHBuildMenuModel.row(v, "driving_range")
	assert_int(int(r["next_tier"])).is_equal(2)
	var keys: Array = []
	for x: Variant in r["reasons"]:
		keys.append(str((x as Dictionary)["key"]))
	assert_bool(keys.has("build.req.parcels")).is_true()
	assert_bool(bool(r["met"])).is_false()


func test_maxed_row() -> void:
	var v: MHFakeGameStateView = MHFakeGameStateView.new()
	v.sample_set_tier("clubhouse", 5)
	var r: Dictionary = MHBuildMenuModel.row(v, "clubhouse")
	assert_bool(bool(r["maxed"])).is_true()
	assert_int(int(r["next_tier"])).is_equal(0)
	assert_str(MHBuildMenuModel.status(r)).is_equal("maxed")


func test_tier_states() -> void:
	var v: MHFakeGameStateView = MHFakeGameStateView.new()
	assert_int(MHBuildMenuModel.tier_state(v, "clubhouse", 1)).is_equal(MHBuildMenuModel.TierState.OWNED)
	assert_int(MHBuildMenuModel.tier_state(v, "clubhouse", 2)).is_equal(MHBuildMenuModel.TierState.NEXT)
	assert_int(MHBuildMenuModel.tier_state(v, "clubhouse", 3)).is_equal(MHBuildMenuModel.TierState.DEMO_LOCKED)
	v.sample_set_demo(false)
	assert_int(MHBuildMenuModel.tier_state(v, "clubhouse", 3)).is_equal(MHBuildMenuModel.TierState.LOCKED)
	assert_int(MHBuildMenuModel.tier_state(v, "clubhouse", 5)).is_equal(MHBuildMenuModel.TierState.LOCKED)


func test_reason_mapping() -> void:
	var h: Dictionary = MHBuildMenuModel.reason_for_row(["holes", false, 3, 6])
	assert_str(str(h["key"])).is_equal("build.req.holes")
	assert_int(int((h["params"] as Dictionary)["have"])).is_equal(3)
	assert_int(int((h["params"] as Dictionary)["need"])).is_equal(6)
	var b: Dictionary = MHBuildMenuModel.reason_for_row(["building:clubhouse", false, 1, 3])
	assert_str(str((b["params"] as Dictionary)["building_key"])).is_equal("building.clubhouse.name")
	var t: Dictionary = MHBuildMenuModel.reason_for_row(["hosted_tournament", false, 0, 2])
	assert_str(str((t["params"] as Dictionary)["level_key"])).is_equal("tournament.regional.name")
	var k: Dictionary = MHBuildMenuModel.reason_for_row(["parcel_kind:homes", false, 0, 1])
	assert_str(str((k["params"] as Dictionary)["kind_key"])).is_equal("land.kind.homes")
	assert_str(str(MHBuildMenuModel.reason_for_row(["avg_hole_score", false, 1, 2])["key"])).is_equal("build.req.avg_score")
	assert_str(str(MHBuildMenuModel.reason_for_row(["wat", false, 1, 2])["key"])).is_equal("build.req.unknown")
	for row_key: String in ["holes", "avg_hole_score", "parcels_owned", "members", "any_others", "demo_limit", "previous_tier", "hosted_tournament", "building:landmark", "parcel_kind:homes", "unknown_tier", "pace_score", "staff", "spectators"]:
		var rr: Dictionary = MHBuildMenuModel.reason_for_row([row_key, false, 0, 1])
		assert_bool(MHStrings.has_key(str(rr["key"]))).override_failure_message("no text for " + row_key).is_true()


func test_reports_list_demo_first_and_skip_met_rows() -> void:
	var rep: MHGateReport = MHGateReport.new()
	rep.add("holes", false, 3, 6)
	rep.add("members", true, 5, 0)
	rep.add("demo_limit", false, 3, 2)
	rep.finish()
	var reasons: Array = MHBuildMenuModel.reasons_for_report(rep)
	assert_int(reasons.size()).is_equal(2)
	assert_str(str((reasons[0] as Dictionary)["key"])).is_equal("build.req.demo")
	assert_str(str((reasons[1] as Dictionary)["key"])).is_equal("build.req.holes")


func test_unloaded_catalogue_gives_empty() -> void:
	var v: MHGameStateView = MHGameStateView.new()
	assert_bool(MHBuildMenuModel.row(v, "clubhouse").is_empty()).is_true()
	assert_str(MHBuildMenuModel.status({})).is_equal("locked")


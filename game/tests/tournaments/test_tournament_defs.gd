extends GdUnitTestSuite
## MHTournamentDefs: loading, validation and the shipped data. NOT YET RUN in Godot.


func _data_text() -> String:
	return FileAccess.get_file_as_string(MHTournamentFixture.DATA_PATH)


func _data_dict() -> Dictionary:
	return MHDataJson.parse_text(_data_text())["value"] as Dictionary


func test_shipped_data_loads() -> void:
	var d: MHTournamentDefs = MHTournamentDefs.new()
	assert_bool(d.load_from_file(MHTournamentFixture.DATA_PATH)).is_true()
	assert_str(d.load_error).is_equal("")
	assert_bool(d.is_loaded()).is_true()


func test_four_levels_in_ladder_order() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	var ids: Array = d.level_ids()
	assert_int(ids.size()).is_equal(4)
	assert_str(str(ids[0])).is_equal("local")
	assert_str(str(ids[3])).is_equal("major")
	assert_int(MHTournamentDefs.level_rank("local")).is_equal(1)
	assert_int(MHTournamentDefs.level_rank("major")).is_equal(4)
	assert_int(MHTournamentDefs.level_rank("nope")).is_equal(0)
	assert_str(MHTournamentDefs.level_from_rank(2)).is_equal("regional")
	assert_str(MHTournamentDefs.level_from_rank(0)).is_equal("")
	assert_str(MHTournamentDefs.level_from_rank(5)).is_equal("")


func test_no_requirement_is_tier_five() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	for lid: Variant in d.level_ids():
		var e: Dictionary = d.entry(str(lid))
		for b: Variant in (e["buildings"] as Array):
			assert_int(int((b as Dictionary)["min_tier"])).is_between(1, 4)


func test_ladder_gets_harder_and_pays_more() -> void:
	var defs: MHTournamentDefs = MHTournamentFixture.defs()
	var ids: Array = defs.level_ids()
	for i: int in range(1, ids.size()):
		var a: String = str(ids[i - 1])
		var b: String = str(ids[i])
		assert_int(defs.level_int(b, "host_cost")).is_greater(defs.level_int(a, "host_cost"))
		assert_int(defs.level_int(b, "field_size")).is_greater_equal(defs.level_int(a, "field_size"))
		assert_int(defs.level_int(b, "prestige_base")).is_greater(defs.level_int(a, "prestige_base"))
		assert_int(int(defs.entry(b)["min_avg_hole_score"])).is_greater(int(defs.entry(a)["min_avg_hole_score"]))


func test_spectator_capacity_by_clubhouse_tier() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	assert_int(d.spectator_capacity(0)).is_equal(0)
	assert_int(d.spectator_capacity(1)).is_equal(0)
	assert_int(d.spectator_capacity(2)).is_equal(50)
	assert_int(d.spectator_capacity(3)).is_equal(150)
	assert_int(d.spectator_capacity(4)).is_equal(400)
	assert_int(d.spectator_capacity(5)).is_equal(800)
	assert_int(d.spectator_capacity(9)).is_equal(800)


func test_conditions_and_purse_data() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	assert_int(d.conditions().size()).is_equal(4)
	assert_str(str(d.condition_by_id("storm")["id"])).is_equal("storm")
	assert_bool(d.condition_by_id("nope").is_empty()).is_true()
	var total: int = 0
	for x: Variant in (d.purse()["places_permille"] as Array):
		total += int(x)
	assert_int(total).is_equal(1000)


func test_accessors_return_copies() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	var row: Dictionary = d.level_data("local")
	row["host_cost"] = 1
	assert_int(d.level_int("local", "host_cost")).is_equal(25000)
	assert_bool(d.level_data("nope").is_empty()).is_true()
	assert_int(d.level_int("nope", "host_cost")).is_equal(0)


func test_rejects_wrong_schema() -> void:
	var raw: Dictionary = _data_dict()
	raw["schema"] = "mh.other"
	var d: MHTournamentDefs = MHTournamentDefs.new()
	assert_bool(d.load_from_dict(raw)).is_false()
	assert_bool(d.is_loaded()).is_false()
	assert_str(d.load_error).is_not_empty()


func test_rejects_tier_five_requirement() -> void:
	var raw: Dictionary = _data_dict()
	MHTestEdit.put(raw, ["levels", 0, "entry", "buildings", 0, "min_tier"], 5)
	var d: MHTournamentDefs = MHTournamentDefs.new()
	assert_bool(d.load_from_dict(raw)).is_false()
	assert_str(d.load_error).contains("tier")


func test_rejects_bad_prestige_weights_and_purse() -> void:
	var raw: Dictionary = _data_dict()
	MHTestEdit.put(raw, ["prestige", "weights_permille", "pace"], 201)
	var d: MHTournamentDefs = MHTournamentDefs.new()
	assert_bool(d.load_from_dict(raw)).is_false()
	var raw2: Dictionary = _data_dict()
	MHTestEdit.put(raw2, ["purse", "places_permille", 0], 299)
	assert_bool(d.load_from_dict(raw2)).is_false()


func test_rejects_missing_or_bad_revenue() -> void:
	var raw: Dictionary = _data_dict()
	MHTestEdit.put(raw, ["levels", 0, "revenue", "attendance_pct"], 101)
	var d: MHTournamentDefs = MHTournamentDefs.new()
	assert_bool(d.load_from_dict(raw)).is_false()
	var raw2: Dictionary = _data_dict()
	((raw2["levels"] as Array)[0] as Dictionary).erase("revenue")
	assert_bool(d.load_from_dict(raw2)).is_false()


func test_host_costs_follow_dec_065() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	assert_int(d.level_int("local", "host_cost")).is_equal(25000)
	assert_int(d.level_int("regional", "host_cost")).is_equal(60000)
	for lid: Variant in d.level_ids():
		var rv: Dictionary = d.level_data(str(lid))["revenue"]
		assert_int(int(rv["attendance_pct"])).is_between(0, 100)


func test_rejects_levels_out_of_order_or_missing() -> void:
	var raw: Dictionary = _data_dict()
	var lv: Array = raw["levels"]
	var tmp: Variant = lv[0]
	lv[0] = lv[1]
	lv[1] = tmp
	var d: MHTournamentDefs = MHTournamentDefs.new()
	assert_bool(d.load_from_dict(raw)).is_false()
	var raw2: Dictionary = _data_dict()
	(raw2["levels"] as Array).pop_back()
	assert_bool(d.load_from_dict(raw2)).is_false()


func test_rejects_fractional_numbers_in_text() -> void:
	var text: String = _data_text().replace("\"host_cost\": 25000,", "\"host_cost\": 25000.5,")
	var d: MHTournamentDefs = MHTournamentDefs.new()
	assert_bool(d.load_from_text(text)).is_false()
	assert_bool(d.load_from_text("[1, 2]")).is_false()
	assert_bool(d.load_from_file("res://data/does_not_exist.json")).is_false()


func test_game_copy_equals_docs_copy() -> void:
	var game_text: String = _data_text()
	assert_bool(game_text.length() > 1000).is_true()
	var docs_path: String = ProjectSettings.globalize_path("res://").path_join(MHTournamentFixture.DOCS_COPY).simplify_path()
	if not FileAccess.file_exists(docs_path):
		return
	assert_str(FileAccess.get_file_as_string(docs_path).sha256_text()).is_equal(game_text.sha256_text())

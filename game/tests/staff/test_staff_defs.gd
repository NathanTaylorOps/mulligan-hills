extends GdUnitTestSuite
## MHStaffDefs: loading, validation and the shipped data against buildings.json, tournaments.json and the Python goldens.
## NOT YET RUN in Godot.

const TEN_BUILDINGS: Array = [
	"clubhouse", "pro_shop", "driving_range", "restaurant", "pool_spa", "cart_barn", "maintenance", "lodging", "homes",
	"landmark",
]


func test_shipped_data_loads() -> void:
	var d: MHStaffDefs = MHStaffDefs.new()
	assert_bool(d.load_from_file(MHStaffFixture.DATA_PATH)).is_true()
	assert_str(d.load_error).is_equal("")
	assert_bool(d.is_loaded()).is_true()
	assert_bool(MHStaffDefs.load_default().is_loaded()).is_true()


func test_roles_cover_every_building() -> void:
	var d: MHStaffDefs = MHStaffFixture.defs()
	assert_int(d.role_ids().size()).is_equal(11)
	var seen: Dictionary = {}
	for rid: Variant in d.role_ids():
		seen[d.role_building(str(rid))] = true
	for b: Variant in TEN_BUILDINGS:
		assert_bool(seen.has(str(b))).is_true()
	var bd: MHBuildingDefs = MHBuildingDefs.load_default()
	for b2: Variant in bd.ids():
		assert_bool(seen.has(str(b2))).is_true()
	assert_str(d.role_kind("groundskeeper")).is_equal("grounds")
	assert_str(d.role_kind("wildlife_ranger")).is_equal("pest")
	assert_str(d.role_kind("marshal")).is_equal("station")
	assert_str(d.role_kind("nope")).is_equal("")


func test_grid_and_decay_match_the_land_layout() -> void:
	var d: MHStaffDefs = MHStaffFixture.defs()
	var land: Dictionary = MHBuildingDefs.load_default().land_config()
	var grid: Dictionary = land["grid"]
	assert_int(d.grid_cols()).is_equal(int(grid["cols"]))
	assert_int(d.grid_rows()).is_equal(int(grid["rows"]))
	assert_int(MHStaffFixture.kinds().size()).is_equal(MHStaffDefs.NPARCELS)
	for k: Variant in MHStaffDefs.PARCEL_KINDS:
		assert_int(d.decay(str(k))).is_greater(0)


func test_grades_by_tenure() -> void:
	var d: MHStaffDefs = MHStaffFixture.defs()
	assert_int(d.grade_count()).is_equal(3)
	assert_int(d.grade_of(0)).is_equal(0)
	assert_int(d.grade_of(19)).is_equal(0)
	assert_int(d.grade_of(20)).is_equal(1)
	assert_int(d.grade_of(59)).is_equal(1)
	assert_int(d.grade_of(60)).is_equal(2)
	assert_int(d.grade_of(5000)).is_equal(2)
	assert_str(d.grade_id(2)).is_equal("veteran")
	assert_int(d.work_permille(0)).is_equal(1000)
	assert_int(d.work_permille(60)).is_equal(1700)


func test_golden_wages_costs_and_caps() -> void:
	var d: MHStaffDefs = MHStaffFixture.defs()
	var g: Dictionary = MHStaffFixture.golden()
	assert_bool(g.is_empty()).is_false()
	for row: Variant in (g["wage"] as Array):
		var r: Array = row
		assert_int(d.wage(str(r[0]), int(r[1]))).is_equal(int(r[2]))
	for row2: Variant in (g["hire_cost"] as Array):
		var r2: Array = row2
		assert_int(d.hire_cost(str(r2[0]))).is_equal(int(r2[1]))
	for row3: Variant in (g["caps"] as Array):
		var r3: Array = row3
		for t: int in range(6):
			assert_int(d.cap(str(r3[0]), t)).is_equal(int(r3[t + 1]))
	assert_int(d.cap("groundskeeper", 9)).is_equal(d.cap("groundskeeper", 5))
	assert_int(d.cap("nope", 3)).is_equal(0)


func test_tournament_staff_gate_is_reachable_with_required_buildings_only() -> void:
	var d: MHStaffDefs = MHStaffFixture.defs()
	var td: MHTournamentDefs = MHTournamentFixture.defs()
	for lid: Variant in td.level_ids():
		var e: Dictionary = td.entry(str(lid))
		var tiers: Dictionary = {}
		for b: Variant in (e["buildings"] as Array):
			tiers[str((b as Dictionary)["building"])] = int((b as Dictionary)["min_tier"])
		var reachable: int = 0
		for rid: Variant in d.role_ids():
			reachable += d.cap(str(rid), int(tiers.get(d.role_building(str(rid)), 0)))
		assert_int(reachable).is_greater_equal(int(e["min_staff"]))


func test_max_head_count_fits_the_roster_limit() -> void:
	var d: MHStaffDefs = MHStaffFixture.defs()
	var total: int = 0
	for rid: Variant in d.role_ids():
		total += d.cap(str(rid), 5)
	assert_int(total).is_equal(30)
	assert_int(total).is_less_equal(d.param("max_employees"))


func test_rejects_bad_data() -> void:
	var base: Dictionary = MHStaffFixture.data_dict()
	var bad: Dictionary = base.duplicate(true)
	bad["schema"] = "mh.other"
	assert_bool(MHStaffDefs.new().load_from_dict(bad)).is_false()
	bad = base.duplicate(true)
	(bad["params"] as Dictionary)["keeper_work"] = -1
	assert_bool(MHStaffDefs.new().load_from_dict(bad)).is_false()
	bad = base.duplicate(true)
	(bad["params"] as Dictionary).erase("pest_start")
	assert_bool(MHStaffDefs.new().load_from_dict(bad)).is_false()
	bad = base.duplicate(true)
	((bad["roles"] as Array)[1] as Dictionary)["id"] = "groundskeeper"
	assert_bool(MHStaffDefs.new().load_from_dict(bad)).is_false()
	bad = base.duplicate(true)
	((bad["roles"] as Array)[0] as Dictionary)["building"] = "casino"
	assert_bool(MHStaffDefs.new().load_from_dict(bad)).is_false()
	bad = base.duplicate(true)
	((bad["roles"] as Array)[0] as Dictionary)["caps_by_tier"] = [3, 2, 1, 1, 1]
	assert_bool(MHStaffDefs.new().load_from_dict(bad)).is_false()
	bad = base.duplicate(true)
	(bad["grid"] as Dictionary)["cols"] = 5
	assert_bool(MHStaffDefs.new().load_from_dict(bad)).is_false()
	bad = base.duplicate(true)
	((bad["grades"] as Array)[0] as Dictionary)["min_tenure_days"] = 3
	assert_bool(MHStaffDefs.new().load_from_dict(bad)).is_false()
	assert_bool(MHStaffDefs.new().load_from_text("not json")).is_false()
	assert_bool(MHStaffDefs.new().load_from_text("{\"schema\":\"mh.staff\",\"schema_version\":1,\"params\":{\"a\":1.5}}")).is_false()


func test_accessors_return_copies() -> void:
	var d: MHStaffDefs = MHStaffFixture.defs()
	var r: Dictionary = d.role("groundskeeper")
	r["daily_wage_cents"] = 1
	assert_int(d.role_int("groundskeeper", "daily_wage_cents")).is_equal(2200)
	var ids: Array = d.role_ids()
	ids.clear()
	assert_int(d.role_ids().size()).is_equal(11)


func test_game_copy_equals_docs_copy() -> void:
	var game_text: String = FileAccess.get_file_as_string(MHStaffFixture.DATA_PATH)
	assert_bool(game_text.length() > 1000).is_true()
	var docs_path: String = ProjectSettings.globalize_path("res://").path_join(MHStaffFixture.DOCS_COPY).simplify_path()
	if not FileAccess.file_exists(docs_path):
		return
	assert_str(FileAccess.get_file_as_string(docs_path).sha256_text()).is_equal(game_text.sha256_text())


func test_draft_strings_cover_every_name_key() -> void:
	var d: MHStaffDefs = MHStaffFixture.defs()
	var r: Dictionary = MHDataJson.load_file(MHStaffFixture.STRINGS_PATH)
	assert_bool(bool(r["ok"])).is_true()
	var strings: Dictionary = (r["value"] as Dictionary)["strings"]
	for rid: Variant in d.role_ids():
		assert_bool(strings.has(str(d.role(str(rid))["name_key"]))).is_true()
	for k: Variant in d.incident_kinds():
		assert_bool(strings.has(str((k as Dictionary)["name_key"]))).is_true()
	var data: Dictionary = MHStaffFixture.data_dict()
	for g: Variant in (data["grades"] as Array):
		assert_bool(strings.has(str((g as Dictionary)["name_key"]))).is_true()
	for s: Variant in (data["sighting_kinds"] as Array):
		assert_bool(strings.has(str((s as Dictionary)["name_key"]))).is_true()

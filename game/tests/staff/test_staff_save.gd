extends GdUnitTestSuite
## MHStaff.to_save_block / from_save_block: shape, round trip through JSON, rejection of bad blocks, the legacy default.
## NOT YET RUN in Godot.

const RICH: int = 1000000000
const SaveFixture = preload("res://tests/save/save_fixture.gd")


## make_doc() is unsealed (no checksum), and validate() returns early without one; add a well-formed dummy so the rest is checked.
func _doc() -> Dictionary:
	var d: Dictionary = SaveFixture.make_doc()
	d["checksum"] = {"alg": "sha256", "value": "0000000000000000000000000000000000000000000000000000000000000000"}
	return d


var _staff: MHStaff
var _view: Dictionary


func before_test() -> void:
	_staff = MHStaffFixture.staff()
	_view = MHStaffFixture.view({"maintenance": 3, "clubhouse": 3}, MHStaffFixture.start_owned())


func _played() -> MHStaff:
	var st: MHStaff = MHStaffFixture.staff()
	st.hire("groundskeeper", 0, _view, RICH)
	st.hire("groundskeeper", 0, _view, RICH)
	st.hire("wildlife_ranger", 0, _view, RICH)
	st.hire("marshal", 0, _view, RICH)
	st.auto_assign(_view)
	for day: int in range(1, 41):
		st.on_day(day, _view, 99)
	st.personal_mow(5, 500, 1024, _view)
	st.pay_hour(3)
	return st


func test_block_shape_matches_the_schema_keys() -> void:
	var b: Dictionary = _played().to_save_block()
	var keys: Array = b.keys()
	keys.sort()
	assert_array(keys).is_equal(["condition", "employees", "equipment", "last_day", "next_serial", "personal_pest", "personal_work", "pest", "stats", "v"])
	assert_int(int(b["v"])).is_equal(1)
	assert_int((b["condition"] as Array).size()).is_equal(16)
	assert_int((b["employees"] as Array).size()).is_equal(4)
	var e: Dictionary = (b["employees"] as Array)[0]
	var ek: Array = e.keys()
	ek.sort()
	assert_array(ek).is_equal(["areas", "hired_day", "role", "serial", "tenure"])
	var sk: Array = (b["stats"] as Dictionary).keys()
	sk.sort()
	assert_array(sk).is_equal(["fires", "hires", "incidents_handled", "incidents_hit", "sightings", "wages_cents"])


func test_round_trip_through_json_text() -> void:
	var st: MHStaff = _played()
	var text: String = JSON.stringify(st.to_save_block())
	var parsed: Variant = JSON.parse_string(text)
	assert_int(typeof(parsed)).is_equal(TYPE_DICTIONARY)
	var other: MHStaff = MHStaffFixture.staff()
	assert_bool(other.from_save_block(parsed as Dictionary)).is_true()
	assert_bool(MHStaffFixture.same_list(st.state_list(), other.state_list())).is_true()
	assert_str(JSON.stringify(other.to_save_block(), "", true)).is_equal(JSON.stringify(st.to_save_block(), "", true))
	# the loaded club carries on exactly like the original
	for day: int in range(41, 61):
		st.on_day(day, _view, 99)
		other.on_day(day, _view, 99)
	assert_bool(MHStaffFixture.same_list(st.state_list(), other.state_list())).is_true()


func test_loading_over_a_used_state_replaces_everything() -> void:
	var st: MHStaff = _played()
	var fresh: MHStaff = MHStaffFixture.staff()
	assert_bool(st.from_save_block(fresh.to_save_block())).is_true()
	assert_int(st.head_count()).is_equal(0)
	assert_int(st.roster.next_serial).is_equal(1)
	assert_int(st.roster.hires).is_equal(0)
	assert_int(st.grounds.last_day).is_equal(-1)
	assert_int(st.condition_of(5)).is_equal(700)


func test_mid_day_save_keeps_the_daily_personal_limits() -> void:
	var st: MHStaff = MHStaffFixture.staff()
	st.personal_mow(5, 1024, 1024, _view)
	st.personal_mow(5, 1024, 1024, _view)
	var other: MHStaff = MHStaffFixture.staff()
	assert_bool(other.from_save_block(st.to_save_block())).is_true()
	assert_int(other.personal_mow(5, 1024, 1024, _view)).is_equal(0)


func _bad(mutate: Callable) -> bool:
	var st: MHStaff = _played()
	var block: Dictionary = st.to_save_block()
	var before: PackedInt64Array = st.state_list()
	mutate.call(block)
	var accepted: bool = st.from_save_block(block)
	# a refused block must leave the state untouched
	if not accepted:
		assert_bool(MHStaffFixture.same_list(before, st.state_list())).is_true()
	return accepted


func test_rejects_bad_blocks() -> void:
	assert_bool(_bad(func(b: Dictionary) -> void: b["v"] = 2)).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: b.erase("v"))).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: b["next_serial"] = 0)).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: b["next_serial"] = 2)).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: b["last_day"] = -2)).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: b["last_day"] = 1.5)).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: b["employees"] = "x")).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: ((b["employees"] as Array)[0] as Dictionary)["role"] = "pirate")).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: ((b["employees"] as Array)[0] as Dictionary)["serial"] = 3)).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: ((b["employees"] as Array)[0] as Dictionary)["tenure"] = -1)).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: ((b["employees"] as Array)[0] as Dictionary)["areas"] = [3, 3])).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: ((b["employees"] as Array)[0] as Dictionary)["areas"] = [16])).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: ((b["employees"] as Array)[3] as Dictionary)["areas"] = [5])).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: ((b["employees"] as Array)[0] as Dictionary)["extra"] = 1)).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: (b["condition"] as Array).resize(15))).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: (b["condition"] as Array)[2] = 1001)).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: (b["pest"] as Array)[2] = -1)).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: (b["personal_work"] as Array)[2] = 601)).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: (b["personal_pest"] as Array)[2] = 401)).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: (b["stats"] as Dictionary)["hires"] = -1)).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: (b["stats"] as Dictionary)["cheats"] = 1)).is_false()
	assert_bool(_bad(func(b: Dictionary) -> void: (b["stats"] as Dictionary).erase("sightings"))).is_false()


func test_rejects_dangling_equipment_operator_on_restore() -> void:
	var st: MHStaff = MHStaffFixture.staff()
	var hired: Dictionary = st.hire("groundskeeper", 0, _view, RICH)
	assert_bool(bool(hired["ok"])).is_true()
	var bought: Dictionary = st.buy_equipment("greens_mower", RICH, _view)
	assert_bool(bool(bought["ok"])).is_true()
	assert_bool(st.assign_equipment(int(bought["serial"]), int(hired["serial"]))).is_true()
	var block: Dictionary = st.to_save_block()
	((block["equipment"] as Dictionary)["units"][0] as Dictionary)["assigned_employee"] = 999999
	var restored: MHStaff = MHStaffFixture.staff()
	assert_bool(restored.from_save_block(block)).is_false()


func test_rejects_role_incompatible_equipment_operator_on_restore() -> void:
	var st: MHStaff = MHStaffFixture.staff()
	var grounds: Dictionary = st.hire("groundskeeper", 0, _view, RICH)
	var ranger: Dictionary = st.hire("wildlife_ranger", 0, _view, RICH)
	assert_bool(bool(grounds["ok"]) and bool(ranger["ok"])).is_true()
	var bought: Dictionary = st.buy_equipment("greens_mower", RICH, _view)
	assert_bool(bool(bought["ok"])).is_true()
	assert_bool(st.assign_equipment(int(bought["serial"]), int(grounds["serial"]))).is_true()
	var block: Dictionary = st.to_save_block()
	((block["equipment"] as Dictionary)["units"][0] as Dictionary)["assigned_employee"] = int(ranger["serial"])
	var restored: MHStaff = MHStaffFixture.staff()
	assert_bool(restored.from_save_block(block)).is_false()


func test_unmodified_block_is_accepted_by_the_helper() -> void:
	assert_bool(_bad(func(_b: Dictionary) -> void: pass)).is_true()


func test_too_many_employees_rejected() -> void:
	var st: MHStaff = MHStaffFixture.staff()
	var block: Dictionary = st.to_save_block()
	var emps: Array = []
	for i: int in range(121):
		emps.append({"serial": i + 1, "role": "marshal", "hired_day": 0, "tenure": 0, "areas": []})
	block["employees"] = emps
	block["next_serial"] = 500
	assert_bool(st.from_save_block(block)).is_false()


func test_legacy_counts_fit_the_existing_club_staff_block() -> void:
	var st: MHStaff = _played()
	var lc: Dictionary = st.legacy_counts()
	var keys: Array = lc.keys()
	keys.sort()
	assert_array(keys).is_equal(["caterers", "greenkeepers", "marshals", "pro_shop_staff"])
	assert_int(int(lc["greenkeepers"])).is_equal(3)
	assert_int(int(lc["marshals"])).is_equal(1)


func test_save_document_validator_accepts_the_roster_block() -> void:
	var doc: Dictionary = _doc()
	var base: int = MHSaveGame.validate(doc).size()
	(doc["club"] as Dictionary)["staff_roster"] = _played().to_save_block()
	assert_int(MHSaveGame.validate(doc).size()).is_equal(base)
	# the block survives the document normalizer and the canonical checksum
	var again: MHSaveResult = MHSaveGame.normalize(JSON.parse_string(JSON.stringify(doc)))
	assert_bool(again.is_ok()).is_true()
	assert_int(MHSaveGame.validate(again.value as Dictionary).size()).is_equal(base)
	var loaded: MHStaff = MHStaffFixture.staff()
	assert_bool(loaded.from_save_block(((again.value as Dictionary)["club"] as Dictionary)["staff_roster"] as Dictionary)).is_true()
	assert_int(loaded.head_count()).is_equal(4)


func test_save_document_validator_rejects_a_malformed_roster_block() -> void:
	var doc: Dictionary = _doc()
	var base: int = MHSaveGame.validate(doc).size()
	(doc["club"] as Dictionary)["staff_roster"] = "nope"
	assert_int(MHSaveGame.validate(doc).size()).is_greater(base)
	var block: Dictionary = _played().to_save_block()
	block.erase("stats")
	(doc["club"] as Dictionary)["staff_roster"] = block
	assert_int(MHSaveGame.validate(doc).size()).is_greater(base)
	var short: Dictionary = _played().to_save_block()
	(short["pest"] as Array).resize(3)
	(doc["club"] as Dictionary)["staff_roster"] = short
	assert_int(MHSaveGame.validate(doc).size()).is_greater(base)
	var other: Dictionary = _doc()
	(other["club"] as Dictionary)["unknown_key"] = 1
	assert_int(MHSaveGame.validate(other).size()).is_greater(base)


func test_a_save_without_a_roster_is_the_fresh_default() -> void:
	var doc: Dictionary = _doc()
	assert_bool((doc["club"] as Dictionary).has("staff_roster")).is_false()
	assert_bool(MHSaveGame.validate(doc).any(func(e: Variant) -> bool: return str(e).contains("staff_roster"))).is_false()
	assert_int(MHStaffFixture.staff().head_count()).is_equal(0)

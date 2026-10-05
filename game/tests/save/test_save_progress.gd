extends GdUnitTestSuite
## Save fields added after the first v1 files (DEC-052 clock position, playtime, tournament counters, achievement
## stats, streak, daily state; ironman removed by DEC-058) and their round trip through the real modules.
## v1 saves written before these fields must stay valid and readable. NOT YET RUN in Godot.

const Fixture = preload("res://tests/save/save_fixture.gd")


## Fixture document (a legacy v1 shape: ironman false, playtime_s, nothing else new) sealed and ready to validate.
func _legacy_doc() -> Dictionary:
	var doc: Dictionary = Fixture.make_doc()
	MHSaveGame.seal(doc)
	return doc


## A document that carries every new field, filled from real module state.
func _full_doc() -> Dictionary:
	var doc: Dictionary = Fixture.make_doc()
	doc.erase("ironman")
	(doc["world"] as Dictionary)["minute_of_day"] = 135
	var pr: Dictionary = doc["progress"]
	var p: MHProgression = MHProgressionFixture.progression()
	p.stats.observe({"holes_max": 7, "best_course_score": 47, "members_max": 12, "lifetime_earned": 64200, "bonus_prestige": 20})
	p.stats.observe_tiers({"clubhouse": 1, "maintenance": 0})
	p.record_active_day(20000)
	p.record_active_day(20001)
	p.refresh()
	var blocks: Dictionary = p.to_save_progress()
	for k: Variant in blocks.keys():
		pr[k] = blocks[k]
	var ds: MHDailyState = MHDailyState.new()
	ds.record_attempt(20001, true, 810, 700)
	ds.record_attempt(20001, false, 400, 650)
	pr["daily"] = ds.to_save_block()
	var ts: MHTournamentState = MHTournamentState.new()
	ts.from_save_block({"hosted_levels": ["local"], "cooldown_until_day": 30, "hosted_count": 2, "attempted_count": 3})
	pr["tournaments"] = ts.to_save_block()
	pr["playtime_s"] = 7300
	MHSaveGame.seal(doc)
	return doc


func test_clock_constant_matches_the_game_day() -> void:
	assert_int(MHSaveGame.MAX_MINUTE_OF_DAY).is_equal(MHGameClock.MINUTES_PER_DAY - 1)


func test_legacy_v1_save_stays_valid_and_readable() -> void:
	var doc: Dictionary = _legacy_doc()
	assert_bool(doc.has("ironman")).is_true()
	assert_bool((doc["world"] as Dictionary).has("minute_of_day")).is_false()
	assert_int(MHSaveGame.validate(doc).size()).is_equal(0)
	assert_int(MHSaveGame.minute_of_day_of(doc)).is_equal(0)
	assert_int(MHSaveGame.playtime_s_of(doc)).is_equal(5400)
	var sum: MHSaveSummary = MHSaveSummary.from_doc(doc)
	assert_int(sum.playtime_s).is_equal(5400)
	assert_int(sum.day).is_equal(17)


func test_save_without_ironman_key_is_valid_and_true_is_refused() -> void:
	var doc: Dictionary = Fixture.make_doc()
	doc.erase("ironman")
	MHSaveGame.seal(doc)
	assert_int(MHSaveGame.validate(doc).size()).is_equal(0)
	doc["ironman"] = true
	assert_bool(MHSaveGame.validate(doc).is_empty()).is_false()
	doc["ironman"] = "no"
	assert_bool(MHSaveGame.validate(doc).is_empty()).is_false()


func test_strip_legacy_keys_returns_a_copy_without_ironman() -> void:
	var doc: Dictionary = _legacy_doc()
	var out: Dictionary = MHSaveGame.strip_legacy_keys(doc)
	assert_bool(out.has("ironman")).is_false()
	assert_bool(doc.has("ironman")).is_true()
	MHSaveGame.seal(out)
	assert_int(MHSaveGame.validate(out).size()).is_equal(0)


func test_full_document_validates_and_reads_back() -> void:
	var doc: Dictionary = _full_doc()
	var errs: Array = MHSaveGame.validate(doc)
	assert_str(", ".join(PackedStringArray(errs))).is_equal("")
	assert_int(MHSaveGame.minute_of_day_of(doc)).is_equal(135)
	assert_int(MHSaveGame.playtime_s_of(doc)).is_equal(7300)
	assert_int(MHSaveSummary.from_doc(doc).playtime_s).is_equal(7300)


func test_full_document_survives_bytes_round_trip_byte_identical() -> void:
	var doc: Dictionary = _full_doc()
	var bytes: PackedByteArray = MHSaveGame.to_bytes(doc)
	var r: MHSaveResult = MHSaveGame.parse_bytes(bytes)
	assert_bool(r.is_ok()).is_true()
	var back: Dictionary = r.value
	assert_bool(MHSaveGame.to_bytes(back) == bytes).is_true()
	assert_int(MHSaveGame.validate(back).size()).is_equal(0)


func test_progress_blocks_load_back_into_the_modules() -> void:
	var doc: Dictionary = _full_doc()
	var parsed: MHSaveResult = MHSaveGame.parse_bytes(MHSaveGame.to_bytes(doc))
	var pr: Dictionary = (parsed.value as Dictionary)["progress"]
	var p: MHProgression = MHProgressionFixture.progression()
	assert_bool(p.load_save_progress(pr)).is_true()
	assert_int(p.stats.value_of("holes_max")).is_equal(7)
	assert_int(p.stats.value_of("lifetime_earned")).is_equal(64200)
	assert_int(p.streak.current).is_equal(2)
	assert_int(p.streak.last_day).is_equal(20001)
	assert_bool((p.to_save_progress()["stats"] as Dictionary) == (pr["stats"] as Dictionary)).is_true()
	assert_bool((p.to_save_progress()["streak"] as Dictionary) == (pr["streak"] as Dictionary)).is_true()
	var ds: MHDailyState = MHDailyState.new()
	assert_bool(ds.from_save_block(pr["daily"] as Dictionary)).is_true()
	assert_int(ds.attempts_left(20001)).is_equal(1)
	assert_int(ds.attempted_days).is_equal(1)
	assert_int(ds.completed_days).is_equal(1)
	assert_bool(ds.to_save_block() == (pr["daily"] as Dictionary)).is_true()
	var ts: MHTournamentState = MHTournamentState.new()
	assert_bool(ts.from_save_block(pr["tournaments"] as Dictionary)).is_true()
	assert_int(ts.hosted_count).is_equal(2)
	assert_int(ts.attempted_count).is_equal(3)
	assert_int(ts.cooldown_until_day).is_equal(30)
	assert_str(ts.highest_hosted_level()).is_equal("local")


func test_old_progress_without_new_blocks_loads_with_fresh_defaults() -> void:
	var doc: Dictionary = _legacy_doc()
	var pr: Dictionary = doc["progress"]
	var p: MHProgression = MHProgressionFixture.progression()
	assert_bool(p.load_save_progress(pr)).is_true()
	assert_int(p.unlocked_ids().size()).is_equal(1)
	assert_int(p.streak.current).is_equal(0)
	assert_int(p.stats.value_of("holes_max")).is_equal(0)
	var ts: MHTournamentState = MHTournamentState.new()
	assert_bool(ts.from_save_block(pr["tournaments"] as Dictionary)).is_true()
	assert_int(ts.hosted_count).is_equal(0)


func test_bad_progress_blocks_change_nothing() -> void:
	var p: MHProgression = MHProgressionFixture.progression()
	p.stats.observe({"holes_max": 5})
	assert_bool(p.load_save_progress({"stats": {"holes_max": -3}})).is_false()
	assert_bool(p.load_save_progress({"stats": "x"})).is_false()
	assert_bool(p.load_save_progress({"streak": {"current": 1}})).is_false()
	assert_bool(p.load_save_progress({"achievements": "first_hole"})).is_false()
	assert_int(p.stats.value_of("holes_max")).is_equal(5)
	# unknown stat names are dropped, not an error (a save from a newer build)
	assert_bool(p.load_save_progress({"stats": {"holes_max": 9, "stat_from_the_future": 4}})).is_true()
	assert_int(p.stats.value_of("holes_max")).is_equal(9)


const BAD_CASES: Array = [
	"minute_of_day 660", "minute_of_day negative", "playtime negative", "hosted_count negative", "stat negative",
	"stat key malformed", "streak claimed duplicate", "streak last_day -2", "daily best_pm 1001", "daily used 11",
	"daily board not objects", "daily history too long", "daily missing key", "streak not an object",
]


func test_validate_rejects_bad_new_fields() -> void:
	for case_name: Variant in BAD_CASES:
		var doc: Dictionary = _full_doc()
		_break(doc, str(case_name))
		MHSaveGame.seal(doc)
		assert_bool(MHSaveGame.validate(doc).is_empty()).override_failure_message("accepted: " + str(case_name)).is_false()


func _break(doc: Dictionary, case_name: String) -> void:
	var world: Dictionary = doc["world"]
	var pr: Dictionary = doc["progress"]
	var tn: Dictionary = pr["tournaments"]
	var stats: Dictionary = pr["stats"]
	var streak: Dictionary = pr["streak"]
	var daily: Dictionary = pr["daily"]
	if case_name == "minute_of_day 660":
		world["minute_of_day"] = 660
	elif case_name == "minute_of_day negative":
		world["minute_of_day"] = -1
	elif case_name == "playtime negative":
		pr["playtime_s"] = -1
	elif case_name == "hosted_count negative":
		tn["hosted_count"] = -1
	elif case_name == "stat negative":
		stats["holes_max"] = -1
	elif case_name == "stat key malformed":
		stats["Bad Key"] = 1
	elif case_name == "streak claimed duplicate":
		streak["claimed"] = [3, 3]
	elif case_name == "streak last_day -2":
		streak["last_day"] = -2
	elif case_name == "daily best_pm 1001":
		daily["best_pm"] = 1001
	elif case_name == "daily used 11":
		daily["used"] = 11
	elif case_name == "daily board not objects":
		daily["board"] = [1]
	elif case_name == "daily history too long":
		daily["history"] = _rows(31)
	elif case_name == "daily missing key":
		daily.erase("board")
	elif case_name == "streak not an object":
		pr["streak"] = 5


func test_clock_resumes_mid_day_from_the_save() -> void:
	var doc: Dictionary = _full_doc()
	var clock: MHGameClock = MHGameClock.new()
	clock.set_time(int((doc["world"] as Dictionary)["day"]), MHSaveGame.minute_of_day_of(doc))
	assert_int(clock.day()).is_equal(17)
	assert_int(clock.minute_of_day()).is_equal(135)
	# a v1 save without the field resumes at the start of the day
	var legacy: Dictionary = _legacy_doc()
	clock.set_time(int((legacy["world"] as Dictionary)["day"]), MHSaveGame.minute_of_day_of(legacy))
	assert_int(clock.minute_of_day()).is_equal(0)


func _rows(n: int) -> Array:
	var out: Array = []
	for i: int in range(n):
		out.append({"day": i, "attempts": 1, "completed": 0, "best_pm": 100})
	return out

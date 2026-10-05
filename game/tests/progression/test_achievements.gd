extends GdUnitTestSuite
## MHProgressStats and MHAchievements. NOT YET RUN in Godot.

const SCHEMA_DOCS: String = "../docs/spec/data/achievements.schema.json"


func _stats(snapshot: Dictionary) -> MHProgressStats:
	var s: MHProgressStats = MHProgressStats.new()
	s.observe(snapshot)
	return s


# ------------------------------------------------------------------ stats

func test_stats_only_go_up() -> void:
	var s: MHProgressStats = MHProgressStats.new()
	assert_bool(s.observe({"holes_max": 9})).is_true()
	assert_bool(s.observe({"holes_max": 6})).is_false()
	assert_int(s.value_of("holes_max")).is_equal(9)
	assert_bool(s.observe({"holes_max": 12})).is_true()
	assert_int(s.value_of("holes_max")).is_equal(12)
	assert_int(s.value_of("members_max")).is_equal(0)


func test_stats_ignore_unknown_and_bad_values() -> void:
	var s: MHProgressStats = MHProgressStats.new()
	assert_bool(s.observe({"made_up_stat": 5, "holes_max": "7", "members_max": 1.5})).is_false()
	assert_int(s.value_of("made_up_stat")).is_equal(0)
	assert_int(s.value_of("holes_max")).is_equal(0)
	s.observe({"holes_max": -4, "lifetime_earned": 99999999999})
	assert_int(s.value_of("holes_max")).is_equal(0)
	assert_int(s.value_of("lifetime_earned")).is_equal(MHProgressStats.MAX_VALUE)
	s.observe({"tutorial_done": true})
	assert_int(s.value_of("tutorial_done")).is_equal(1)
	s.observe({"tutorial_done": false})
	assert_int(s.value_of("tutorial_done")).is_equal(1)


func test_observe_tiers() -> void:
	var s: MHProgressStats = MHProgressStats.new()
	s.observe_tiers({"clubhouse": 4, "restaurant": 3, "landmark": 5, "homes": 0})
	assert_int(s.value_of("tier_clubhouse")).is_equal(4)
	assert_int(s.value_of("tier_restaurant")).is_equal(3)
	assert_int(s.value_of("tier_landmark")).is_equal(5)
	assert_int(s.value_of("tier_sum")).is_equal(12)
	assert_int(s.value_of("tier5_count")).is_equal(1)
	assert_int(s.value_of("buildings_built")).is_equal(3)
	# demolishing never lowers a mark
	s.observe_tiers({"clubhouse": 1})
	assert_int(s.value_of("tier_clubhouse")).is_equal(4)
	assert_int(s.value_of("tier_sum")).is_equal(12)


func test_observe_hosted() -> void:
	var s: MHProgressStats = MHProgressStats.new()
	s.observe_hosted(["local", "regional"], 3, 5)
	assert_int(s.value_of("hosted_local")).is_equal(1)
	assert_int(s.value_of("hosted_regional")).is_equal(1)
	assert_int(s.value_of("hosted_national")).is_equal(0)
	assert_int(s.value_of("tournaments_hosted")).is_equal(3)
	assert_int(s.value_of("tournaments_attempted")).is_equal(5)


func test_stats_round_trip() -> void:
	var s: MHProgressStats = _stats({"holes_max": 18, "bonus_prestige": 40, "nope": 3})
	var d: Dictionary = s.to_dict()
	var t: MHProgressStats = MHProgressStats.new()
	assert_bool(t.from_dict(d)).is_true()
	assert_int(t.value_of("holes_max")).is_equal(18)
	assert_int(t.value_of("bonus_prestige")).is_equal(40)
	var parsed: Variant = JSON.parse_string(JSON.stringify(d))
	var u: MHProgressStats = MHProgressStats.new()
	assert_bool(u.from_dict(parsed as Dictionary)).is_true()
	assert_int(u.value_of("holes_max")).is_equal(18)
	var bad: Dictionary = {"v": 1, "stats": {"holes_max": -1}}
	assert_bool(MHProgressStats.new().from_dict(bad)).is_false()
	assert_bool(MHProgressStats.new().from_dict({"v": 2, "stats": {}})).is_false()
	# unknown keys in a save are dropped, not fatal
	assert_bool(MHProgressStats.new().from_dict({"v": 1, "stats": {"retired_stat": 4, "holes_max": 2}})).is_true()


func test_stat_keys_match_the_schema_enum() -> void:
	var docs_path: String = ProjectSettings.globalize_path("res://").path_join(SCHEMA_DOCS).simplify_path()
	assert_int(MHProgressStats.STAT_KEYS.size()).is_equal(39)
	if not FileAccess.file_exists(docs_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(docs_path))
	var schema: Dictionary = parsed
	var item: Dictionary = (((schema["properties"] as Dictionary)["achievements"] as Dictionary)["items"] as Dictionary)
	var all_item: Dictionary = (((item["properties"] as Dictionary)["all"] as Dictionary)["items"] as Dictionary)
	var stat_enum: Array = (((all_item["properties"] as Dictionary)["stat"] as Dictionary)["enum"] as Array)
	assert_int(stat_enum.size()).is_equal(MHProgressStats.STAT_KEYS.size())
	for k: Variant in stat_enum:
		assert_bool(MHProgressStats.STAT_KEYS.has(str(k))).is_true()


# ------------------------------------------------------------------ catalogue

func test_catalogue_loads_with_at_least_forty() -> void:
	var a: MHAchievements = MHAchievements.new()
	assert_bool(a.load_from_file(MHProgressionFixture.ACHIEVEMENTS_PATH)).is_true()
	assert_int(a.count()).is_greater_equal(40)
	assert_int(a.count()).is_equal(61)
	assert_int(a.all_ids().size()).is_equal(61)


func test_every_achievement_is_well_formed_and_unique() -> void:
	var a: MHAchievements = MHProgressionFixture.achievements()
	var seen: Dictionary = {}
	var points: int = 0
	var hidden: int = 0
	var cats: Dictionary = {}
	for aid: String in a.all_ids():
		assert_bool(seen.has(aid)).is_false()
		seen[aid] = true
		var d: Dictionary = a.get_def(aid)
		assert_str(str(d["name_key"])).is_equal("achievement." + aid + ".name")
		assert_str(str(d["desc_key"])).is_equal("achievement." + aid + ".desc")
		assert_int(int(d["points"])).is_between(0, 1000)
		points += int(d["points"])
		if bool(d["hidden"]):
			hidden += 1
		cats[str(d["category"])] = true
		for c: Variant in (d["all"] as Array):
			assert_bool(MHProgressStats.STAT_KEYS.has(str((c as Dictionary)["stat"]))).is_true()
	assert_int(points).is_equal(1140)
	assert_int(hidden).is_equal(1)
	assert_int(cats.size()).is_equal(7)


func test_unlock_conditions_are_data() -> void:
	var a: MHAchievements = MHProgressionFixture.achievements()
	assert_bool(a.is_met("first_hole", _stats({}))).is_false()
	assert_bool(a.is_met("first_hole", _stats({"holes_max": 1}))).is_true()
	assert_bool(a.is_met("nine_holes", _stats({"holes_max": 8}))).is_false()
	assert_bool(a.is_met("nine_holes", _stats({"holes_max": 9}))).is_true()
	assert_bool(a.is_met("no_such_achievement", _stats({"holes_max": 99}))).is_false()


func test_all_conditions_must_hold() -> void:
	var a: MHAchievements = MHProgressionFixture.achievements()
	assert_bool(a.is_met("keep_trying", _stats({"tournaments_attempted": 2}))).is_false()
	assert_bool(a.is_met("keep_trying", _stats({"tournaments_hosted": 1}))).is_false()
	assert_bool(a.is_met("keep_trying", _stats({"tournaments_attempted": 2, "tournaments_hosted": 1}))).is_true()
	var three: MHProgressStats = _stats({"hosted_local": 1, "hosted_regional": 1, "hosted_national": 1})
	assert_bool(a.is_met("full_ladder", three)).is_false()
	three.observe({"hosted_major": 1})
	assert_bool(a.is_met("full_ladder", three)).is_true()


func test_newly_unlocked_skips_already_unlocked_and_keeps_file_order() -> void:
	var a: MHAchievements = MHProgressionFixture.achievements()
	var s: MHProgressStats = _stats({"holes_max": 9, "best_hole_score": 55})
	var fresh: Array = a.newly_unlocked(s, [])
	assert_int(fresh.size()).is_equal(3)
	assert_str(str(fresh[0])).is_equal("first_hole")
	assert_str(str(fresh[1])).is_equal("nine_holes")
	assert_str(str(fresh[2])).is_equal("good_hole")
	var again: Array = a.newly_unlocked(s, ["first_hole", "good_hole"])
	assert_int(again.size()).is_equal(1)
	assert_str(str(again[0])).is_equal("nine_holes")
	assert_int(a.newly_unlocked(s, fresh).size()).is_equal(0)


func test_points() -> void:
	var a: MHAchievements = MHProgressionFixture.achievements()
	assert_int(a.points_of("first_hole")).is_equal(5)
	assert_int(a.points_of("major_host")).is_equal(60)
	assert_int(a.points_of("nope")).is_equal(0)
	assert_int(a.total_points(["first_hole", "nine_holes", "nope"])).is_equal(15)


func test_progress_rows() -> void:
	var a: MHAchievements = MHProgressionFixture.achievements()
	var s: MHProgressStats = _stats({"holes_max": 4, "hosted_local": 1, "hosted_regional": 1})
	var rows: Array = a.progress_rows(s, ["first_hole"])
	assert_int(rows.size()).is_equal(61)
	var by_id: Dictionary = {}
	for r: Variant in rows:
		by_id[str((r as Dictionary)["id"])] = r
	var nine: Dictionary = by_id["nine_holes"]
	assert_int(int(nine["progress"])).is_equal(4)
	assert_int(int(nine["target"])).is_equal(9)
	assert_bool(bool(nine["earned"])).is_false()
	assert_str(str(nine["category"])).is_equal("design")
	var first: Dictionary = by_id["first_hole"]
	assert_bool(bool(first["earned"])).is_true()
	assert_int(int(first["progress"])).is_equal(int(first["target"]))
	var ladder: Dictionary = by_id["full_ladder"]
	assert_bool(bool(ladder["hidden"])).is_true()
	assert_int(int(ladder["progress"])).is_equal(2)
	assert_int(int(ladder["target"])).is_equal(4)


func test_non_gte_ops() -> void:
	var cond_lte: Dictionary = {"stat": "holes_max", "op": "lte", "value": 3}
	var cond_eq: Dictionary = {"stat": "holes_max", "op": "eq", "value": 3}
	var s: MHProgressStats = _stats({"holes_max": 3})
	assert_bool(MHAchievements.condition_met(cond_lte, s)).is_true()
	assert_bool(MHAchievements.condition_met(cond_eq, s)).is_true()
	s.observe({"holes_max": 4})
	assert_bool(MHAchievements.condition_met(cond_lte, s)).is_false()
	assert_bool(MHAchievements.condition_met(cond_eq, s)).is_false()


func test_validation_rejects_bad_catalogues() -> void:
	var a: MHAchievements = MHAchievements.new()
	var raw: Dictionary = MHDataJson.load_file(MHProgressionFixture.ACHIEVEMENTS_PATH)["value"]
	(raw["achievements"] as Array).resize(39)
	assert_bool(a.load_from_dict(raw)).is_false()
	assert_bool(a.is_loaded()).is_false()
	var raw2: Dictionary = MHDataJson.load_file(MHProgressionFixture.ACHIEVEMENTS_PATH)["value"]
	MHTestEdit.put(raw2, ["achievements", 1, "id"], "first_hole")
	assert_bool(a.load_from_dict(raw2)).is_false()
	var raw3: Dictionary = MHDataJson.load_file(MHProgressionFixture.ACHIEVEMENTS_PATH)["value"]
	MHTestEdit.put(raw3, ["achievements", 0, "all", 0, "stat"], "made_up")
	assert_bool(a.load_from_dict(raw3)).is_false()
	var raw4: Dictionary = MHDataJson.load_file(MHProgressionFixture.ACHIEVEMENTS_PATH)["value"]
	MHTestEdit.put(raw4, ["achievements", 0, "all"], [])
	assert_bool(a.load_from_dict(raw4)).is_false()
	assert_bool(a.load_from_text("{}")).is_false()


func test_game_copy_equals_docs_copy() -> void:
	assert_bool(MHProgressionFixture.same_text_as_docs(MHProgressionFixture.ACHIEVEMENTS_PATH, "../docs/spec/data/achievements.json")).is_true()
	assert_bool(MHProgressionFixture.same_text_as_docs(MHProgressionFixture.PROGRESSION_PATH, "../docs/spec/data/progression.json")).is_true()

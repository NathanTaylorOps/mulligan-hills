extends GdUnitTestSuite
## MHProgression: prestige points, levels, refresh loop, persistence. Goldens from a Python mirror of the formulas
## (scratch script). NOT YET RUN in Godot.


func _rich() -> MHProgression:
	var p: MHProgression = MHProgressionFixture.progression()
	p.stats.observe({
		"holes_max": 18, "tier_sum": 20, "best_course_score": 60, "members_max": 100, "challenges_completed": 5,
		"challenges_attempted": 8, "commissions_done": 2, "bonus_prestige": 30,
	})
	return p


func test_loads_defaults() -> void:
	var p: MHProgression = MHProgression.new()
	assert_bool(p.load_defaults()).is_true()
	assert_str(p.load_error).is_equal("")
	assert_bool(p.is_loaded()).is_true()
	assert_int(p.level_count()).is_equal(20)
	assert_int(p.level()).is_equal(1)
	assert_int(p.club_points()).is_equal(0)
	assert_int(p.points_for_next_level()).is_equal(100)


func test_unloaded_is_safe() -> void:
	var p: MHProgression = MHProgression.new()
	assert_int(p.club_points()).is_equal(0)
	assert_int(p.level_count()).is_equal(0)
	assert_int(p.level()).is_equal(1)


func test_points_breakdown_golden() -> void:
	var p: MHProgression = _rich()
	var b: Dictionary = p.points_breakdown()
	assert_int(int(b["holes"])).is_equal(144)
	assert_int(int(b["tiers"])).is_equal(200)
	assert_int(int(b["course"])).is_equal(300)
	assert_int(int(b["members"])).is_equal(50)
	assert_int(int(b["challenges"])).is_equal(56)
	assert_int(int(b["commissions"])).is_equal(30)
	assert_int(int(b["achievements"])).is_equal(0)
	assert_int(int(b["streak"])).is_equal(0)
	assert_int(int(b["bonus"])).is_equal(30)
	assert_int(int(b["total"])).is_equal(810)
	assert_int(p.level()).is_equal(5)


func test_member_points_are_capped() -> void:
	var p: MHProgression = MHProgressionFixture.progression()
	p.stats.observe({"members_max": 5000})
	assert_int(int(p.points_breakdown()["members"])).is_equal(200)


func test_level_table_edges() -> void:
	var p: MHProgression = MHProgressionFixture.progression()
	assert_int(p.level_for_points(0)).is_equal(1)
	assert_int(p.level_for_points(99)).is_equal(1)
	assert_int(p.level_for_points(100)).is_equal(2)
	assert_int(p.level_for_points(249)).is_equal(2)
	assert_int(p.level_for_points(250)).is_equal(3)
	assert_int(p.level_for_points(21999)).is_equal(19)
	assert_int(p.level_for_points(22000)).is_equal(20)
	assert_int(p.level_for_points(99999999)).is_equal(20)
	assert_bool(p.level_row(0).is_empty()).is_true()
	assert_bool(p.level_row(21).is_empty()).is_true()
	assert_int(int(p.level_row(7)["prestige_needed"])).is_equal(1400)


func test_unlocks_by_level() -> void:
	var p: MHProgression = MHProgressionFixture.progression()
	assert_int(p.unlocks_up_to_level(1).size()).is_equal(0)
	var up5: Array = p.unlocks_up_to_level(5)
	assert_int(up5.size()).is_equal(4)
	assert_str(str(up5[0])).is_equal("commissions")
	assert_str(str(up5[3])).is_equal("banner_1")
	assert_bool(p.is_unlocked("commissions")).is_false()
	p.stats.observe({"bonus_prestige": 120})
	assert_bool(p.is_unlocked("commissions")).is_true()
	assert_bool(p.is_unlocked("plaque_bronze")).is_false()


func test_refresh_unlocks_achievements_and_lifts_the_level() -> void:
	var p: MHProgression = _rich()
	var r: Dictionary = p.refresh()
	var fresh: Array = r["new_achievements"]
	var want: Array = ["first_hole", "nine_holes", "full_eighteen", "solid_course", "fine_course", "tier_sum_twenty", "fifty_members", "first_commission", "first_challenge", "challenge_met", "club_level_five"]
	assert_int(fresh.size()).is_equal(want.size())
	for i: int in range(want.size()):
		assert_str(str(fresh[i])).is_equal(str(want[i]))
	assert_int(int(r["level_before"])).is_equal(1)
	assert_int(int(r["level"])).is_equal(5)
	assert_bool(bool(r["level_up"])).is_true()
	assert_int((r["new_unlocks"] as Array).size()).is_equal(4)
	assert_int(int(p.points_breakdown()["achievements"])).is_equal(145)
	assert_int(p.club_points()).is_equal(955)
	assert_int(p.stats.value_of("level")).is_equal(5)
	assert_bool(p.is_achievement_unlocked("club_level_five")).is_true()
	# a second refresh with nothing new does nothing
	var r2: Dictionary = p.refresh()
	assert_int((r2["new_achievements"] as Array).size()).is_equal(0)
	assert_bool(bool(r2["level_up"])).is_false()
	assert_int((r2["new_unlocks"] as Array).size()).is_equal(0)


func test_refresh_small_progress() -> void:
	var p: MHProgression = MHProgressionFixture.progression()
	p.stats.observe({"holes_max": 9, "best_hole_score": 55})
	var r: Dictionary = p.refresh()
	assert_int((r["new_achievements"] as Array).size()).is_equal(3)
	assert_int(p.club_points()).is_equal(92)
	assert_int(p.level()).is_equal(1)
	assert_bool(bool(r["level_up"])).is_false()


func test_refresh_tournament_ladder() -> void:
	var p: MHProgression = MHProgressionFixture.progression()
	p.stats.observe_hosted(["local", "regional", "national", "major"], 4, 4)
	var r: Dictionary = p.refresh()
	assert_int((r["new_achievements"] as Array).size()).is_equal(7)
	assert_bool(p.is_achievement_unlocked("full_ladder")).is_true()
	assert_int(p.club_points()).is_equal(220)
	assert_int(p.level()).is_equal(2)
	assert_int(int(r["level"])).is_equal(2)
	assert_str(str((r["new_unlocks"] as Array)[0])).is_equal("commissions")


func test_points_never_drop_when_stats_are_observed_lower() -> void:
	var p: MHProgression = _rich()
	p.refresh()
	var before: int = p.club_points()
	p.stats.observe({"holes_max": 3, "tier_sum": 1, "best_course_score": 5})
	p.refresh()
	assert_int(p.club_points()).is_equal(before)


func test_bonus_prestige_adds_up() -> void:
	var p: MHProgression = MHProgressionFixture.progression()
	p.add_bonus_prestige(52)
	p.add_bonus_prestige(0)
	p.add_bonus_prestige(-10)
	p.add_bonus_prestige(48)
	assert_int(p.stats.value_of("bonus_prestige")).is_equal(100)
	assert_int(p.level()).is_equal(2)


func test_streak_feeds_stats_and_points() -> void:
	var p: MHProgression = MHProgressionFixture.progression()
	for day: int in range(3):
		p.record_active_day(day)
	assert_int(p.stats.value_of("streak_best")).is_equal(3)
	assert_int(p.stats.value_of("active_days")).is_equal(3)
	assert_int(int(p.points_breakdown()["streak"])).is_equal(10)
	var r: Dictionary = p.refresh()
	assert_bool(p.is_achievement_unlocked("streak_three")).is_true()
	assert_int((r["new_achievements"] as Array).size()).is_equal(1)
	assert_int(p.club_points()).is_equal(15)


func test_observe_helpers_for_other_modules() -> void:
	var p: MHProgression = MHProgressionFixture.progression()
	var ts: MHTournamentState = MHTournamentState.new()
	ts.from_save_block({"hosted_levels": ["local"], "cooldown_until_day": 0})
	p.observe_tournaments(ts)
	assert_int(p.stats.value_of("hosted_local")).is_equal(1)
	assert_int(p.stats.value_of("tournaments_hosted")).is_equal(1)
	var ds: MHDailyState = MHDailyState.new()
	ds.record_attempt(3, true, 800, 800)
	p.observe_daily(ds)
	assert_int(p.stats.value_of("challenges_attempted")).is_equal(1)
	assert_int(p.stats.value_of("challenges_completed")).is_equal(1)
	assert_int(int(p.points_breakdown()["challenges"])).is_equal(10)


func test_save_ids_filter_unknown_and_duplicates() -> void:
	var p: MHProgression = MHProgressionFixture.progression()
	var dropped: int = p.load_save_ids(["first_hole", "retired_one", "first_hole", "nine_holes"])
	assert_int(dropped).is_equal(2)
	var ids: Array = p.to_save_ids()
	assert_int(ids.size()).is_equal(2)
	assert_str(str(ids[0])).is_equal("first_hole")
	assert_int(int(p.points_breakdown()["achievements"])).is_equal(15)
	# loaded ids are not unlocked again
	p.stats.observe({"holes_max": 9})
	assert_int((p.refresh()["new_achievements"] as Array).size()).is_equal(0)


func test_round_trip_and_json_round_trip() -> void:
	var p: MHProgression = _rich()
	p.record_active_day(10)
	p.record_active_day(11)
	p.refresh()
	var d: Dictionary = p.to_dict()
	var q: MHProgression = MHProgressionFixture.progression()
	assert_bool(q.from_dict(d)).is_true()
	assert_int(q.club_points()).is_equal(p.club_points())
	assert_int(q.level()).is_equal(p.level())
	assert_int(q.streak.current).is_equal(2)
	assert_int(q.unlocked_ids().size()).is_equal(p.unlocked_ids().size())
	assert_bool(q.to_dict() == d).is_true()
	var parsed: Variant = JSON.parse_string(JSON.stringify(d))
	var r: MHProgression = MHProgressionFixture.progression()
	assert_bool(r.from_dict(parsed as Dictionary)).is_true()
	assert_int(r.club_points()).is_equal(p.club_points())
	assert_bool(r.to_dict() == d).is_true()


func test_bad_saves_change_nothing() -> void:
	var p: MHProgression = _rich()
	var before: int = p.club_points()
	assert_bool(p.from_dict({"v": 5})).is_false()
	assert_bool(p.from_dict({"v": 1, "stats": {}, "streak": {}, "unlocked": []})).is_false()
	assert_int(p.club_points()).is_equal(before)


func test_achievement_rows_for_the_screen() -> void:
	var p: MHProgression = _rich()
	p.refresh()
	var rows: Array = p.achievement_rows()
	assert_int(rows.size()).is_equal(61)
	var earned: int = 0
	for r: Variant in rows:
		if bool((r as Dictionary)["earned"]):
			earned += 1
	assert_int(earned).is_equal(11)


func test_rejects_bad_progression_data() -> void:
	var a: MHAchievements = MHProgressionFixture.achievements()
	var raw: Dictionary = MHDataJson.load_file(MHProgressionFixture.PROGRESSION_PATH)["value"]
	var p: MHProgression = MHProgression.new()
	assert_bool(p.load_from_dict(raw)).is_false()
	assert_str(p.load_error).is_equal("achievements not loaded")
	p.achievements = a
	assert_bool(p.load_from_dict(raw)).is_true()
	var raw2: Dictionary = MHDataJson.load_file(MHProgressionFixture.PROGRESSION_PATH)["value"]
	MHTestEdit.put(raw2, ["levels", 1, "prestige_needed"], 0)
	assert_bool(MHProgressionFixture.progression().load_from_dict(raw2)).is_false()
	var raw3: Dictionary = MHDataJson.load_file(MHProgressionFixture.PROGRESSION_PATH)["value"]
	MHTestEdit.put(raw3, ["levels", 0, "prestige_needed"], 5)
	var p3: MHProgression = MHProgression.new()
	p3.achievements = a
	assert_bool(p3.load_from_dict(raw3)).is_false()
	var raw4: Dictionary = MHDataJson.load_file(MHProgressionFixture.PROGRESSION_PATH)["value"]
	MHTestEdit.put(raw4, ["milestones", "per_hole"], -1)
	var p4: MHProgression = MHProgression.new()
	p4.achievements = a
	assert_bool(p4.load_from_dict(raw4)).is_false()

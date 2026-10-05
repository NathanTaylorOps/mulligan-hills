extends GdUnitTestSuite
## MHDailyChallenge, MHKillSwitch. Golden challenges come from an independent Python mirror of the generation
## algorithm (scratch script, uses tools/reference/determinism/mh_rng.py). NOT YET RUN in Godot.

const DATA_PATH: String = "res://data/daily_challenges.json"
const DOCS_COPY: String = "../docs/spec/data/daily_challenges.json"


func _ch() -> MHDailyChallenge:
	var c: MHDailyChallenge = MHDailyChallenge.new()
	c.load_from_file(DATA_PATH)
	return c


func test_shipped_data_loads() -> void:
	var c: MHDailyChallenge = MHDailyChallenge.new()
	assert_bool(c.load_from_file(DATA_PATH)).is_true()
	assert_str(c.load_error).is_equal("")
	assert_int(c.template_count()).is_equal(12)
	assert_int(c.attempts_per_day()).is_equal(3)
	assert_int(c.history_days()).is_equal(30)
	assert_int(c.local_board_cap()).is_equal(90)


func test_unloaded_generates_nothing() -> void:
	var c: MHDailyChallenge = MHDailyChallenge.new()
	assert_bool(c.generate(5).is_empty()).is_true()
	assert_bool(_ch().generate(-1).is_empty()).is_true()


func test_golden_day_0() -> void:
	var g: Dictionary = _ch().generate(0)
	assert_str(str(g["template_id"])).is_equal("gem_par3")
	assert_int(int(g["difficulty"])).is_equal(0)
	assert_int(int(g["par"])).is_equal(3)
	assert_int(int((g["axis_min"] as Dictionary)["beauty"])).is_equal(50)
	assert_int((g["axis_max"] as Dictionary).size()).is_equal(0)
	assert_int(int(g["max_length_yd"])).is_equal(190)
	assert_bool(g.has("min_score")).is_false()
	assert_int(int(g["target_score"])).is_equal(50)
	assert_int(int(g["sim_seed"])).is_equal(1112932578)
	assert_int(int(g["challenge_id"])).is_equal(0)
	assert_str(str(g["title_key"])).is_equal("challenge.gem_par3.title")
	assert_str(str(g["desc_key"])).is_equal("challenge.gem_par3.desc")


func test_golden_days_1_and_3() -> void:
	var g1: Dictionary = _ch().generate(1)
	assert_str(str(g1["template_id"])).is_equal("fair_play")
	assert_int(int(g1["par"])).is_equal(5)
	assert_int(int((g1["axis_min"] as Dictionary)["fairness"])).is_equal(60)
	assert_int(int(g1["min_score"])).is_equal(45)
	assert_int(int(g1["target_score"])).is_equal(45)
	assert_int(int(g1["sim_seed"])).is_equal(3118481572)
	var g3: Dictionary = _ch().generate(3)
	assert_str(str(g3["template_id"])).is_equal("length_axis_light")
	assert_int(int(g3["difficulty"])).is_equal(2)
	assert_int(int(g3["par"])).is_equal(3)
	assert_int(int((g3["axis_min"] as Dictionary)["imagination"])).is_equal(60)
	assert_int(int((g3["axis_max"] as Dictionary)["length"])).is_equal(40)
	assert_int(int(g3["min_score"])).is_equal(55)
	assert_int(int(g3["sim_seed"])).is_equal(1737800550)


func test_golden_current_era_days() -> void:
	var c: MHDailyChallenge = _ch()
	var a: Dictionary = c.generate(20000)
	assert_str(str(a["template_id"])).is_equal("straight_and_true_par4")
	assert_int(int((a["axis_min"] as Dictionary)["accuracy"])).is_equal(55)
	assert_int(int((a["axis_min"] as Dictionary)["fairness"])).is_equal(55)
	assert_int(int(a["max_length_yd"])).is_equal(475)
	assert_int(int(a["target_score"])).is_equal(55)
	assert_int(int(a["sim_seed"])).is_equal(2744482057)
	var b: Dictionary = c.generate(20001)
	assert_str(str(b["template_id"])).is_equal("all_rounder")
	var bmin: Dictionary = b["axis_min"]
	assert_int(bmin.size()).is_equal(4)
	assert_int(int(bmin["accuracy"])).is_equal(40)
	assert_int(int(b["min_score"])).is_equal(45)
	var l: Dictionary = c.generate(20454)
	assert_str(str(l["template_id"])).is_equal("long_haul_par5")
	assert_int(int(l["min_length_yd"])).is_equal(560)
	assert_bool(l.has("max_length_yd")).is_false()
	var m: Dictionary = c.generate(20455)
	assert_str(str(m["template_id"])).is_equal("clever_par3")
	assert_int(int(m["difficulty"])).is_equal(1)
	assert_int(int((m["axis_min"] as Dictionary)["accuracy"])).is_equal(60)
	assert_int(int((m["axis_min"] as Dictionary)["imagination"])).is_equal(65)
	assert_int(int(m["max_length_yd"])).is_equal(175)
	assert_int(int(m["target_score"])).is_equal(63)
	var n: Dictionary = c.generate(25000)
	assert_str(str(n["template_id"])).is_equal("straight_and_true_par4")
	assert_int(int(n["difficulty"])).is_equal(1)
	assert_int(int(n["max_length_yd"])).is_equal(445)


func test_same_day_same_challenge_every_time() -> void:
	var c1: MHDailyChallenge = _ch()
	var c2: MHDailyChallenge = _ch()
	for day: int in [0, 7, 365, 20455, 99999]:
		assert_bool(c1.generate(day) == c2.generate(day)).is_true()
		assert_bool(c1.generate(day) == c1.generate(day)).is_true()


func test_difficulty_and_template_mix_over_400_days() -> void:
	var c: MHDailyChallenge = _ch()
	var diffs: Array = [0, 0, 0]
	var seen: Dictionary = {}
	for day: int in range(400):
		var g: Dictionary = c.generate(day)
		diffs[int(g["difficulty"])] = int(diffs[int(g["difficulty"])]) + 1
		seen[str(g["template_id"])] = true
	# python mirror: difficulty counts 192 / 146 / 62, all 12 templates appear
	assert_int(int(diffs[0])).is_equal(192)
	assert_int(int(diffs[1])).is_equal(146)
	assert_int(int(diffs[2])).is_equal(62)
	assert_int(seen.size()).is_equal(12)


func test_thresholds_stay_between_the_pair_ends() -> void:
	var c: MHDailyChallenge = _ch()
	for day: int in range(0, 600):
		var g: Dictionary = c.generate(day)
		var t: Dictionary = c.template_by_id(str(g["template_id"]))
		assert_bool((t["par"] as Array).has(int(g["par"]))).is_true()
		var amin: Dictionary = g["axis_min"]
		for a: Variant in amin.keys():
			var pair: Array = (t["axis_min"] as Dictionary)[a]
			assert_int(int(amin[a])).is_between(mini(int(pair[0]), int(pair[1])), maxi(int(pair[0]), int(pair[1])))
		var amax: Dictionary = g["axis_max"]
		for a2: Variant in amax.keys():
			var pair2: Array = (t["axis_max"] as Dictionary)[a2]
			assert_int(int(amax[a2])).is_between(mini(int(pair2[0]), int(pair2[1])), maxi(int(pair2[0]), int(pair2[1])))
		if g.has("max_length_yd"):
			var p3: Array = t["max_length_yd"]
			assert_int(int(g["max_length_yd"])).is_between(mini(int(p3[0]), int(p3[1])), maxi(int(p3[0]), int(p3[1])))
			assert_int(int(g["max_length_yd"]) % 5).is_equal(0)
		assert_int(int(g["target_score"])).is_between(0, 100)


func test_hard_is_no_easier_than_easy() -> void:
	# a min-style pair rises with difficulty, a max-style pair falls: check the pair ends are respected in order
	var c: MHDailyChallenge = _ch()
	var low_hard: int = 100
	var high_easy: int = 0
	for day: int in range(0, 2000):
		var g: Dictionary = c.generate(day)
		if str(g["template_id"]) != "gem_par3":
			continue
		var beauty: int = int((g["axis_min"] as Dictionary)["beauty"])
		if int(g["difficulty"]) == 2:
			low_hard = mini(low_hard, beauty)
		if int(g["difficulty"]) == 0:
			high_easy = maxi(high_easy, beauty)
	# gem_par3 beauty pair is [50, 70]: hard is 70 minus at most one 5-step jitter (so 65 or more), easy is 50 plus
	# at most one jitter (so 55 or less)
	assert_int(low_hard).is_greater_equal(65)
	assert_int(high_easy).is_less_equal(55)


func test_sim_seed_is_the_public_daily_seed() -> void:
	var c: MHDailyChallenge = _ch()
	assert_int(c.sim_seed(0)).is_equal(1112932578)
	assert_int(c.sim_seed(5)).is_equal(MHRMath.daily_seed(5, 55825))


func test_kill_switch_stops_generation() -> void:
	var c: MHDailyChallenge = _ch()
	assert_bool(c.today(20455, {}).is_empty()).is_false()
	assert_bool(c.today(20455, {"daily_challenge": true}).is_empty()).is_false()
	assert_bool(c.today(20455, {"daily_challenge": false}).is_empty()).is_true()
	assert_bool(c.today(20455, {"daily_challenge": false, "tournaments": true}).is_empty()).is_true()
	assert_bool(c.today(20455, {"tournaments": false}).is_empty()).is_false()
	assert_bool(c.today(20455, {"daily_challenge": true}) == c.generate(20455)).is_true()


func test_kill_switch_reader_semantics() -> void:
	assert_bool(MHKillSwitch.is_on({}, "tournaments")).is_true()
	assert_bool(MHKillSwitch.is_on({"tournaments": false}, "tournaments")).is_false()
	assert_bool(MHKillSwitch.is_on({"tournaments": true}, "tournaments")).is_true()
	# fail open on anything that is not a boolean
	assert_bool(MHKillSwitch.is_on({"tournaments": 0}, "tournaments")).is_true()
	assert_bool(MHKillSwitch.is_on({"tournaments": "false"}, "tournaments")).is_true()
	assert_bool(MHKillSwitch.is_on({"tournaments": null}, "tournaments")).is_true()
	assert_bool(MHKillSwitch.is_on({"daily_challenge": false}, "tournaments")).is_true()
	assert_bool(MHDailyChallenge.is_feature_on({"daily_challenge": false})).is_false()
	assert_bool(MHDailyChallenge.is_feature_on({})).is_true()
	assert_int(MHKillSwitch.KEYS.size()).is_equal(6)


func test_day_number_and_rollover() -> void:
	assert_int(MHDailyChallenge.day_number_from_unix(0)).is_equal(0)
	assert_int(MHDailyChallenge.day_number_from_unix(86399)).is_equal(0)
	assert_int(MHDailyChallenge.day_number_from_unix(86400)).is_equal(1)
	assert_int(MHDailyChallenge.day_number_from_unix(1767225600)).is_equal(20454)
	assert_int(MHDailyChallenge.minutes_until_rollover(0)).is_equal(1440)
	assert_int(MHDailyChallenge.minutes_until_rollover(86400 - 60)).is_equal(1)
	assert_int(MHDailyChallenge.minutes_until_rollover(86400 - 1)).is_equal(1)
	assert_int(MHDailyChallenge.minutes_until_rollover(3600)).is_equal(1380)


func test_axes_from_rating() -> void:
	var axes: Dictionary = MHDailyChallenge.axes_from_rating({"A": 555, "I": 604, "Len": 0, "B": 1000, "F": 449})
	assert_int(int(axes["accuracy"])).is_equal(56)
	assert_int(int(axes["imagination"])).is_equal(60)
	assert_int(int(axes["length"])).is_equal(0)
	assert_int(int(axes["beauty"])).is_equal(100)
	assert_int(int(axes["fairness"])).is_equal(45)


func _entry(valid: bool, par: int, length_yd: int, score: int, axes: Dictionary) -> Dictionary:
	return {"valid": valid, "par": par, "length_yd": length_yd, "score": score, "axes": axes}


func test_evaluate_all_met() -> void:
	var g: Dictionary = _ch().generate(20455)
	# clever_par3: par 3, accuracy >= 60, imagination >= 65, length <= 175 yd, target 63
	var ok: Dictionary = MHDailyChallenge.evaluate(g, _entry(true, 3, 175, 70, {"accuracy": 60, "imagination": 65}))
	assert_bool(bool(ok["completed"])).is_true()
	var rows: Array = ok["rows"]
	assert_int(rows.size()).is_equal(5)
	assert_str(str((rows[0] as Array)[0])).is_equal("valid")
	assert_str(str((rows[2] as Array)[0])).is_equal("axis_min:accuracy")
	assert_str(str((rows[4] as Array)[0])).is_equal("max_length_yd")


func test_evaluate_reports_each_miss() -> void:
	var g: Dictionary = _ch().generate(20455)
	var bad: Dictionary = MHDailyChallenge.evaluate(g, _entry(true, 4, 176, 0, {"accuracy": 59, "imagination": 65}))
	assert_bool(bool(bad["completed"])).is_false()
	var met: Dictionary = {}
	for r: Variant in (bad["rows"] as Array):
		met[str((r as Array)[0])] = bool((r as Array)[1])
	assert_bool(bool(met["par"])).is_false()
	assert_bool(bool(met["axis_min:accuracy"])).is_false()
	assert_bool(bool(met["axis_min:imagination"])).is_true()
	assert_bool(bool(met["max_length_yd"])).is_false()
	var dead: Dictionary = MHDailyChallenge.evaluate(g, _entry(false, 3, 100, 90, {"accuracy": 100, "imagination": 100}))
	assert_bool(bool(dead["completed"])).is_false()


func test_evaluate_axis_max_min_length_and_min_score() -> void:
	var g: Dictionary = _ch().generate(3)
	# length_axis_light: par 3, imagination >= 60, length axis <= 40, min score 55
	var ok: Dictionary = MHDailyChallenge.evaluate(g, _entry(true, 3, 150, 55, {"imagination": 60, "length": 40}))
	assert_bool(bool(ok["completed"])).is_true()
	assert_bool(bool(MHDailyChallenge.evaluate(g, _entry(true, 3, 150, 55, {"imagination": 60, "length": 41}))["completed"])).is_false()
	assert_bool(bool(MHDailyChallenge.evaluate(g, _entry(true, 3, 150, 54, {"imagination": 60, "length": 40}))["completed"])).is_false()
	var g2: Dictionary = _ch().generate(20454)
	assert_bool(bool(MHDailyChallenge.evaluate(g2, _entry(true, 5, 560, 45, {"accuracy": 50}))["completed"])).is_true()
	assert_bool(bool(MHDailyChallenge.evaluate(g2, _entry(true, 5, 559, 45, {"accuracy": 50}))["completed"])).is_false()


func test_validation_rejects_bad_data() -> void:
	var raw: Dictionary = MHDataJson.load_file(DATA_PATH)["value"]
	var c: MHDailyChallenge = MHDailyChallenge.new()
	raw["attempts_per_day"] = 0
	assert_bool(c.load_from_dict(raw)).is_false()
	assert_bool(c.is_loaded()).is_false()
	var raw2: Dictionary = MHDataJson.load_file(DATA_PATH)["value"]
	raw2["difficulty_weights"] = [0, 0, 0]
	assert_bool(c.load_from_dict(raw2)).is_false()
	var raw3: Dictionary = MHDataJson.load_file(DATA_PATH)["value"]
	MHTestEdit.put(raw3, ["templates", 0, "par"], [6])
	assert_bool(c.load_from_dict(raw3)).is_false()
	var raw4: Dictionary = MHDataJson.load_file(DATA_PATH)["value"]
	MHTestEdit.put(raw4, ["templates", 1, "id"], "strategic_par4")
	assert_bool(c.load_from_dict(raw4)).is_false()
	assert_bool(c.load_from_text("not json")).is_false()


func test_game_copy_equals_docs_copy() -> void:
	var game_text: String = FileAccess.get_file_as_string(DATA_PATH)
	assert_bool(game_text.length() > 1000).is_true()
	var docs_path: String = ProjectSettings.globalize_path("res://").path_join(DOCS_COPY).simplify_path()
	if not FileAccess.file_exists(docs_path):
		return
	assert_str(FileAccess.get_file_as_string(docs_path).sha256_text()).is_equal(game_text.sha256_text())

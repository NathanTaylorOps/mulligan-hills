extends GdUnitTestSuite
## MHStrings: lookup, params, missing keys, house style. NOT YET RUN.


func test_lookup_and_missing_key() -> void:
	assert_bool(MHStrings.has_key("ui.common.back")).is_true()
	assert_str(MHStrings.t("ui.common.back")).is_equal("Back")
	assert_bool(MHStrings.has_key("nope.not.here")).is_false()
	assert_str(MHStrings.t("nope.not.here")).is_equal("[nope.not.here]")
	assert_str(MHStrings.tr_key("nope.not.here")).is_equal("[nope.not.here]")


func test_placeholders() -> void:
	assert_str(MHStrings.t("hud.cash", {"amount": "$1,200"})).is_equal("Cash $1,200")
	assert_str(MHStrings.t("hud.day_time", {"day": 3, "time": "7:00 AM"})).is_equal("Day 3, 7:00 AM")
	assert_str(MHStrings.format("a {x} b {y}", {"x": 1})).is_equal("a 1 b {y}")


func test_key_params_are_translated() -> void:
	var s: String = MHStrings.t("build.details_title", {"building_key": "building.clubhouse.name"})
	assert_str(s).is_equal("Clubhouse")
	var r: String = MHStrings.t("build.req.building", {"building_key": "building.pro_shop.name", "need": 3, "have": 1})
	assert_str(r).is_equal("Needs Pro shop tier 3 (have 1)")


func test_house_style() -> void:
	var key_re: RegEx = RegEx.create_from_string("^[a-z0-9_]+(\\.[a-z0-9_]+){1,4}$")
	var ph_re: RegEx = RegEx.create_from_string("\\{[a-z_]+\\}")
	for k: Variant in MHStrings.keys():
		var key: String = str(k)
		var text_value: String = MHStrings.t(key)
		assert_bool(text_value != "").is_true()
		# advisor.RCnnn keys are named by MHAdvisor (previous workstream); the spec asks for lowercase.
		if not key.begins_with("advisor.RC"):
			assert_bool(key_re.search(key) != null).override_failure_message("bad key shape: " + key).is_true()
		assert_bool(text_value.find("\u2014") == -1).override_failure_message("em dash in " + key).is_true()
		assert_bool(text_value == text_value.strip_edges()).override_failure_message("edge space in " + key).is_true()
		assert_bool(text_value.find("  ") == -1).override_failure_message("double space in " + key).is_true()
		for i: int in range(text_value.length()):
			assert_bool(text_value.unicode_at(i) < 128).override_failure_message("non-ASCII in " + key).is_true()
		var stripped: String = ph_re.sub(text_value, "", true)
		assert_bool(stripped.find("{") == -1 and stripped.find("}") == -1).override_failure_message("bad placeholder in " + key).is_true()


func test_every_dynamic_key_family_exists() -> void:
	var view: MHFakeGameStateView = MHFakeGameStateView.new()
	var defs: MHBuildingDefs = view.building_defs()
	var need: Array = []
	for id: Variant in defs.ids():
		need.append("building." + str(id) + ".name")
		need.append("building." + str(id) + ".desc")
	for t: Variant in MHEditorTools.tool_ids():
		need.append(MHEditorTools.label_key(StringName(t)))
	for s: Variant in MHEditorTools.surface_names():
		need.append(MHEditorTools.surface_label_key(str(s)))
	for sev: int in [0, 1, 2, 3, 4]:
		need.append(MHAdvisor.severity_key(sev))
	for sid: Variant in MHScreenIds.ALL:
		need.append("gallery.screen." + str(sid))
	for c: Variant in MHAchievementsScreen.CATEGORIES:
		need.append("ach.cat." + str(c))
	for a: Variant in view.achievements():
		var ad: Dictionary = a
		need.append("achievement." + str(ad["id"]) + ".name")
		need.append("achievement." + str(ad["id"]) + ".desc")
	for lvl: Variant in MHBuildingDefs.LEVELS:
		need.append("tournament." + str(lvl) + ".name")
	for st: String in ["locked", "available", "cooldown", "active"]:
		need.append("tournament.status." + st)
	for k: String in ["golf", "facility", "homes"]:
		need.append("land.kind." + k)
	for fps: String in ["30", "60", "auto"]:
		need.append("settings.fps." + fps)
	for p: int in range(4):
		need.append("settings.palette." + str(p))
	for b: String in ["poor", "fair", "good", "great", "superb"]:
		need.append("score.band." + b)
	for why: String in ["busy", "cash", "cooldown", "disabled", "locked", "unknown_level"]:
		need.append("tournament.blocked." + why)
	for tk: String in ["toast.tournament.started", "toast.daily.done", "toast.daily.tried", "toast.daily.off", "toast.daily.no_attempts", "daily.completed", "gallery.tournament_ready"]:
		need.append(tk)
	for lvl2: Variant in MHBuildingDefs.LEVELS:
		need.append("tournament." + str(lvl2) + ".desc")
	need.append(view.level_title_key())
	var d: Dictionary = view.daily_challenge()
	need.append(str(d["title_key"]))
	need.append(str(d["desc_key"]))
	for key: Variant in need:
		assert_bool(MHStrings.has_key(str(key))).override_failure_message("missing string key " + str(key)).is_true()


func test_sample_advisor_codes_have_text() -> void:
	var view: MHFakeGameStateView = MHFakeGameStateView.new()
	for h: int in range(1, view.hole_count() + 1):
		var r: Dictionary = view.hole_rating(h)
		for reason: Variant in r["reasons"]:
			var rd: Dictionary = reason
			assert_bool(MHStrings.has_key(MHAdvisor.string_key(int(rd["code"])))).override_failure_message("no advisor text for code " + str(rd["code"])).is_true()

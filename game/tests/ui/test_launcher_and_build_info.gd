extends GdUnitTestSuite
## Pure-function tests. Must pass with or without res://build_info.json. NOT YET RUN.

func test_fallback_when_file_missing() -> void:
	var d: Dictionary = MHBuildInfo.load("res://__no_such_build_info__.json")
	assert_str(str(d["sha"])).is_equal("dev")
	assert_str(str(d["run_number"])).is_equal("dev")


func test_parse_bad_json_falls_back() -> void:
	assert_str(str(MHBuildInfo.parse("not json")["sha"])).is_equal("dev")
	assert_str(str(MHBuildInfo.parse("[1,2]")["sha"])).is_equal("dev")


func test_parse_partial_and_full() -> void:
	var d: Dictionary = MHBuildInfo.parse('{"sha":"abc1234","run_number":"42","renderer":""}')
	assert_str(str(d["sha"])).is_equal("abc1234")
	assert_str(str(d["run_number"])).is_equal("42")
	assert_str(str(d["renderer"])).is_equal("dev")
	assert_str(str(d["workflow"])).is_equal("dev")


func test_label_text() -> void:
	assert_str(MHBuildInfo.label_text(MHBuildInfo.fallback())).is_equal("Build: dev")
	var d: Dictionary = MHBuildInfo.parse('{"sha":"abc1234","run_number":"42","renderer":"compatibility","workflow":"Android debug APK","built_at":"2026-09-29T00:00:00Z"}')
	assert_str(MHBuildInfo.label_text(d)).contains("#42")
	assert_str(MHBuildInfo.label_text(d)).contains("abc1234")


func test_label_text_default_never_empty() -> void:
	assert_str(MHBuildInfo.label_text()).is_not_empty()


func test_filter_entries() -> void:
	var entries: Array = [["A", "res://a.tscn"], ["B", "res://b.tscn"], ["bad"], ["C", "res://c.tscn"]]
	var out: Array = MHLauncher.filter_entries(entries, func(p: String) -> bool: return p != "res://b.tscn")
	assert_int(out.size()).is_equal(2)
	assert_str(str(out[0][0])).is_equal("A")
	assert_str(str(out[1][0])).is_equal("C")
	assert_int(MHLauncher.filter_entries([], func(_p: String) -> bool: return true).size()).is_equal(0)


func test_scene_list_paths_are_scene_files() -> void:
	for e: Variant in MHLauncher.SCENES:
		var entry: Array = e
		assert_bool(str(entry[1]).begins_with("res://") and str(entry[1]).ends_with(".tscn")).is_true()

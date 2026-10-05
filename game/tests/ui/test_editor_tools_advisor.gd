extends GdUnitTestSuite
## MHEditorTools and MHAdvisor (pure). NOT YET RUN.


func test_tools_map_to_brush_modes() -> void:
	assert_int(MHEditorTools.tool_ids().size()).is_equal(5)
	assert_int(MHEditorTools.brush_mode(MHEditorTools.RAISE)).is_equal(MHBrush.Mode.RAISE)
	assert_int(MHEditorTools.brush_mode(MHEditorTools.LOWER)).is_equal(MHBrush.Mode.LOWER)
	assert_int(MHEditorTools.brush_mode(MHEditorTools.SMOOTH)).is_equal(MHBrush.Mode.SMOOTH)
	assert_int(MHEditorTools.brush_mode(MHEditorTools.LEVEL)).is_equal(MHBrush.Mode.FLATTEN)
	assert_int(MHEditorTools.brush_mode(MHEditorTools.PAINT)).is_equal(MHBrush.Mode.PAINT)
	assert_int(MHEditorTools.brush_mode(&"bogus")).is_equal(MHBrush.Mode.RAISE)
	assert_bool(MHEditorTools.is_tool(&"paint")).is_true()
	assert_bool(MHEditorTools.is_tool(&"bogus")).is_false()


func test_surfaces_and_radius() -> void:
	assert_int(MHEditorTools.surface_names().size()).is_equal(11)
	assert_int(MHEditorTools.surface_layer("green")).is_equal(3)
	assert_int(MHEditorTools.surface_layer("nope")).is_equal(-1)
	assert_int(MHEditorTools.clamp_radius(0)).is_equal(MHEditorTools.RADIUS_MIN)
	assert_int(MHEditorTools.clamp_radius(99)).is_equal(MHEditorTools.RADIUS_MAX)
	assert_int(MHEditorTools.clamp_radius(8)).is_equal(8)
	assert_str(MHEditorTools.label_key(&"raise")).is_equal("editor.tool.raise")
	assert_str(MHEditorTools.surface_label_key("fairway")).is_equal("surface.fairway")


func test_advisor_sorting_and_limit() -> void:
	var rows: Array = [
		{"code": 5, "severity": MHAdvisor.SEV_WARN},
		{"code": 2, "severity": MHAdvisor.SEV_BLOCK},
		{"code": 9, "severity": MHAdvisor.SEV_SEVERE},
		{"code": 1, "severity": MHAdvisor.SEV_WARN},
		{"code": 7, "severity": MHAdvisor.SEV_PRAISE},
		{"severity": MHAdvisor.SEV_WARN},
	]
	var sorted: Array = MHAdvisor.sorted_reasons(rows)
	assert_int(sorted.size()).is_equal(5)
	var codes: Array = []
	for r: Variant in sorted:
		codes.append(int((r as Dictionary)["code"]))
	assert_array(codes).is_equal([2, 9, 1, 5, 7])
	var top: Array = MHAdvisor.top_reasons(rows)
	assert_int(top.size()).is_equal(MHAdvisor.MAX_SHOWN)
	assert_int(int((top[0] as Dictionary)["code"])).is_equal(2)
	assert_int(MHAdvisor.top_reasons([], 3).size()).is_equal(0)


func test_advisor_keys() -> void:
	assert_str(MHAdvisor.code_label(31)).is_equal("RC031")
	assert_str(MHAdvisor.string_key(31)).is_equal("advisor.RC031")
	assert_bool(MHAdvisor.is_praise(MHAdvisor.SEV_PRAISE)).is_true()
	assert_bool(MHAdvisor.is_praise(MHAdvisor.SEV_WARN)).is_false()
	assert_str(MHAdvisor.severity_key(MHAdvisor.SEV_BLOCK)).is_equal("advisor.sev.block")
	assert_str(MHAdvisor.severity_key(99)).is_equal("advisor.sev.info")

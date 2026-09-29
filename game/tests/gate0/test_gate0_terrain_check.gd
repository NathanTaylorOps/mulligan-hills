extends GdUnitTestSuite
## Item 5 scripted check on a small grid, plus the sink adapter. NOT YET RUN.

const PATH: String = "user://mh_gate0_test_terrain.mhts"


func after_test() -> void:
	for p: String in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			var d: DirAccess = DirAccess.open("user://")
			if d != null:
				d.remove(p.get_file())


func test_plan_is_deterministic_and_in_bounds() -> void:
	var a: Array = MHGate0TerrainCheck.make_plan(96, 64, 12, 7)
	var b: Array = MHGate0TerrainCheck.make_plan(96, 64, 12, 7)
	assert_int(a.size()).is_equal(12)
	for i: int in range(a.size()):
		var sa: Dictionary = a[i]
		var sb: Dictionary = b[i]
		var pa: PackedInt32Array = sa["points"]
		var pb: PackedInt32Array = sb["points"]
		assert_bool(pa == pb).is_true()
		assert_int(pa.size() % 2).is_equal(0)
		for k: int in range(pa.size() / 2):
			assert_bool(pa[k * 2] >= 0 and pa[k * 2] <= 96).is_true()
			assert_bool(pa[k * 2 + 1] >= 0 and pa[k * 2 + 1] <= 64).is_true()


func test_plan_differs_by_seed() -> void:
	var a: Array = MHGate0TerrainCheck.make_plan(96, 64, 3, 1)
	var b: Array = MHGate0TerrainCheck.make_plan(96, 64, 3, 2)
	var pa: PackedInt32Array = (a[0] as Dictionary)["points"]
	var pb: PackedInt32Array = (b[0] as Dictionary)["points"]
	assert_bool(pa == pb).is_false()


func test_full_check_passes_on_small_grid() -> void:
	var editor: MHTerrainEditor = MHGate0TerrainApi.make_editor(96, 64)
	var d: Dictionary = MHGate0TerrainCheck.run(editor, 10, PATH)
	assert_bool(bool(d["changed_by_strokes"])).is_true()
	assert_bool(bool(d["undo_restores_initial"])).is_true()
	assert_bool(bool(d["redo_restores_stroked"])).is_true()
	assert_bool(bool(d["cancel_leaves_no_residue"])).is_true()
	assert_bool(bool(d["heights_in_int16"])).is_true()
	assert_bool(bool(d["save_load_identical"])).is_true()
	assert_bool(bool(d["pass"])).is_true()
	assert_str(MHGate0TerrainCheck.format_result(d)).contains("RESULT: PASS")


func test_judge_fails_when_any_criterion_fails() -> void:
	var editor: MHTerrainEditor = MHGate0TerrainApi.make_editor(64, 64)
	var d: Dictionary = MHGate0TerrainCheck.run(editor, 6, PATH)
	assert_bool(MHGate0TerrainCheck.judge(d)).is_true()
	d["undo_restores_initial"] = false
	assert_bool(MHGate0TerrainCheck.judge(d)).is_false()


func test_sink_stroke_then_undo_restores_hash() -> void:
	var editor: MHTerrainEditor = MHGate0TerrainApi.make_editor(64, 64)
	var sink: MHGate0TerrainSink = MHGate0TerrainSink.new(editor)
	var h0: int = MHGate0TerrainApi.content_hash(editor)
	sink.begin_stroke()
	sink.apply_brush_at(20, 20)
	sink.apply_brush_at(30, 24)
	sink.end_stroke()
	assert_int(sink.strokes_committed).is_equal(1)
	assert_bool(MHGate0TerrainApi.content_hash(editor) != h0).is_true()
	assert_bool(sink.undo()).is_true()
	assert_int(MHGate0TerrainApi.content_hash(editor)).is_equal(h0)
	assert_bool(sink.redo()).is_true()
	assert_bool(MHGate0TerrainApi.content_hash(editor) != h0).is_true()


func test_sink_cancel_rolls_back() -> void:
	var editor: MHTerrainEditor = MHGate0TerrainApi.make_editor(64, 64)
	var sink: MHGate0TerrainSink = MHGate0TerrainSink.new(editor)
	var h0: int = MHGate0TerrainApi.content_hash(editor)
	sink.begin_stroke()
	sink.apply_brush_at(20, 20)
	sink.apply_brush_at(28, 20)
	sink.cancel_stroke()
	assert_int(MHGate0TerrainApi.content_hash(editor)).is_equal(h0)
	assert_int(sink.strokes_cancelled).is_equal(1)
	assert_int(sink.strokes_committed).is_equal(0)
	assert_int(MHGate0TerrainApi.undo_count(editor)).is_equal(0)


func test_sink_ignores_dab_without_stroke() -> void:
	var editor: MHTerrainEditor = MHGate0TerrainApi.make_editor(64, 64)
	var sink: MHGate0TerrainSink = MHGate0TerrainSink.new(editor)
	var h0: int = MHGate0TerrainApi.content_hash(editor)
	sink.apply_brush_at(10, 10)
	assert_int(MHGate0TerrainApi.content_hash(editor)).is_equal(h0)
	assert_int(sink.dabs).is_equal(0)

extends GdUnitTestSuite
## MHLiveLayout zone maths, MHOrientation and MHTouchBridge clipping. Pure, no scene. NOT YET RUN.

const WIDTHS: Array = [96.0, 160.0, 180.0]
## [viewport units, touch_min units]. Viewports follow canvas_items + expand from base 1280x720:
## S22 Ultra landscape 2340x1080 -> 1560x720; portrait 1080x2340 -> 1280x2773; small phone 1280x720 at 320 dpi.
const CASES: Array = [
	[Vector2(1560, 720), 75.0],
	[Vector2(1280, 2773), 178.0],
	[Vector2(1280, 720), 48.0],
	[Vector2(1280, 720), 96.0],
	[Vector2(720, 1280), 84.0],
	[Vector2(1024, 768), 60.0],
]


## What a HUD leaves free: gutter all round, two top rows (chips and speed buttons), one bottom nav row.
func _free(vp: Vector2, tm: float) -> Rect2:
	var top: float = 12.0 + tm + 8.0 + tm + 8.0
	var bottom: float = 12.0 + tm + 8.0
	return Rect2(12.0, top, vp.x - 24.0, vp.y - top - bottom)


func _zones(c: Array, state: int, mirror: bool = false) -> Dictionary:
	var vp: Vector2 = c[0]
	var tm: float = c[1]
	return MHLiveLayout.compute(_free(vp, tm), tm, 30.0, state, WIDTHS, mirror)


func _rects(z: Dictionary) -> Array:
	return [z["actions"], z["status"], z["panel"]]


func test_zones_never_overlap_and_stay_inside_free_rect() -> void:
	for c: Variant in CASES:
		var cs: Array = c
		var free: Rect2 = _free(cs[0], cs[1])
		for state: int in [MHLiveLayout.PanelState.HIDDEN, MHLiveLayout.PanelState.COLLAPSED, MHLiveLayout.PanelState.OPEN]:
			for mirror: bool in [false, true]:
				var z: Dictionary = _zones(cs, state, mirror)
				var rects: Array = _rects(z)
				for i: int in range(rects.size()):
					var a: Rect2 = rects[i]
					if a.size.x <= 0.0 or a.size.y <= 0.0:
						continue
					assert_bool(free.grow(0.01).encloses(a)).override_failure_message("zone %d outside free rect, cs %s state %d" % [i, str(cs[0]), state]).is_true()
					for j: int in range(i + 1, rects.size()):
						assert_bool(MHLiveLayout.overlaps(a, rects[j] as Rect2)).override_failure_message("zones %d and %d overlap, cs %s state %d mirror %s" % [i, j, str(cs[0]), state, str(mirror)]).is_false()


func test_touch_targets_and_status_width() -> void:
	for c: Variant in CASES:
		var cs: Array = c
		var tm: float = cs[1]
		for state: int in [MHLiveLayout.PanelState.COLLAPSED, MHLiveLayout.PanelState.OPEN]:
			var z: Dictionary = _zones(cs, state)
			var actions: Rect2 = z["actions"]
			var status: Rect2 = z["status"]
			var panel: Rect2 = z["panel"]
			assert_float(actions.size.y).is_greater_equal(tm)
			assert_float(actions.size.x).is_greater_equal(160.0)
			assert_float(status.size.x).is_greater_equal(160.0) # Never the zero-width column of the old bug.
			assert_float(panel.size.y).is_greater_equal(tm + 2.0 * MHLiveLayout.PANEL_PAD_V)


func test_landscape_uses_side_column_and_portrait_uses_bottom_sheet() -> void:
	var land: Dictionary = _zones(CASES[0], MHLiveLayout.PanelState.OPEN)
	assert_bool(land["landscape"]).is_true()
	var free_l: Rect2 = _free(CASES[0][0], CASES[0][1])
	var lp: Rect2 = land["panel"]
	assert_float(lp.end.x).is_equal_approx(free_l.end.x, 0.01)
	assert_float(lp.size.y).is_equal_approx(free_l.size.y, 0.01)
	assert_float((land["actions"] as Rect2).end.x).is_less(lp.position.x)
	var port: Dictionary = _zones(CASES[1], MHLiveLayout.PanelState.OPEN)
	assert_bool(port["landscape"]).is_false()
	var free_p: Rect2 = _free(CASES[1][0], CASES[1][1])
	var pp: Rect2 = port["panel"]
	assert_float(pp.end.y).is_equal_approx(free_p.end.y, 0.01)
	assert_float(pp.size.x).is_equal_approx(free_p.size.x, 0.01)
	assert_float(pp.size.y).is_less_equal(free_p.size.y * 0.5 + 0.01)
	assert_float(pp.position.y).is_greater((port["status"] as Rect2).end.y)


func test_mirror_puts_panel_on_the_left() -> void:
	var z: Dictionary = _zones(CASES[0], MHLiveLayout.PanelState.OPEN, true)
	var free: Rect2 = _free(CASES[0][0], CASES[0][1])
	assert_float((z["panel"] as Rect2).position.x).is_equal_approx(free.position.x, 0.01)
	assert_float((z["actions"] as Rect2).position.x).is_greater((z["panel"] as Rect2).end.x)


func test_hidden_panel_gives_no_panel_zone_and_full_width_column() -> void:
	var z: Dictionary = _zones(CASES[0], MHLiveLayout.PanelState.HIDDEN)
	var free: Rect2 = _free(CASES[0][0], CASES[0][1])
	assert_float((z["panel"] as Rect2).size.x).is_equal(0.0)
	assert_float((z["actions"] as Rect2).size.x).is_equal_approx(free.size.x, 0.01)


func test_collapsed_panel_is_header_height() -> void:
	for c: Variant in CASES:
		var cs: Array = c
		var z: Dictionary = _zones(cs, MHLiveLayout.PanelState.COLLAPSED)
		assert_float((z["panel"] as Rect2).size.y).is_equal_approx(MHLiveLayout.panel_header_height(cs[1]), 0.01)


func test_flow_rows_wrap() -> void:
	assert_int(MHLiveLayout.flow_rows([], 8.0, 500.0)).is_equal(0)
	assert_int(MHLiveLayout.flow_rows([96.0, 160.0, 180.0], 8.0, 1000.0)).is_equal(1)
	assert_int(MHLiveLayout.flow_rows([96.0, 160.0, 180.0], 8.0, 300.0)).is_equal(2)
	assert_int(MHLiveLayout.flow_rows([96.0, 160.0, 180.0], 8.0, 170.0)).is_equal(3)
	assert_float(MHLiveLayout.flow_height(2, 48.0, 8.0)).is_equal(104.0)
	assert_float(MHLiveLayout.flow_height(0, 48.0, 8.0)).is_equal(0.0)


func test_tiny_free_rect_still_never_overlaps() -> void:
	var z: Dictionary = MHLiveLayout.compute(Rect2(0, 0, 400, 120), 96.0, 30.0, MHLiveLayout.PanelState.OPEN, WIDTHS)
	assert_bool(z["fits"]).is_false()
	var rects: Array = _rects(z)
	for i: int in range(rects.size()):
		for j: int in range(i + 1, rects.size()):
			assert_bool(MHLiveLayout.overlaps(rects[i] as Rect2, rects[j] as Rect2)).is_false()
	assert_bool(MHLiveLayout.compute(Rect2(), 48.0, 30.0, MHLiveLayout.PanelState.OPEN, WIDTHS)["fits"]).is_false()


func test_orientation_policy() -> void:
	assert_int(MHOrientation.sanitize(4, 6)).is_equal(4)
	assert_int(MHOrientation.sanitize(9, 6)).is_equal(6)
	assert_int(MHOrientation.sanitize(-1, 4)).is_equal(4)
	assert_bool(MHOrientation.is_landscape_only(MHOrientation.SENSOR_LANDSCAPE)).is_true()
	assert_bool(MHOrientation.is_landscape_only(MHOrientation.SENSOR)).is_false()
	assert_bool(MHOrientation.is_landscape_only(MHOrientation.PORTRAIT)).is_false()
	assert_bool(MHOrientation.is_landscape_only(MHOrientation.DEFAULT_GAME)).is_true()


func test_touch_bridge_clipping() -> void:
	var r: Rect2 = Rect2(0, 100, 100, 50)
	assert_bool(MHTouchBridge.clipped(r, []) == r).is_true()
	var inside: Rect2 = MHTouchBridge.clipped(r, [Rect2(0, 0, 100, 120)])
	assert_float(inside.size.y).is_equal_approx(20.0, 0.001)
	assert_bool(MHTouchBridge.clipped(r, [Rect2(0, 0, 100, 90)]).has_area()).is_false()
	assert_bool(MHTouchBridge.clipped(r, [Rect2(0, 0, 100, 90)]).has_point(Vector2(50, 120))).is_false()



func test_editor_dock_uses_safe_width_and_leaves_world_space() -> void:
	for c: Variant in CASES:
		var cs: Array = c
		var free: Rect2 = _free(cs[0], cs[1])
		for wanted: float in [80.0, 260.0, 5000.0]:
			var dock: Rect2 = MHLiveLayout.editor_dock_rect(free, wanted)
			assert_bool(free.grow(0.01).encloses(dock)).is_true()
			assert_float(dock.size.x).is_equal_approx(free.size.x, 0.01)
			assert_float(dock.end.y).is_equal_approx(free.end.y, 0.01)
			assert_float(dock.position.y - free.position.y).is_greater_equal(free.size.y * MHLiveLayout.WORLD_MIN_FRACTION - 0.01)
	assert_bool(MHLiveLayout.editor_dock_rect(Rect2(), 260.0).has_area()).is_false()


func test_touch_bridge_splits_nested_scroll_axes() -> void:
	var bridge: MHTouchBridge = auto_free(MHTouchBridge.new())
	add_child(bridge)
	var outer: MHScrollBox = auto_free(MHScrollBox.new())
	outer.position = Vector2.ZERO
	outer.size = Vector2(300, 200)
	outer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(outer)
	var inner: MHScrollBox = MHScrollBox.new()
	inner.position = Vector2.ZERO
	inner.size = Vector2(300, 100)
	inner.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	inner.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(inner)
	await get_tree().process_frame
	var targets: Dictionary = bridge._scroll_targets_at(Vector2(20, 20))
	assert_object(targets["horizontal"]).is_same(inner)
	assert_object(targets["vertical"]).is_same(outer)

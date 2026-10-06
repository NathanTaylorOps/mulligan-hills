extends GdUnitTestSuite
## MHSliceText HUD helpers plus the build-menu rows read from a real session. NOT YET RUN in Godot.


func test_building_title() -> void:
	assert_str(MHSliceText.building_title("pro_shop")).is_equal("Pro Shop")
	assert_str(MHSliceText.building_title("clubhouse")).is_equal("Clubhouse")


func test_reason_text() -> void:
	assert_str(MHSliceText.reason_text({"key": "build.req.holes", "have": 2, "need": 6})).is_equal("holes 2/6")
	assert_str(MHSliceText.reason_text({"key": "build.req.avg_score", "have": 22, "need": 32})).is_equal("avg score 22/32")
	assert_str(MHSliceText.reason_text({})).is_equal("requirement 0/0")


func test_income_per_hour() -> void:
	assert_int(MHSliceText.income_per_hour_dollars(121000)).is_equal(110)
	assert_int(MHSliceText.income_per_hour_dollars(0)).is_equal(0)


func test_hud_and_detail_lines() -> void:
	var line: String = MHSliceText.hud_line(1234, 0, 0, 392, 110, 5)
	assert_bool(line.contains("Cash $1,234")).is_true()
	assert_bool(line.contains("Day 1")).is_true()
	assert_bool(line.contains("7:00 AM")).is_true()
	assert_bool(line.contains("Rating 39.2")).is_true()
	assert_bool(line.contains("Income $110/hr")).is_true()
	assert_bool(line.contains("Golfers 5")).is_true()
	var detail: String = MHSliceText.detail_line(8, -250, 2, 0)
	assert_bool(detail.contains("Green fee $8")).is_true()
	assert_bool(detail.contains("Net -$250/day")).is_true()


func test_row_summary_and_buy_label_for_synthetic_rows() -> void:
	var ready: Dictionary = {"id": "pro_shop", "owned_tier": 0, "next_tier": 1, "maxed": false, "met": true,
		"demo_locked": false, "income": 300, "cost": 900, "reasons": []}
	assert_str(MHSliceText.row_summary(ready)).is_equal("Pro Shop  not built  next T1  +$300/day")
	assert_str(MHSliceText.buy_label(ready, 1200)).is_equal("Buy T1 $1,200")
	var locked: Dictionary = ready.duplicate()
	locked["met"] = false
	locked["owned_tier"] = 1
	locked["next_tier"] = 2
	locked["reasons"] = [{"key": "build.req.holes", "have": 2, "need": 6}, {"key": "build.req.avg_score", "have": 22, "need": 32},
		{"key": "build.req.parcels", "have": 5, "need": 6}]
	assert_str(MHSliceText.row_summary(locked)).is_equal("Pro Shop  T1  needs holes 2/6, avg score 22/32")
	var maxed: Dictionary = ready.duplicate()
	maxed["maxed"] = true
	maxed["owned_tier"] = 5
	assert_str(MHSliceText.row_summary(maxed)).is_equal("Pro Shop  T5 (max)")
	assert_str(MHSliceText.buy_label(maxed, 0)).is_equal("-")
	var demo: Dictionary = ready.duplicate()
	demo["demo_locked"] = true
	assert_str(MHSliceText.buy_label(demo, 5)).is_equal("-")
	assert_str(MHSliceText.row_summary({})).is_equal("")
	assert_str(MHSliceText.buy_label({}, 5)).is_equal("-")


func test_real_menu_rows_for_a_fresh_session() -> void:
	var s: MHGameSession = MHGameSession.create()
	assert_object(s).is_not_null()
	var view: MHLiveGameStateView = MHLiveGameStateView.new(s)
	var row: Dictionary = MHBuildMenuModel.row(view, "clubhouse")
	assert_int(int(row["next_tier"])).is_equal(1)
	assert_bool(bool(row["met"])).is_true()
	var text: String = MHSliceText.row_summary(row)
	assert_bool(text.begins_with("Clubhouse  not built")).is_true()
	s.demo = false # Homes are demo-locked; with the full game they only miss the homes parcel.
	var homes: Dictionary = MHBuildMenuModel.row(view, "homes")
	assert_bool(bool(homes["met"])).is_false()
	assert_bool(MHSliceText.row_summary(homes).contains("needs")).is_true()

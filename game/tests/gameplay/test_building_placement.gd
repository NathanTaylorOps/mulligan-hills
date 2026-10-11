class_name TestBuildingPlacement
extends GdUnitTestSuite

func _world() -> Array:
	var g: MHHeightGrid = MHHeightGrid.new(128, 128, 1000)
	var s: MHSplatMap = MHSplatMap.new(g.samples_x, g.samples_y)
	var defs: MHBuildingDefs = MHBuildingDefs.load_default()
	var land: MHLandModel = MHLandModel.create(defs)
	return [g, s, land]


func test_flat_owned_ground_accepts_freeform_position_and_seats_on_ground() -> void:
	var w: Array = _world()
	var g: MHHeightGrid = w[0]
	g.fill(2250)
	var r: Dictionary = MHBuildingPlacement.validate(g, w[1], w[2], "clubhouse", 1, Vector2i(48000, 48000))
	assert_bool(bool(r["ok"])).is_true()
	assert_int(int(r["ground_mm"])).is_equal(2250)


func test_water_anywhere_under_footprint_rejects_placement() -> void:
	var w: Array = _world()
	var s: MHSplatMap = w[1]
	s.paint_disc(48, 48, 2, MHSplatMap.Layer.WATER, 1000)
	var r: Dictionary = MHBuildingPlacement.validate(w[0], s, w[2], "clubhouse", 1, Vector2i(48000, 48000))
	assert_bool(bool(r["ok"])).is_false()
	assert_str(str(r["reason"])).is_equal("hazard")


func test_cliff_like_relief_rejects_placement() -> void:
	var w: Array = _world()
	var g: MHHeightGrid = w[0]
	for y: int in range(g.samples_y):
		for x: int in range(g.samples_x):
			g.set_h(x, y, 0 if x < 48 else 5000)
	var r: Dictionary = MHBuildingPlacement.validate(g, w[1], w[2], "restaurant", 1, Vector2i(48000, 48000))
	assert_bool(bool(r["ok"])).is_false()
	assert_str(str(r["reason"])).is_equal("terrain_relief")


func test_existing_building_clearance_rejects_overlap() -> void:
	var w: Array = _world()
	var existing: Array = [{"center_mm": [48000, 48000], "size_m": [18, 14]}]
	var r: Dictionary = MHBuildingPlacement.validate(w[0], w[1], w[2], "pro_shop", 1, Vector2i(52000, 48000), existing)
	assert_bool(bool(r["ok"])).is_false()
	assert_str(str(r["reason"])).is_equal("building_overlap")


func test_rotation_swaps_rectangular_footprint() -> void:
	var w: Array = _world()
	var a: Dictionary = MHBuildingPlacement.validate(w[0], w[1], w[2], "clubhouse", 1, Vector2i(48000, 48000), [], 0)
	var b: Dictionary = MHBuildingPlacement.validate(w[0], w[1], w[2], "clubhouse", 1, Vector2i(48000, 48000), [], 1)
	assert_bool(bool(a["ok"])).is_true()
	assert_bool(bool(b["ok"])).is_true()
	assert_array(a["size_m"]).is_equal([18, 14])
	assert_array(b["size_m"]).is_equal([14, 18])


func test_finalized_fairway_rejects_building_even_on_flat_ground() -> void:
	var w: Array = _world()
	var hole: Dictionary = {"slot_id": 0, "tee": [0, 0], "green": [0, 60, 5],
		"features": [{"t": "fairway", "rect": [-8, 0, 8, 60]}]}
	# First Real Round origin is around 48m,34m; this footprint intersects its fairway.
	var r: Dictionary = MHBuildingPlacement.validate(w[0], w[1], w[2], "pro_shop", 1, Vector2i(48000, 50000), [], 0, [hole])
	assert_bool(bool(r["ok"])).is_false()
	assert_str(str(r["reason"])).is_equal("golf_feature")


func test_tree_or_decor_obstacle_rejects_footprint() -> void:
	var w: Array = _world()
	var obstacles: Array = [{"kind": "tree", "x_mm": 48000, "y_mm": 48000, "radius_mm": 1800}]
	var r: Dictionary = MHBuildingPlacement.validate(w[0], w[1], w[2], "pro_shop", 1,
		Vector2i(48000, 48000), [], 0, [], obstacles)
	assert_bool(bool(r["ok"])).is_false()
	assert_str(str(r["reason"])).is_equal("obstacle")


func test_nearby_obstacle_outside_footprint_is_allowed() -> void:
	var w: Array = _world()
	var obstacles: Array = [{"kind": "rock", "x_mm": 70000, "y_mm": 70000, "radius_mm": 1000}]
	var r: Dictionary = MHBuildingPlacement.validate(w[0], w[1], w[2], "pro_shop", 1,
		Vector2i(48000, 48000), [], 0, [], obstacles)
	assert_bool(bool(r["ok"])).is_true()


func test_golf_exclusion_uses_saved_hole_world_origin() -> void:
	var w: Dictionary = _world()
	var hole: Dictionary = {"slot_id": 0, "tee": [0, 0], "green": [0, 60, 5],
		"features": [{"t": "fairway", "rect": [-8, 0, 8, 60]}]}
	var course: Dictionary = {"holes": [{"hole_no": 1, "origin_dm": [700, 500], "layout": hole}]}
	var result: Dictionary = MHBuildingPlacement.validate(w["grid"], w["splat"], w["land"], "clubhouse", 1,
		Vector2i(70000, 50000), [], 0, [hole], [], course)
	assert_bool(bool(result["ok"])).is_false()
	assert_str(str(result["reason"])).is_equal("golf_feature")

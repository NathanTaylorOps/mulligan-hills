extends GdUnitTestSuite
## Rendering-side picking. NOT YET RUN.


func test_straight_down_ray_hits_cell_under_it() -> void:
	var g := MHHeightGrid.new(64, 64)
	var hit: Vector2i = MHPicking.pick(g, Vector3(20.2, 50.0, 30.4), Vector3(0, -1, 0))
	assert_int(hit.x).is_equal(20)
	assert_int(hit.y).is_equal(30)


func test_angled_ray_on_flat_ground() -> void:
	var g := MHHeightGrid.new(64, 64)
	# from (10, 10, 10) heading +x,+z and down at 45 degrees reaches y=0 at t where y drops 10: x=z=20 area
	var hit: Vector2i = MHPicking.pick(g, Vector3(10, 10, 10), Vector3(1, -1, 0))
	assert_int(hit.x).is_equal(20)
	assert_int(hit.y).is_equal(10)


func test_ray_hits_raised_hill_before_ground() -> void:
	var g := MHHeightGrid.new(64, 64)
	MHBrush.apply_dab(g, MHBrush.Mode.RAISE, 32, 32, 10, 8000, 0, null)
	var hit: Vector2i = MHPicking.pick(g, Vector3(32.0, 50.0, 32.0), Vector3(0, -1, 0))
	assert_int(hit.x).is_equal(32)
	assert_int(hit.y).is_equal(32)


func test_ray_pointing_up_misses() -> void:
	var g := MHHeightGrid.new(64, 64)
	assert_bool(MHPicking.pick(g, Vector3(20, 5, 20), Vector3(0, 1, 0), 200.0) == MHPicking.MISS).is_true()

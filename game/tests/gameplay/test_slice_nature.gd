extends GdUnitTestSuite
## MHSliceNature: deterministic scatter. Pure (MHArtRng, no scene tree). NOT YET RUN in Godot.


func test_same_seed_gives_the_same_scatter() -> void:
	var a: Array = MHSliceNature.scatter(123, 90)
	var b: Array = MHSliceNature.scatter(123, 90)
	assert_int(a.size()).is_equal(b.size())
	for i: int in range(a.size()):
		var da: Dictionary = a[i]
		var db: Dictionary = b[i]
		assert_str(str(da["kind"])).is_equal(str(db["kind"]))
		assert_int(int(da["variant"])).is_equal(int(db["variant"]))
		assert_float(float(da["x"])).is_equal(float(db["x"]))
		assert_float(float(da["z"])).is_equal(float(db["z"]))
		assert_float(float(da["yaw"])).is_equal(float(db["yaw"]))
		assert_float(float(da["scale"])).is_equal(float(db["scale"]))


func test_a_different_seed_gives_a_different_scatter() -> void:
	var a: Array = MHSliceNature.scatter(1, 60)
	var b: Array = MHSliceNature.scatter(2, 60)
	var differs: bool = a.size() != b.size()
	if not differs:
		for i: int in range(a.size()):
			if float((a[i] as Dictionary)["x"]) != float((b[i] as Dictionary)["x"]):
				differs = true
				break
	assert_bool(differs).is_true()


func test_items_are_valid_and_avoid_the_exclusions() -> void:
	var rects: Array = MHSliceNature.exclusion_rects()
	var items: Array = MHSliceNature.scatter(MHVerticalSlice.NATURE_SEED, MHVerticalSlice.NATURE_COUNT)
	assert_int(items.size()).is_greater(MHVerticalSlice.NATURE_COUNT / 2)
	assert_int(items.size()).is_less_equal(MHVerticalSlice.NATURE_COUNT)
	var lo: float = -MHSliceNature.RING_M
	var hi: float = MHSliceLayout.MAP_M + MHSliceNature.RING_M
	for it: Variant in items:
		var d: Dictionary = it
		assert_bool(MHNatureMeshes.KINDS.has(str(d["kind"]))).is_true()
		assert_int(int(d["variant"])).is_between(0, MHSliceNature.VARIANTS_USED - 1)
		assert_int(int(d["lod"])).is_between(0, 1)
		assert_float(float(d["scale"])).is_between(0.85, 1.25)
		assert_float(float(d["x"])).is_between(lo, hi)
		assert_float(float(d["z"])).is_between(lo, hi)
		assert_bool(MHSliceNature.is_excluded(float(d["x"]), float(d["z"]), rects)).is_false()


func test_zero_and_negative_counts_give_nothing() -> void:
	assert_int(MHSliceNature.scatter(5, 0).size()).is_equal(0)
	assert_int(MHSliceNature.scatter(5, -3).size()).is_equal(0)


func test_exclusions_cover_the_hole_corridors_and_building_parcels() -> void:
	var rects: Array = MHSliceNature.exclusion_rects()
	for slot: int in range(MHSliceLayout.hole_slot_count()):
		var mid: Vector2 = MHSliceLayout.hole_point_m(slot, 0, 30)
		assert_bool(MHSliceNature.is_excluded(mid.x, mid.y, rects)).is_true()
	var facility: Vector2 = MHSliceLayout.parcel_centre_m(8)
	assert_bool(MHSliceNature.is_excluded(facility.x, facility.y, rects)).is_true()
	var annex: Vector2 = MHSliceLayout.slot_centre_m(MHSliceLayout.ANNEX_BASE)
	assert_bool(MHSliceNature.is_excluded(annex.x, annex.y, rects)).is_true()
	assert_bool(MHSliceNature.is_excluded(-20.0, -20.0, rects)).is_false()


func test_grouping_keeps_every_item_and_limits_draw_calls() -> void:
	var items: Array = MHSliceNature.scatter(MHVerticalSlice.NATURE_SEED, MHVerticalSlice.NATURE_COUNT)
	var groups: Dictionary = MHSliceNature.group(items)
	var total: int = 0
	for key: Variant in groups.keys():
		total += (groups[key] as Array).size()
		var parts: PackedStringArray = str(key).split("|")
		assert_int(parts.size()).is_equal(3)
	assert_int(total).is_equal(items.size())
	# 9 kinds x 2 LODs x 2 variants is the hard ceiling; real scatters use fewer.
	assert_int(groups.size()).is_less_equal(36)
	var keys: Array = groups.keys()
	var sorted: Array = keys.duplicate()
	sorted.sort()
	assert_array(keys).contains_exactly(sorted)


func test_every_group_key_builds_a_mesh_inside_its_budget() -> void:
	var groups: Dictionary = MHSliceNature.group(MHSliceNature.scatter(99, 90))
	for key: Variant in groups.keys():
		var parts: PackedStringArray = str(key).split("|")
		var tris: int = MHNatureMeshes.build_builder(parts[0], int(parts[1]), int(parts[2])).tri_count()
		assert_int(tris).is_between(1, MHNatureMeshes.budget(parts[0], int(parts[1])))

extends GdUnitTestSuite
## The content catalogue (DEC-079..083): counts Nathan asked for, unique ids, walking vs cart paths.
## NOT YET RUN in Godot.

const PATH: String = "res://data/content_catalogue.json"


func _load() -> Dictionary:
	var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	assert_bool(parsed is Dictionary).is_true()
	return parsed as Dictionary


func _ids(rows: Array) -> Array:
	var out: Array = []
	for r: Variant in rows:
		out.append(str((r as Dictionary)["id"]))
	return out


func _assert_unique(ids: Array) -> void:
	var seen: Dictionary = {}
	for i: Variant in ids:
		assert_bool(seen.has(i)).override_failure_message("duplicate id %s" % str(i)).is_false()
		seen[i] = true


func test_fifteen_tree_styles_in_three_heights() -> void:
	var d: Dictionary = _load()
	assert_int((d["trees"] as Array).size()).is_equal(15)
	assert_int((d["tree_heights"] as Array).size()).is_equal(3)
	_assert_unique(_ids(d["trees"] as Array))


func test_ten_plant_styles_in_fifteen_colours() -> void:
	var d: Dictionary = _load()
	assert_int((d["plants"] as Array).size()).is_equal(10)
	assert_int((d["plant_colours"] as Array).size()).is_equal(15)
	_assert_unique(_ids(d["plants"] as Array))
	_assert_unique(d["plant_colours"] as Array)


func test_several_turf_types_with_sane_speed() -> void:
	var d: Dictionary = _load()
	var turf: Array = d["turf"] as Array
	assert_int(turf.size()).is_greater_equal(8)
	_assert_unique(_ids(turf))
	for t: Variant in turf:
		assert_int(int((t as Dictionary)["speed_permille"])).is_between(500, 1500)


func test_walking_paths_are_cheaper_than_cart_paths_and_exclude_carts() -> void:
	var d: Dictionary = _load()
	var paths: Array = d["paths"] as Array
	_assert_unique(_ids(paths))
	var cart_count: int = 0
	var cheapest_cart: int = 1000000
	var dearest_walk: int = 0
	for p: Variant in paths:
		var row: Dictionary = p as Dictionary
		if bool(row["carts"]):
			cart_count += 1
			cheapest_cart = mini(cheapest_cart, int(row["cost_per_m_cents"]))
		else:
			dearest_walk = maxi(dearest_walk, int(row["cost_per_m_cents"]))
	assert_int(cart_count).is_equal(3)
	assert_int(dearest_walk).is_less(cheapest_cart)

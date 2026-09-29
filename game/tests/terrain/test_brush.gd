extends GdUnitTestSuite
## Brush math, determinism hash and golden vectors from tools/reference/terrain/brush_ref.py. NOT YET RUN.

const GOLDEN_PATH: String = "res://tests/terrain/golden/brush_golden.json"


func _load_golden() -> Dictionary:
	var f: FileAccess = FileAccess.open(GOLDEN_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed as Dictionary


func test_falloff_table_shape() -> void:
	var t: PackedInt32Array = MHBrush.falloff_table()
	assert_int(t.size()).is_equal(1025)
	assert_int(t[0]).is_equal(0)
	assert_int(t[512]).is_equal(512)
	assert_int(t[1024]).is_equal(1024)
	for i in range(1024):
		assert_bool(t[i] <= t[i + 1]).is_true()


func test_raise_centre_is_exact_strength() -> void:
	var g := MHHeightGrid.new(32, 32)
	MHBrush.apply_dab(g, MHBrush.Mode.RAISE, 16, 16, 5, 300, 0, null)
	assert_int(g.get_h(16, 16)).is_equal(300)
	assert_int(g.get_h(16 + 5, 16)).is_equal(0)


func test_raise_lower_cancel() -> void:
	var g := MHHeightGrid.new(32, 32)
	MHBrush.apply_dab(g, MHBrush.Mode.RAISE, 16, 16, 6, 250, 0, null)
	MHBrush.apply_dab(g, MHBrush.Mode.LOWER, 16, 16, 6, 250, 0, null)
	assert_int(g.hash_fnv1a()).is_equal(MHHeightGrid.new(32, 32).hash_fnv1a())


func test_clamps_to_int16() -> void:
	var g := MHHeightGrid.new(16, 16)
	MHBrush.apply_dab(g, MHBrush.Mode.RAISE, 8, 8, 3, 60000, 0, null)
	assert_int(g.get_h(8, 8)).is_equal(32767)


func test_flatten_pulls_centre_to_level() -> void:
	var g := MHHeightGrid.new(16, 16)
	g.fill_lcg_noise(1, 800)
	MHBrush.apply_dab(g, MHBrush.Mode.FLATTEN, 8, 8, 4, 1000, 250, null)
	assert_int(g.get_h(8, 8)).is_equal(250)


func test_edge_clipping_does_not_crash() -> void:
	var g := MHHeightGrid.new(16, 16)
	var r: Rect2i = MHBrush.apply_dab(g, MHBrush.Mode.RAISE, -2, 0, 6, 100, 0, null)
	assert_bool(r.has_area()).is_true()
	var r2: Rect2i = MHBrush.apply_dab(g, MHBrush.Mode.RAISE, 100, 100, 6, 100, 0, null)
	assert_bool(r2.has_area()).is_false()


func test_determinism_hash_repeatable() -> void:
	var a := MHHeightGrid.new(64, 64)
	var b := MHHeightGrid.new(64, 64)
	a.fill_lcg_noise(99, 700)
	b.fill_lcg_noise(99, 700)
	for i in range(20):
		var m: int = i % 4
		MHBrush.apply_dab(a, m, (i * 7) % 65, (i * 13) % 65, 3 + i % 9, 200, 100, null)
		MHBrush.apply_dab(b, m, (i * 7) % 65, (i * 13) % 65, 3 + i % 9, 200, 100, null)
	assert_int(a.hash_fnv1a()).is_equal(b.hash_fnv1a())
	assert_bool(a.equals(b)).is_true()


func test_golden_falloff() -> void:
	var g: Dictionary = _load_golden()
	assert_int(MHBrush.falloff_hash()).is_equal(int(g["falloff_fnv"]))
	var t: PackedInt32Array = MHBrush.falloff_table()
	var samples: Dictionary = g["falloff_samples"]
	for k in samples.keys():
		assert_int(t[int(k)]).is_equal(int(samples[k]))


func test_golden_vectors_match_python_reference() -> void:
	var gold: Dictionary = _load_golden()
	var grid := MHHeightGrid.new(int(gold["cells"]), int(gold["cells"]))
	grid.fill_lcg_noise(int(gold["seed"]), int(gold["amplitude"]))
	assert_int(grid.hash_fnv1a()).is_equal(int(gold["initial_hash"]))
	var ops: Array = gold["ops"]
	for k in range(ops.size()):
		var op: Dictionary = ops[k]
		MHBrush.apply_dab(grid, int(op["mode"]), int(op["cx"]), int(op["cy"]), int(op["radius"]),
				int(op["strength"]), int(op["level"]), null)
		assert_int(grid.hash_fnv1a()).override_failure_message("golden op %d mismatch" % k).is_equal(int(op["hash_after"]))
	assert_int(grid.hash_fnv1a()).is_equal(int(gold["final_hash"]))
	for p in gold["probe"]:
		assert_int(grid.get_h(int(p[0]), int(p[1]))).is_equal(int(p[2]))

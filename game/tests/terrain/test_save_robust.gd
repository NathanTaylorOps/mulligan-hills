extends GdUnitTestSuite
## Crash-safe save: verify-before-rename, .bak rotation, fallback load from .tmp/.bak when the main file is
## missing, truncated or corrupt. Bad files are written with FileAccess to user://. NOT YET RUN.

const PATH: String = "user://mh_test_robust.mhts"


func before_test() -> void:
	MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.NONE
	MHTerrainSave.fault_action = MHTerrainSave.FaultAction.RETURN_ERROR
	_clean()


func after_test() -> void:
	MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.NONE
	_clean()


func _clean() -> void:
	for p in [PATH, PATH + ".tmp", PATH + ".bak"]:
		_remove(p)


func _remove(p: String) -> void:
	var d: DirAccess = DirAccess.open("user://")
	if d != null and FileAccess.file_exists(p):
		d.remove(p.get_file())


func _grid(seed_value: int) -> MHHeightGrid:
	var g := MHHeightGrid.new(40, 24, 1000)
	g.fill_lcg_noise(seed_value, 2500)
	return g


func _splat(g: MHHeightGrid, layer: int) -> MHSplatMap:
	var s := MHSplatMap.new(g.samples_x, g.samples_y)
	s.paint_disc(15, 10, 6, layer, 1000)
	return s


func _save(seed_value: int) -> MHHeightGrid:
	var g: MHHeightGrid = _grid(seed_value)
	assert_int(MHTerrainSave.save_to_file(PATH, g, _splat(g, seed_value % 11))).is_equal(OK)
	return g


func _write_bytes(p: String, data: PackedByteArray) -> void:
	var f: FileAccess = FileAccess.open(p, FileAccess.WRITE)
	assert_object(f).is_not_null()
	f.store_buffer(data)
	f.close()


func _read_bytes(p: String) -> PackedByteArray:
	var f: FileAccess = FileAccess.open(p, FileAccess.READ)
	assert_object(f).is_not_null()
	var d: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return d


func _garbage(n: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(n)
	var state: int = 12345
	for i in range(n):
		state = (state * 1103515245 + 12345) & 0x7FFFFFFF
		b[i] = (state >> 8) & 255
	return b


func test_first_save_creates_no_bak_and_no_tmp() -> void:
	_save(1)
	assert_bool(FileAccess.file_exists(PATH)).is_true()
	assert_bool(FileAccess.file_exists(PATH + ".bak")).is_false()
	assert_bool(FileAccess.file_exists(PATH + ".tmp")).is_false()


func test_second_save_keeps_previous_good_file_as_bak() -> void:
	var a: MHHeightGrid = _save(1)
	var b: MHHeightGrid = _save(2)
	assert_bool(FileAccess.file_exists(PATH + ".tmp")).is_false()
	assert_bool(MHTerrainSave.load_from_file(PATH).grid.equals(b)).is_true()
	assert_bool(MHTerrainSave.load_from_file(PATH + ".bak").grid.equals(a)).is_true()
	var c: MHHeightGrid = _save(3)
	assert_bool(MHTerrainSave.load_from_file(PATH).grid.equals(c)).is_true()
	assert_bool(MHTerrainSave.load_from_file(PATH + ".bak").grid.equals(b)).is_true()


func test_fallback_main_ok_uses_main_even_if_bak_is_garbage() -> void:
	_save(1)
	var b: MHHeightGrid = _save(2)
	_write_bytes(PATH + ".bak", _garbage(300))
	var r: MHTerrainSave.LoadResult = MHTerrainSave.load_with_fallback(PATH)
	assert_int(r.error).is_equal(OK)
	assert_str(r.source).is_equal("main")
	assert_bool(r.recovered).is_false()
	assert_bool(r.grid.equals(b)).is_true()


@warning_ignore("integer_division")
func test_fallback_truncated_main_uses_bak() -> void:
	var a: MHHeightGrid = _save(1)
	_save(2)
	var data: PackedByteArray = _read_bytes(PATH)
	_write_bytes(PATH, data.slice(0, data.size() / 2))
	assert_bool(MHTerrainSave.load_from_file(PATH).error != OK).is_true()
	var r: MHTerrainSave.LoadResult = MHTerrainSave.load_with_fallback(PATH)
	assert_int(r.error).is_equal(OK)
	assert_str(r.source).is_equal("bak")
	assert_bool(r.recovered).is_true()
	assert_bool(r.grid.equals(a)).is_true()


func test_fallback_every_truncation_length_uses_bak() -> void:
	var a: MHHeightGrid = _save(1)
	_save(2)
	var data: PackedByteArray = _read_bytes(PATH)
	for cut in [0, 1, 4, 19, 20, 21, 100, data.size() - 1]:
		_write_bytes(PATH, data.slice(0, cut))
		var r: MHTerrainSave.LoadResult = MHTerrainSave.load_with_fallback(PATH)
		assert_int(r.error).is_equal(OK)
		assert_str(r.source).is_equal("bak")
		assert_bool(r.grid.equals(a)).is_true()


func test_fallback_garbage_main_uses_bak() -> void:
	var a: MHHeightGrid = _save(1)
	_save(2)
	_write_bytes(PATH, _garbage(500))
	var r: MHTerrainSave.LoadResult = MHTerrainSave.load_with_fallback(PATH)
	assert_int(r.error).is_equal(OK)
	assert_str(r.source).is_equal("bak")
	assert_bool(r.grid.equals(a)).is_true()


@warning_ignore("integer_division")
func test_fallback_bit_flipped_main_uses_bak() -> void:
	var a: MHHeightGrid = _save(1)
	_save(2)
	var data: PackedByteArray = _read_bytes(PATH)
	data[data.size() / 2] = data[data.size() / 2] ^ 0xFF
	_write_bytes(PATH, data)
	var r: MHTerrainSave.LoadResult = MHTerrainSave.load_with_fallback(PATH)
	assert_str(r.source).is_equal("bak")
	assert_bool(r.grid.equals(a)).is_true()


func test_fallback_missing_main_uses_bak() -> void:
	var a: MHHeightGrid = _save(1)
	_save(2)
	_remove(PATH)
	var r: MHTerrainSave.LoadResult = MHTerrainSave.load_with_fallback(PATH)
	assert_int(r.error).is_equal(OK)
	assert_str(r.source).is_equal("bak")
	assert_bool(r.grid.equals(a)).is_true()


func test_fallback_corrupt_main_and_corrupt_bak_fails() -> void:
	_save(1)
	_save(2)
	_write_bytes(PATH, _garbage(200))
	_write_bytes(PATH + ".bak", _garbage(200))
	var r: MHTerrainSave.LoadResult = MHTerrainSave.load_with_fallback(PATH)
	assert_bool(r.error != OK).is_true()
	assert_str(r.source).is_equal("")
	assert_bool(r.grid == null).is_true()


func test_fallback_corrupt_main_without_bak_fails() -> void:
	_save(1)
	_write_bytes(PATH, _garbage(200))
	assert_bool(MHTerrainSave.load_with_fallback(PATH).error != OK).is_true()


func test_fallback_nothing_on_disk_is_not_found() -> void:
	assert_int(MHTerrainSave.load_with_fallback(PATH).error).is_equal(ERR_FILE_NOT_FOUND)


func test_fallback_missing_main_prefers_valid_tmp_over_bak() -> void:
	_save(1)
	_save(2)
	_remove(PATH)
	var c: MHHeightGrid = _grid(3)
	_write_bytes(PATH + ".tmp", MHTerrainSave.encode(c, _splat(c, 3)))
	var r: MHTerrainSave.LoadResult = MHTerrainSave.load_with_fallback(PATH)
	assert_int(r.error).is_equal(OK)
	assert_str(r.source).is_equal("tmp")
	assert_bool(r.grid.equals(c)).is_true()


@warning_ignore("integer_division")
func test_fallback_truncated_tmp_is_skipped_in_favour_of_bak() -> void:
	var a: MHHeightGrid = _save(1)
	_save(2)
	_remove(PATH)
	var g: MHHeightGrid = _grid(3)
	var data: PackedByteArray = MHTerrainSave.encode(g, _splat(g, 3))
	_write_bytes(PATH + ".tmp", data.slice(0, data.size() / 3))
	var r: MHTerrainSave.LoadResult = MHTerrainSave.load_with_fallback(PATH)
	assert_str(r.source).is_equal("bak")
	assert_bool(r.grid.equals(a)).is_true()


func test_corrupt_main_is_not_promoted_to_bak_on_next_save() -> void:
	var a: MHHeightGrid = _save(1)
	_save(2)
	_write_bytes(PATH, _garbage(400))
	var c: MHHeightGrid = _save(3)
	assert_bool(MHTerrainSave.load_from_file(PATH).grid.equals(c)).is_true()
	assert_bool(MHTerrainSave.load_from_file(PATH + ".bak").grid.equals(a)).is_true()
	assert_bool(FileAccess.file_exists(PATH + ".tmp")).is_false()


func test_write_atomic_rejects_data_that_fails_verification_and_keeps_main() -> void:
	var a: MHHeightGrid = _save(1)
	var err: int = MHTerrainSave.write_atomic(PATH, _garbage(256))
	assert_int(err).is_equal(ERR_FILE_CORRUPT)
	assert_bool(FileAccess.file_exists(PATH + ".tmp")).is_false()
	assert_bool(FileAccess.file_exists(PATH + ".bak")).is_false()
	assert_bool(MHTerrainSave.load_from_file(PATH).grid.equals(a)).is_true()


func test_fault_after_bak_rotate_recovers_new_data_from_tmp() -> void:
	_save(1)
	var b: MHHeightGrid = _save(2)
	MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.AFTER_BAK_ROTATE
	var c: MHHeightGrid = _grid(3)
	assert_bool(MHTerrainSave.save_to_file(PATH, c, _splat(c, 3)) != OK).is_true()
	MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.NONE
	assert_bool(FileAccess.file_exists(PATH)).is_false()
	var r: MHTerrainSave.LoadResult = MHTerrainSave.load_with_fallback(PATH)
	assert_int(r.error).is_equal(OK)
	assert_str(r.source).is_equal("tmp")
	assert_bool(r.grid.equals(c)).is_true()
	assert_bool(MHTerrainSave.load_from_file(PATH + ".bak").grid.equals(b)).is_true()
	# a normal save afterwards works and leaves a consistent set
	var d: MHHeightGrid = _save(4)
	assert_bool(MHTerrainSave.load_with_fallback(PATH).grid.equals(d)).is_true()
	assert_str(MHTerrainSave.load_with_fallback(PATH).source).is_equal("main")


func test_fault_after_temp_write_still_loads_previous_via_fallback() -> void:
	var a: MHHeightGrid = _save(1)
	MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.AFTER_TEMP_WRITE
	var b: MHHeightGrid = _grid(2)
	assert_bool(MHTerrainSave.save_to_file(PATH, b, _splat(b, 2)) != OK).is_true()
	MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.NONE
	var r: MHTerrainSave.LoadResult = MHTerrainSave.load_with_fallback(PATH)
	assert_str(r.source).is_equal("main")
	assert_bool(r.grid.equals(a)).is_true()


func test_fault_mid_temp_write_with_missing_main_falls_back_to_bak() -> void:
	var a: MHHeightGrid = _save(1)
	_save(2)
	_remove(PATH)
	MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.MID_TEMP_WRITE
	var c: MHHeightGrid = _grid(3)
	assert_bool(MHTerrainSave.save_to_file(PATH, c, _splat(c, 3)) != OK).is_true()
	MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.NONE
	var r: MHTerrainSave.LoadResult = MHTerrainSave.load_with_fallback(PATH)
	assert_str(r.source).is_equal("bak")
	assert_bool(r.grid.equals(a)).is_true()


func test_600x400_kill_simulation_falls_back_to_previous_save() -> void:
	var g1 := MHHeightGrid.new(600, 400, 1000)
	g1.fill_lcg_noise(21, 3000)
	var s1 := MHSplatMap.new(601, 401)
	assert_int(MHTerrainSave.save_to_file(PATH, g1, s1)).is_equal(OK)
	var g2: MHHeightGrid = g1.duplicate_grid()
	g2.set_h(600, 400, 1234)
	assert_int(MHTerrainSave.save_to_file(PATH, g2, s1)).is_equal(OK)
	var data: PackedByteArray = _read_bytes(PATH)
	_write_bytes(PATH, data.slice(0, data.size() - 7))  # simulate a torn write of the main file
	var r: MHTerrainSave.LoadResult = MHTerrainSave.load_with_fallback(PATH)
	assert_int(r.error).is_equal(OK)
	assert_str(r.source).is_equal("bak")
	assert_bool(r.grid.equals(g1)).is_true()
	assert_int(r.grid.cells_x).is_equal(600)
	assert_int(r.grid.cells_y).is_equal(400)

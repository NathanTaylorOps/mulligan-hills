extends GdUnitTestSuite
## Save/load round trip, corruption detection, atomic write and fault injection. NOT YET RUN.

const PATH: String = "user://mh_test_terrain.mhts"


func before_test() -> void:
	MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.NONE
	MHTerrainSave.fault_action = MHTerrainSave.FaultAction.RETURN_ERROR
	_remove(PATH)
	_remove(PATH + ".tmp")


func after_test() -> void:
	MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.NONE
	_remove(PATH)
	_remove(PATH + ".tmp")


func _remove(p: String) -> void:
	var d: DirAccess = DirAccess.open("user://")
	if d != null and FileAccess.file_exists(p):
		d.remove(p.get_file())


func _sample(seed_value: int = 3) -> Array:
	var g := MHHeightGrid.new(48, 40, 1000)
	g.fill_lcg_noise(seed_value, 3000)
	var s := MHSplatMap.new(g.samples_x, g.samples_y)
	s.paint_disc(20, 20, 8, MHSplatMap.Layer.SAND, 800)
	return [g, s]


func test_crc32_known_vector() -> void:
	assert_int(MHTerrainSave.crc32("123456789".to_ascii_buffer())).is_equal(0xCBF43926)


func test_round_trip_in_memory() -> void:
	var gs: Array = _sample()
	var data: PackedByteArray = MHTerrainSave.encode(gs[0], gs[1])
	var r: MHTerrainSave.LoadResult = MHTerrainSave.decode(data)
	assert_int(r.error).is_equal(OK)
	assert_bool(r.grid.equals(gs[0])).is_true()
	assert_bool(r.splat.bytes == gs[1].bytes).is_true()
	assert_int(r.grid.hash_fnv1a()).is_equal(gs[0].hash_fnv1a())


func test_encode_is_deterministic() -> void:
	var gs: Array = _sample()
	assert_bool(MHTerrainSave.encode(gs[0], gs[1]) == MHTerrainSave.encode(gs[0], gs[1])).is_true()


func test_round_trip_via_file() -> void:
	var gs: Array = _sample()
	assert_int(MHTerrainSave.save_to_file(PATH, gs[0], gs[1])).is_equal(OK)
	assert_bool(FileAccess.file_exists(PATH + ".tmp")).is_false()
	var r: MHTerrainSave.LoadResult = MHTerrainSave.load_from_file(PATH)
	assert_int(r.error).is_equal(OK)
	assert_bool(r.grid.equals(gs[0])).is_true()


func test_extreme_heights_round_trip() -> void:
	var g := MHHeightGrid.new(4, 4)
	g.set_h(0, 0, -32768)
	g.set_h(4, 4, 32767)
	var s := MHSplatMap.new(5, 5)
	var r: MHTerrainSave.LoadResult = MHTerrainSave.decode(MHTerrainSave.encode(g, s))
	assert_int(r.error).is_equal(OK)
	assert_int(r.grid.get_h(0, 0)).is_equal(-32768)
	assert_int(r.grid.get_h(4, 4)).is_equal(32767)


func test_every_single_byte_flip_in_small_file_is_detected() -> void:
	var g := MHHeightGrid.new(4, 4)
	g.fill_lcg_noise(8, 100)
	var data: PackedByteArray = MHTerrainSave.encode(g, MHSplatMap.new(5, 5))
	for i in range(data.size()):
		var bad: PackedByteArray = data.duplicate()
		bad[i] = bad[i] ^ 0x5A
		var r: MHTerrainSave.LoadResult = MHTerrainSave.decode(bad)
		assert_bool(r.error != OK).override_failure_message("flip at byte %d not detected" % i).is_true()


func test_truncation_and_garbage_detected() -> void:
	var gs: Array = _sample()
	var data: PackedByteArray = MHTerrainSave.encode(gs[0], gs[1])
	assert_bool(MHTerrainSave.decode(data.slice(0, data.size() - 1)).error != OK).is_true()
	assert_bool(MHTerrainSave.decode(data.slice(0, 10)).error != OK).is_true()
	assert_bool(MHTerrainSave.decode(PackedByteArray()).error != OK).is_true()
	var extended: PackedByteArray = data.duplicate()
	extended.append(0)
	assert_bool(MHTerrainSave.decode(extended).error != OK).is_true()


func test_bad_magic_and_future_version() -> void:
	var gs: Array = _sample()
	var data: PackedByteArray = MHTerrainSave.encode(gs[0], gs[1])
	var m: PackedByteArray = data.duplicate()
	m[0] = 0
	assert_int(MHTerrainSave.decode(m).error).is_equal(ERR_FILE_UNRECOGNIZED)
	var v: PackedByteArray = data.duplicate()
	v.encode_u16(4, 2)
	assert_bool(MHTerrainSave.decode(v).error != OK).is_true()


func test_corrupt_file_on_disk_detected() -> void:
	var gs: Array = _sample()
	MHTerrainSave.save_to_file(PATH, gs[0], gs[1])
	var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	var data: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	data[data.size() / 2] = data[data.size() / 2] ^ 0xFF
	var w: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	w.store_buffer(data)
	w.close()
	assert_bool(MHTerrainSave.load_from_file(PATH).error != OK).is_true()


func test_fault_after_temp_write_keeps_old_file() -> void:
	var a: Array = _sample(1)
	var b: Array = _sample(2)
	assert_int(MHTerrainSave.save_to_file(PATH, a[0], a[1])).is_equal(OK)
	MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.AFTER_TEMP_WRITE
	assert_bool(MHTerrainSave.save_to_file(PATH, b[0], b[1]) != OK).is_true()
	MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.NONE
	assert_bool(FileAccess.file_exists(PATH + ".tmp")).is_true()
	var r: MHTerrainSave.LoadResult = MHTerrainSave.load_from_file(PATH)
	assert_int(r.error).is_equal(OK)
	assert_bool(r.grid.equals(a[0])).is_true()
	MHTerrainSave.cleanup_stale_temp(PATH)
	assert_bool(FileAccess.file_exists(PATH + ".tmp")).is_false()
	assert_bool(MHTerrainSave.load_from_file(PATH).grid.equals(a[0])).is_true()


func test_fault_mid_temp_write_keeps_old_file_and_temp_is_invalid() -> void:
	var a: Array = _sample(1)
	var b: Array = _sample(2)
	MHTerrainSave.save_to_file(PATH, a[0], a[1])
	MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.MID_TEMP_WRITE
	assert_bool(MHTerrainSave.save_to_file(PATH, b[0], b[1]) != OK).is_true()
	MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.NONE
	assert_bool(MHTerrainSave.load_from_file(PATH).grid.equals(a[0])).is_true()
	assert_bool(MHTerrainSave.load_from_file(PATH + ".tmp").error != OK).is_true()


func test_fault_on_first_ever_save_leaves_no_valid_file() -> void:
	var a: Array = _sample(1)
	MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.AFTER_TEMP_WRITE
	MHTerrainSave.save_to_file(PATH, a[0], a[1])
	MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.NONE
	assert_int(MHTerrainSave.load_from_file(PATH).error).is_equal(ERR_FILE_NOT_FOUND)


func test_save_after_stale_temp_succeeds() -> void:
	var a: Array = _sample(1)
	MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.MID_TEMP_WRITE
	MHTerrainSave.save_to_file(PATH, a[0], a[1])
	MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.NONE
	assert_int(MHTerrainSave.save_to_file(PATH, a[0], a[1])).is_equal(OK)
	assert_bool(MHTerrainSave.load_from_file(PATH).grid.equals(a[0])).is_true()

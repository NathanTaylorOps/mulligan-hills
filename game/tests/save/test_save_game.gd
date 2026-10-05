extends GdUnitTestSuite
## MHSaveGame: integer normalisation, canonical JSON, checksum, parse order, validation. NOT YET RUN in Godot.
## Golden checksum comes from a Python mirror (json.dumps sort_keys, compact separators, sha256).

const Fixture = preload("res://tests/save/save_fixture.gd")


func test_normalize_converts_integral_floats() -> void:
	var r: MHSaveResult = MHSaveGame.normalize({"a": 1.0, "b": [2.0, {"c": -3.0}], "s": "x", "t": true, "n": null})
	assert_bool(r.is_ok()).is_true()
	var d: Dictionary = r.value
	assert_int(typeof(d["a"])).is_equal(TYPE_INT)
	assert_int(int(d["a"])).is_equal(1)
	var arr: Array = d["b"]
	assert_int(typeof(arr[0])).is_equal(TYPE_INT)
	assert_int(typeof((arr[1] as Dictionary)["c"])).is_equal(TYPE_INT)
	assert_int(int((arr[1] as Dictionary)["c"])).is_equal(-3)


func test_normalize_rejects_bad_numbers() -> void:
	assert_bool(MHSaveGame.normalize({"a": 1.5}).is_ok()).is_false()
	assert_bool(MHSaveGame.normalize({"a": INF}).is_ok()).is_false()
	assert_bool(MHSaveGame.normalize({"a": NAN}).is_ok()).is_false()
	assert_bool(MHSaveGame.normalize([0.25]).is_ok()).is_false()


func test_normalize_two_pow_53_edge() -> void:
	var ok: MHSaveResult = MHSaveGame.normalize({"a": float(9007199254740991)})
	assert_bool(ok.is_ok()).is_true()
	assert_int(int((ok.value as Dictionary)["a"])).is_equal(9007199254740991)
	assert_bool(MHSaveGame.normalize({"a": float(9007199254740992)}).is_ok()).is_false()
	assert_bool(MHSaveGame.normalize({"a": 9007199254740991}).is_ok()).is_true()
	assert_bool(MHSaveGame.normalize({"a": 9007199254740992}).is_ok()).is_false()
	assert_bool(MHSaveGame.normalize({"a": -9007199254740992}).is_ok()).is_false()


func test_normalize_rejects_non_string_keys_and_deep_nesting() -> void:
	assert_bool(MHSaveGame.normalize({1: 2}).is_ok()).is_false()
	var deep: Array = []
	var cur: Array = deep
	for i in range(60):
		var nxt: Array = []
		cur.append(nxt)
		cur = nxt
	assert_bool(MHSaveGame.normalize(deep).is_ok()).is_false()


func test_u64_hex_round_trip() -> void:
	assert_str(MHSaveGame.u64_hex(0xDEADBEEF)).is_equal("00000000deadbeef")
	assert_str(MHSaveGame.u64_hex(0x7FFFFFFFFFFFFFFF)).is_equal("7fffffffffffffff")
	assert_str(MHSaveGame.u64_hex(-1)).is_equal("ffffffffffffffff")
	assert_int(MHSaveGame.hex_u64("00000000deadbeef")).is_equal(0xDEADBEEF)
	assert_int(MHSaveGame.hex_u64("ffffffffffffffff")).is_equal(-1)
	assert_int(MHSaveGame.hex_u64(MHSaveGame.u64_hex(0x123456789ABCDEF))).is_equal(0x123456789ABCDEF)
	var ok: Array = [true]
	MHSaveGame.hex_u64("not hex at all!!!", ok)
	assert_bool(bool(ok[0])).is_false()
	MHSaveGame.hex_u64("0000000000000001", ok)
	assert_bool(bool(ok[0])).is_true()


func test_canonical_json_sorts_keys_and_prints_integers() -> void:
	var d: Dictionary = {"b": [1, 2, {"z": true, "a": null}], "a": "x\"y", "c": 3.0}
	assert_str(MHSaveGame.canonical_json(d)).is_equal('{"a":"x\\"y","b":[1,2,{"a":null,"z":true}],"c":3}')


func test_checksum_matches_python_reference() -> void:
	var doc: Dictionary = Fixture.make_doc()
	assert_str(MHSaveGame.compute_checksum(doc)).is_equal(Fixture.DOC_CHECKSUM)
	# the checksum ignores an existing checksum key and key order
	doc["checksum"] = {"alg": "sha256", "value": "0".repeat(64)}
	assert_str(MHSaveGame.compute_checksum(doc)).is_equal(Fixture.DOC_CHECKSUM)


func test_seal_and_tamper_detection() -> void:
	var doc: Dictionary = Fixture.make_doc()
	assert_bool(MHSaveGame.checksum_ok(doc)).is_false()
	MHSaveGame.seal(doc)
	assert_bool(MHSaveGame.checksum_ok(doc)).is_true()
	assert_str(String((doc["checksum"] as Dictionary)["value"])).is_equal(Fixture.DOC_CHECKSUM)
	(doc["club"] as Dictionary)["cash"] = 999999
	assert_bool(MHSaveGame.checksum_ok(doc)).is_false()


func test_bytes_round_trip_is_byte_identical() -> void:
	var doc: Dictionary = Fixture.make_doc()
	MHSaveGame.seal(doc)
	var bytes: PackedByteArray = MHSaveGame.to_bytes(doc)
	var r: MHSaveResult = MHSaveGame.parse_bytes(bytes)
	assert_bool(r.is_ok()).is_true()
	assert_bool(MHSaveGame.to_bytes(r.value as Dictionary) == bytes).is_true()


func test_parse_bytes_error_codes() -> void:
	assert_int(MHSaveGame.parse_bytes(PackedByteArray()).code).is_equal(MHSaveResult.Code.PARSE_ERROR)
	assert_int(MHSaveGame.parse_bytes("{not json".to_utf8_buffer()).code).is_equal(MHSaveResult.Code.PARSE_ERROR)
	assert_int(MHSaveGame.parse_bytes("[1,2]".to_utf8_buffer()).code).is_equal(MHSaveResult.Code.BAD_SCHEMA)
	var wrong: Dictionary = Fixture.make_doc()
	wrong["schema"] = "other"
	MHSaveGame.seal(wrong)
	assert_int(MHSaveGame.parse_bytes(MHSaveGame.to_bytes(wrong)).code).is_equal(MHSaveResult.Code.BAD_SCHEMA)
	var future: Dictionary = Fixture.make_doc()
	future["min_reader_version"] = MHSaveGame.READER_VERSION + 1
	MHSaveGame.seal(future)
	assert_int(MHSaveGame.parse_bytes(MHSaveGame.to_bytes(future)).code).is_equal(MHSaveResult.Code.NEEDS_APP_UPDATE)
	var bad: Dictionary = Fixture.make_doc()
	MHSaveGame.seal(bad)
	(bad["club"] as Dictionary)["cash"] = 1
	assert_int(MHSaveGame.parse_bytes(MHSaveGame.to_bytes(bad)).code).is_equal(MHSaveResult.Code.CHECKSUM_MISMATCH)
	var fractional: String = MHSaveGame.canonical_json(Fixture.make_doc()).replace('"cash":18250', '"cash":18250.5')
	assert_int(MHSaveGame.parse_bytes(fractional.to_utf8_buffer()).code).is_equal(MHSaveResult.Code.BAD_SCHEMA)


func test_validate_accepts_the_fixture() -> void:
	var doc: Dictionary = Fixture.make_doc()
	MHSaveGame.seal(doc)
	assert_int(MHSaveGame.validate(doc).size()).is_equal(0)


func test_validate_rejects_entitlement_keys() -> void:
	for key in ["unlocked", "entitlement", "receipt", "token", "premium"]:
		var doc: Dictionary = Fixture.make_doc()
		MHSaveGame.seal(doc)
		doc[key] = true
		assert_bool(MHSaveGame.validate(doc).is_empty()).is_false()


func test_validate_rejects_ironman() -> void:
	var a: Dictionary = Fixture.make_doc()
	a["ironman"] = true
	MHSaveGame.seal(a)
	assert_bool(MHSaveGame.validate(a).is_empty()).is_false()
	var b: Dictionary = Fixture.make_doc()
	b["slot_kind"] = "ironman"
	MHSaveGame.seal(b)
	assert_bool(MHSaveGame.validate(b).is_empty()).is_false()


func test_validate_rejects_bad_fields() -> void:
	var d: Dictionary = Fixture.make_doc()
	MHSaveGame.seal(d)
	d["slot"] = 5
	assert_bool(MHSaveGame.validate(d).is_empty()).is_false()
	d = Fixture.make_doc()
	MHSaveGame.seal(d)
	(d["sim"] as Dictionary)["rng_seed"] = "XYZ"
	assert_bool(MHSaveGame.validate(d).is_empty()).is_false()
	d = Fixture.make_doc()
	MHSaveGame.seal(d)
	((d["course"] as Dictionary)["terrain"] as Dictionary)["file"] = "../evil.mhts"
	assert_bool(MHSaveGame.validate(d).is_empty()).is_false()
	d = Fixture.make_doc()
	MHSaveGame.seal(d)
	d.erase("progress")
	assert_bool(MHSaveGame.validate(d).is_empty()).is_false()


func test_safe_blob_name() -> void:
	assert_bool(MHSaveGame.is_safe_blob_name("slot_1.mhts")).is_true()
	assert_bool(MHSaveGame.is_safe_blob_name("../slot_1.mhts")).is_false()
	assert_bool(MHSaveGame.is_safe_blob_name("a/b.mhts")).is_false()
	assert_bool(MHSaveGame.is_safe_blob_name("slot_1.json")).is_false()
	assert_bool(MHSaveGame.is_safe_blob_name(5)).is_false()

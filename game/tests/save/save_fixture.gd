extends RefCounted
## Shared helpers for the save tests (not a test suite: the file name has no test_ prefix).
## Load with: const Fixture = preload("res://tests/save/save_fixture.gd")

const DOC_JSON: String = '{"schema":"mh.save","save_version":1,"min_reader_version":1,"written_by":{"app_version":"0.1.0","sim_version":"MHSIM-1.0.0","rating_version":"MHRATE-1.0.0","platform":"test"},"slot":1,"slot_kind":"manual","revision":0,"saved_at_unix":1790000000,"install_id":"9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d","mode":"standard","ironman":false,"world":{"day":17,"season":"spring"},"club":{"name_preset_id":4,"cash":18250,"lifetime_earned":64200,"green_fee":35,"members":12,"reputation":140,"prestige":0,"staff":{"greenkeepers":2,"marshals":1,"pro_shop_staff":0,"caterers":0}},"buildings":[{"id":"clubhouse","tier":1,"built_day":0},{"id":"maintenance","tier":0}],"land":{"owned_parcel_ids":[0,1]},"course":{"holes":[{"hole_no":1},{"hole_no":2},{"hole_no":3}],"terrain":{"file":"slot_1.mhts","content_hash":"00000000"}},"sim":{"rating_epoch":1,"rng_seed":"00000000deadbeef","rng_inc":"0000000000000055","golfer_serial":511},"ratings":{"rating_version":"MHRATE-1.0.0","computed_day":16,"holes":[],"course_score":47},"progress":{"tutorial_step":14,"achievements":["first_hole"],"tournaments":{"hosted_levels":[],"cooldown_until_day":0},"playtime_s":5400}}'

## Python reference value: sha256 of the canonical JSON of DOC_JSON (no checksum key), computed with
## json.dumps(sort_keys=True, separators=(",", ":")) in the scratch mirror.
const DOC_CHECKSUM: String = "c7d8a83c5dbc38051d0924924b885c01bc7b8e1505f5dbbed7f15d14c756faa0"


## Fresh, normalized, UNSEALED document (the store seals it).
static func make_doc() -> Dictionary:
	var parsed: Variant = JSON.parse_string(DOC_JSON)
	var nr: MHSaveResult = MHSaveGame.normalize(parsed)
	return nr.value as Dictionary


## A small terrain blob (MHTerrainSave format). Different seeds give different height hashes.
static func make_blob(seed_value: int) -> PackedByteArray:
	var g := MHHeightGrid.new(16, 16, 1000)
	g.fill_lcg_noise(seed_value, 3000)
	var s := MHSplatMap.new(g.samples_x, g.samples_y)
	return MHTerrainSave.encode(g, s)


static func blob_hash(blob: PackedByteArray) -> String:
	var r: MHTerrainSave.LoadResult = MHTerrainSave.decode(blob)
	return MHHash.hex32(r.grid.hash_fnv1a())


## Removes every file in `dir` and the directory itself (user:// only).
static func wipe_dir(dir_path: String) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	var parent: DirAccess = DirAccess.open(dir_path.get_base_dir())
	if parent != null:
		parent.remove(dir_path.get_file())

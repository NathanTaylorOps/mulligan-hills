class_name MHRParams
extends RefCounted
## Normative tables for MHRATE-1.0.0 / MHSIM-1.0.0, loaded once from res://data/rating/params.json
## (a byte-identical copy of docs/spec/rating/params.json; tests/ and docs/ are not exported, data/ is).
## `ok` is false if the file could not be read; the engine then refuses to rate (never guesses tables).

const PATH: String = "res://data/rating/params.json"
const ENGINE_VERSION: String = "MHRATE-1.0.0"
const SIM_VERSION: String = "MHSIM-1.0.0"
## Club tree intercept fraction (permille of flight path), constant list in the spec.
static var tmax: PackedInt32Array = PackedInt32Array([600, 550, 450, 400, 350, 300, 280, 260, 240, 220, 200, 200])
## Style penalty weight per penalty-eighth: aggressive, neutral, cautious.
static var style_w: PackedInt32Array = PackedInt32Array([0, 8, 30])
## Planner distance fractions (permille of base distance).
static var fracs: PackedInt32Array = PackedInt32Array([1000, 850, 700, 550])
## Preview roster (N = 30), spec golfer-sim.md section 4.
static var preview_counts: PackedInt32Array = PackedInt32Array([3, 5, 8, 8, 4, 2])
## Hole-count gates for tiers 2..5 (index 0 = tier 2). Score gates come from params.json.
static var hole_gates: PackedInt32Array = PackedInt32Array([6, 10, 14, 18])

static var ok: bool = false
static var params_hash: String = ""
static var z256: PackedInt32Array = PackedInt32Array()
static var band_counts: PackedInt32Array = PackedInt32Array()
static var band_lo: PackedInt32Array = PackedInt32Array()
static var band_hi: PackedInt32Array = PackedInt32Array()
static var lie_carry: PackedInt32Array = PackedInt32Array()
static var lie_disp: PackedInt32Array = PackedInt32Array()
static var lie_mishit: PackedInt32Array = PackedInt32Array()
static var lie_add: PackedInt32Array = PackedInt32Array()      # tee, fairway, fringe, rough, deep, bunker, green
static var club_base: PackedInt32Array = PackedInt32Array()
static var club_loft: PackedInt32Array = PackedInt32Array()
static var es_fw: PackedInt32Array = PackedInt32Array()        # flat [x, y, ...]
static var es_green: PackedInt32Array = PackedInt32Array()
static var putt_base: PackedInt32Array = PackedInt32Array()
static var length_table: PackedInt32Array = PackedInt32Array()
static var short_game: PackedInt32Array = PackedInt32Array()
static var plan_samples: PackedInt32Array = PackedInt32Array()  # [zl0, zd0, zl1, zd1, ...]
static var acc_target: PackedInt32Array = PackedInt32Array()    # indexed by par (3..5)
static var pace_std: PackedInt32Array = PackedInt32Array()      # indexed by par (3..5)
static var par_limit_3: int = 260
static var par_limit_4: int = 470
static var w_a: int = 250
static var w_i: int = 350
static var w_l: int = 200
static var w_b: int = 200
static var score_gates: PackedInt32Array = PackedInt32Array()   # tiers 2..5 (index 0 = tier 2)


static func _flat(v: Variant) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for row in (v as Array):
		for e in (row as Array):
			out.append(int(e))
	return out


static func _ints(v: Variant) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for e in (v as Array):
		out.append(int(e))
	return out


static func ensure_loaded() -> bool:
	if ok:
		return true
	if not FileAccess.file_exists(PATH):
		push_error("rating params missing: " + PATH)
		return false
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var norm: PackedByteArray = PackedByteArray()
	for i in range(raw.size()):
		# normalise CRLF to LF (spec 13): drop a CR that is followed by LF
		if raw[i] == 13 and i + 1 < raw.size() and raw[i + 1] == 10:
			continue
		norm.append(raw[i])
	var parsed: Variant = JSON.parse_string(norm.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("rating params invalid json")
		return false
	var d: Dictionary = parsed
	params_hash = MHRMath.hash64(norm)
	z256 = _ints(d["z256"])
	band_counts = _ints(d["band_counts"])
	var rng: PackedInt32Array = _flat(d["band_skill_range"])
	band_lo = PackedInt32Array()
	band_hi = PackedInt32Array()
	for b in range(6):
		band_lo.append(rng[b * 2])
		band_hi.append(rng[b * 2 + 1])
	var lies: Dictionary = d["lies"]
	var keys: Array = ["tee", "fairway", "fringe", "rough", "deep", "bunker"]
	lie_carry = PackedInt32Array()
	lie_disp = PackedInt32Array()
	lie_mishit = PackedInt32Array()
	lie_add = PackedInt32Array()
	var la: Dictionary = d["lie_add"]
	for k in keys:
		var row: Array = lies[k]
		lie_carry.append(int(row[0]))
		lie_disp.append(int(row[1]))
		lie_mishit.append(int(row[2]))
		lie_add.append(int(la[k]))
	lie_add.append(int(la["green"]))
	club_base = PackedInt32Array()
	for c in (d["clubs"] as Array):
		club_base.append(int((c as Array)[1]))
	club_loft = _ints(d["club_loft_pm"])
	es_fw = _flat(d["es_fw"])
	es_green = _flat(d["es_green_ft"])
	putt_base = _flat(d["putt_p1_base"])
	length_table = _flat(d["length_table"])
	short_game = _flat(d["short_game_mult"])
	plan_samples = _flat(d["plan_samples"])
	var lim: Array = d["par_limits"]
	par_limit_3 = int(lim[0])
	par_limit_4 = int(lim[1])
	var at: Dictionary = d["acc_target"]
	var ps: Dictionary = d["pace_std_s"]
	acc_target = PackedInt32Array([0, 0, 0, int(at["3"]), int(at["4"]), int(at["5"])])
	pace_std = PackedInt32Array([0, 0, 0, int(ps["3"]), int(ps["4"]), int(ps["5"])])
	var hw: Dictionary = d["hole_weights"]
	w_a = int(hw["A"])
	w_i = int(hw["I"])
	w_l = int(hw["L"])
	w_b = int(hw["B"])
	var gt: Dictionary = d["gates_avg_score_x10"]
	score_gates = PackedInt32Array([int(gt["2"]), int(gt["3"]), int(gt["4"]), int(gt["5"])])
	ok = (z256.size() == 256 and band_counts.size() == 6 and club_base.size() == 12 and plan_samples.size() == 16)
	return ok

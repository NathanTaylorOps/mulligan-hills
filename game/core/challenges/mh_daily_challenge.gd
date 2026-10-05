class_name MHDailyChallenge
extends RefCounted
## Deterministic daily challenge generator and judge (res://data/daily_challenges.json, DEC-016, DEC-059).
## The challenge of a UTC day is a pure function of the day number and the data file: every device and the server
## derive the same template, difficulty and thresholds. No clock, no randi/randf, integers only. Remote kill
## switch: see MHKillSwitch (key "daily_challenge"); a disabled feature generates nothing.
##
## Generation draw order (stable, tests pin golden challenges). rng = MHRng(H32(generation_salt, day, 0x4D48), 1):
##   1. difficulty  : rng.bounded(sum of difficulty_weights), cumulative over [easy, medium, hard] = 0, 1, 2
##   2. template    : rng.bounded(sum of template weights), cumulative in FILE order
##   3. par         : rng.bounded(template.par.size()) (always consumed, also for one par)
##   4. thresholds  : in this fixed order, only those the template has: axis_min for accuracy, imagination, length,
##                    beauty, fairness; then axis_max in the same axis order; then max_length_yd, min_length_yd,
##                    min_score. Each consumes ONE rng.bounded(3).
## A threshold pair is [easy, hard]. value = easy + round_half_away((hard - easy) x difficulty / 2), plus jitter
## (bounded(3) - 1) x jitter_step, rounded to a multiple of round_step, then clamped between the two pair ends
## (so a hard challenge is never easier than the easy end) and into 0..100 (axes, score) or 50..700 (yards).
@warning_ignore_start("integer_division")

const DEFAULT_PATH: String = "res://data/daily_challenges.json"
const AXES: Array = ["accuracy", "imagination", "length", "beauty", "fairness"]
const STREAM: int = 1
const SECONDS_PER_DAY: int = 86400
const KILL_KEY: String = "daily_challenge"

var load_error: String = ""

var _d: Dictionary = {}
var _loaded: bool = false


static func day_number_from_unix(unix_seconds: int) -> int:
	return MHRMath.fdiv(unix_seconds, SECONDS_PER_DAY)


## Whole minutes until the next UTC midnight (rounded up, 1..1440).
static func minutes_until_rollover(unix_seconds: int) -> int:
	var into_day: int = posmod(unix_seconds, SECONDS_PER_DAY)
	return (SECONDS_PER_DAY - into_day + 59) / 60


## Rating engine hole result (A, I, Len, B, F in permille) to 0..100 axis values for evaluate().
static func axes_from_rating(r: Dictionary) -> Dictionary:
	return {
		"accuracy": MHRMath.rdiv(int(r.get("A", 0)), 10),
		"imagination": MHRMath.rdiv(int(r.get("I", 0)), 10),
		"length": MHRMath.rdiv(int(r.get("Len", 0)), 10),
		"beauty": MHRMath.rdiv(int(r.get("B", 0)), 10),
		"fairness": MHRMath.rdiv(int(r.get("F", 0)), 10),
	}


static func is_feature_on(kill_switches: Dictionary) -> bool:
	return MHKillSwitch.is_on(kill_switches, KILL_KEY)


func is_loaded() -> bool:
	return _loaded


func load_from_file(path: String = DEFAULT_PATH) -> bool:
	var r: Dictionary = MHDataJson.load_file(path)
	if not bool(r["ok"]):
		return _fail(str(r["error"]))
	return load_from_dict(r["value"] as Dictionary)


func load_from_text(text: String) -> bool:
	var r: Dictionary = MHDataJson.parse_text(text)
	if not bool(r["ok"]):
		return _fail(str(r["error"]))
	return load_from_dict(r["value"] as Dictionary)


func load_from_dict(d: Dictionary) -> bool:
	_loaded = false
	load_error = ""
	_d = {}
	if str(d.get("schema", "")) != "mh.daily_challenges" or int(d.get("schema_version", 0)) != 1:
		return _fail("wrong schema or schema_version")
	if not MHDataJson.is_int_in(d.get("attempts_per_day", null), 1, 10):
		return _fail("bad attempts_per_day")
	if not MHDataJson.is_int_in(d.get("history_days", null), 1, 90):
		return _fail("bad history_days")
	if not MHDataJson.is_int_in(d.get("local_board_cap", null), 1, 500):
		return _fail("bad local_board_cap")
	if not MHDataJson.is_int_array(d.get("difficulty_weights", null), 3, 0, 1000):
		return _fail("bad difficulty_weights")
	var wsum: int = 0
	for w: Variant in (d["difficulty_weights"] as Array):
		wsum += int(w)
	if wsum < 1:
		return _fail("difficulty_weights sum to zero")
	if not MHDataJson.is_int_in(d.get("jitter_step", null), 0, 25) or not MHDataJson.is_int_in(d.get("round_step", null), 1, 25):
		return _fail("bad jitter_step or round_step")
	if not MHDataJson.is_int_in(d.get("generation_salt", null), 0, 4294967295) or not MHDataJson.is_int_in(d.get("sim_seed_tag", null), 0, 4294967295):
		return _fail("bad generation_salt or sim_seed_tag")
	var tv: Variant = d.get("templates", null)
	if typeof(tv) != TYPE_ARRAY or (tv as Array).is_empty():
		return _fail("templates missing")
	var seen: Array = []
	for t: Variant in (tv as Array):
		var msg: String = _check_template(t, seen)
		if not msg.is_empty():
			return _fail(msg)
	_d = d
	_loaded = true
	return true


func _fail(msg: String) -> bool:
	load_error = msg
	_loaded = false
	return false


func _check_template(t: Variant, seen: Array) -> String:
	if typeof(t) != TYPE_DICTIONARY:
		return "template is not an object"
	var td: Dictionary = t
	var tid: String = str(td.get("id", ""))
	if tid.is_empty() or seen.has(tid):
		return "missing or duplicate template id"
	seen.append(tid)
	if not MHDataJson.is_int_in(td.get("weight", null), 1, 1000):
		return tid + ": bad weight"
	var pars: Variant = td.get("par", null)
	if not MHDataJson.is_int_array(pars, -1, 3, 5) or (pars as Array).is_empty() or (pars as Array).size() > 3:
		return tid + ": bad par"
	for blk: String in ["axis_min", "axis_max"]:
		if typeof(td.get(blk, null)) != TYPE_DICTIONARY:
			return tid + ": missing " + blk
		var bd: Dictionary = td[blk]
		for k: Variant in bd.keys():
			if not AXES.has(str(k)):
				return tid + ": unknown axis " + str(k)
			if not MHDataJson.is_int_array(bd[k], 2, 0, 100):
				return tid + ": bad " + blk + "." + str(k)
	for k2: String in ["max_length_yd", "min_length_yd"]:
		if td.has(k2) and not MHDataJson.is_int_array(td[k2], 2, 50, 700):
			return tid + ": bad " + k2
	if td.has("min_score") and not MHDataJson.is_int_array(td["min_score"], 2, 0, 100):
		return tid + ": bad min_score"
	if typeof(td.get("text_keys", null)) != TYPE_DICTIONARY:
		return tid + ": text_keys missing"
	var tk: Dictionary = td["text_keys"]
	if str(tk.get("title", "")).is_empty() or str(tk.get("desc", "")).is_empty():
		return tid + ": text_keys incomplete"
	return ""


# ------------------------------------------------------------------ data accessors

func attempts_per_day() -> int:
	return int(_d["attempts_per_day"])


func history_days() -> int:
	return int(_d["history_days"])


func local_board_cap() -> int:
	return int(_d["local_board_cap"])


func template_count() -> int:
	return (_d["templates"] as Array).size()


func template_at(index: int) -> Dictionary:
	var arr: Array = _d["templates"]
	if index < 0 or index >= arr.size():
		return {}
	return (arr[index] as Dictionary).duplicate(true)


func template_by_id(template_id: String) -> Dictionary:
	for t: Variant in (_d["templates"] as Array):
		if str((t as Dictionary)["id"]) == template_id:
			return (t as Dictionary).duplicate(true)
	return {}


## The sim seed for rating a daily submission: H32(0xDA11, day, slot_id, 0x4D48) with slot_id = sim_seed_tag
## (MHRMath.daily_seed). Every player gets the same draws.
func sim_seed(day_number: int) -> int:
	return MHRMath.daily_seed(day_number, int(_d["sim_seed_tag"]))


# ------------------------------------------------------------------ generation

## The challenge of UTC day `day_number` (>= 0). kill_switches is the remote-config kill_switches Dictionary
## (may be empty). Returns {} when the feature is switched off, so the UI shows its "paused" notice.
## Keys: day, challenge_id (= day), template_id, difficulty (0..2), par, axis_min {axis: int}, axis_max {axis: int},
## max_length_yd / min_length_yd / min_score (only when the template has them), target_score, title_key, desc_key,
## sim_seed.
func today(day_number: int, kill_switches: Dictionary) -> Dictionary:
	if not is_feature_on(kill_switches):
		return {}
	return generate(day_number)


func generate(day_number: int) -> Dictionary:
	if not _loaded or day_number < 0:
		return {}
	var rng: MHRng = MHRng.new(MHRMath.h32c(int(_d["generation_salt"]), day_number, 0x4D48), STREAM)
	var diff: int = _weighted(rng, _d["difficulty_weights"] as Array)
	var tweights: Array = []
	for t: Variant in (_d["templates"] as Array):
		tweights.append(int((t as Dictionary)["weight"]))
	var tmpl: Dictionary = (_d["templates"] as Array)[_weighted(rng, tweights)]
	var pars: Array = tmpl["par"]
	var par_pick: int = int(pars[rng.bounded(pars.size())])
	var out_min: Dictionary = {}
	var out_max: Dictionary = {}
	var out: Dictionary = {
		"day": day_number,
		"challenge_id": day_number,
		"template_id": str(tmpl["id"]),
		"difficulty": diff,
		"par": par_pick,
		"axis_min": out_min,
		"axis_max": out_max,
	}
	var jitter: int = int(_d["jitter_step"])
	var step: int = int(_d["round_step"])
	var amin: Dictionary = tmpl["axis_min"]
	var amax: Dictionary = tmpl["axis_max"]
	for a: String in AXES:
		if amin.has(a):
			out_min[a] = _threshold(amin[a] as Array, diff, rng, jitter, step, 0, 100)
	for a2: String in AXES:
		if amax.has(a2):
			out_max[a2] = _threshold(amax[a2] as Array, diff, rng, jitter, step, 0, 100)
	if tmpl.has("max_length_yd"):
		out["max_length_yd"] = _threshold(tmpl["max_length_yd"] as Array, diff, rng, jitter, step, 50, 700)
	if tmpl.has("min_length_yd"):
		out["min_length_yd"] = _threshold(tmpl["min_length_yd"] as Array, diff, rng, jitter, step, 50, 700)
	if tmpl.has("min_score"):
		out["min_score"] = _threshold(tmpl["min_score"] as Array, diff, rng, jitter, step, 0, 100)
	out["target_score"] = _target_score(out)
	var tk: Dictionary = tmpl["text_keys"]
	out["title_key"] = str(tk["title"])
	out["desc_key"] = str(tk["desc"])
	out["sim_seed"] = sim_seed(day_number)
	return out


static func _weighted(rng: MHRng, weights: Array) -> int:
	var total: int = 0
	for w: Variant in weights:
		total += int(w)
	var r: int = rng.bounded(total)
	var run: int = 0
	for i: int in range(weights.size()):
		run += int(weights[i])
		if r < run:
			return i
	return weights.size() - 1


static func _threshold(pair: Array, diff: int, rng: MHRng, jitter_step: int, round_step: int, lo: int, hi: int) -> int:
	var easy: int = int(pair[0])
	var hard: int = int(pair[1])
	var v: int = easy + MHRMath.rdiv((hard - easy) * diff, 2)
	v += (rng.bounded(3) - 1) * jitter_step
	if round_step > 1:
		v = MHRMath.rdiv(v, round_step) * round_step
	var low_end: int = maxi(lo, mini(easy, hard))
	var high_end: int = mini(hi, maxi(easy, hard))
	return clampi(v, low_end, high_end)


## The score the UI shows as the target: min_score when the template has one, otherwise the rounded mean of the
## minimum axis thresholds, otherwise 0.
static func _target_score(ch: Dictionary) -> int:
	if ch.has("min_score"):
		return int(ch["min_score"])
	var amin: Dictionary = ch["axis_min"]
	if amin.is_empty():
		return 0
	var sum: int = 0
	for k: Variant in amin.keys():
		sum += int(amin[k])
	return MHRMath.rdiv(sum, amin.size())


# ------------------------------------------------------------------ judging

## Judges one attempt against a challenge. entry keys: valid (bool, false for dead or unplayable holes), par,
## length_yd, score (0..100 hole score), axes {accuracy, imagination, length, beauty, fairness} (0..100, see
## axes_from_rating). Returns {"completed": bool, "rows": [[key, met, have, need], ...]}. Row keys: valid, par,
## min_score, axis_min:<axis>, axis_max:<axis>, max_length_yd, min_length_yd.
static func evaluate(ch: Dictionary, entry: Dictionary) -> Dictionary:
	var rows: Array = []
	var valid: bool = bool(entry.get("valid", false))
	rows.append(["valid", valid, 1 if valid else 0, 1])
	var par: int = int(entry.get("par", 0))
	rows.append(["par", par == int(ch.get("par", 0)), par, int(ch.get("par", 0))])
	var axes: Dictionary = entry.get("axes", {}) as Dictionary
	var amin: Dictionary = ch.get("axis_min", {}) as Dictionary
	for a: String in AXES:
		if amin.has(a):
			var have: int = int(axes.get(a, 0))
			rows.append(["axis_min:" + a, have >= int(amin[a]), have, int(amin[a])])
	var amax: Dictionary = ch.get("axis_max", {}) as Dictionary
	for a2: String in AXES:
		if amax.has(a2):
			var have2: int = int(axes.get(a2, 0))
			rows.append(["axis_max:" + a2, have2 <= int(amax[a2]), have2, int(amax[a2])])
	var length_yd: int = int(entry.get("length_yd", 0))
	if ch.has("max_length_yd"):
		rows.append(["max_length_yd", length_yd <= int(ch["max_length_yd"]), length_yd, int(ch["max_length_yd"])])
	if ch.has("min_length_yd"):
		rows.append(["min_length_yd", length_yd >= int(ch["min_length_yd"]), length_yd, int(ch["min_length_yd"])])
	if ch.has("min_score"):
		var sc: int = int(entry.get("score", 0))
		rows.append(["min_score", sc >= int(ch["min_score"]), sc, int(ch["min_score"])])
	var done: bool = true
	for r: Variant in rows:
		if not bool((r as Array)[1]):
			done = false
	return {"completed": done, "rows": rows}

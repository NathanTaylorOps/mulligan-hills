class_name MHGate0Sim
extends RefCounted
## Gate 0 items 3 and 4 logic: golden sim hashes and sim cost arithmetic. Pure except run_one/time_run.
## The golden values are COPIED from game/tests/core/golden/shotsim.json because the Android export
## excludes tests/* (export_presets.cfg.template), so the phone cannot read that file. A unit test
## (game/tests/gate0/test_gate0_sim.gd) fails if the copy drifts from the JSON.

const COURSE_SEED: int = 20260929
const BASE_SEED: int = 777

## Each row: golfers, holes, hash (hex string, 16 chars).
const RUNS: Array = [
	{"golfers": 4, "holes": 3, "hash": "7fe28c37437e041a"},
	{"golfers": 10, "holes": 18, "hash": "e78ef50b1b29abe7"},
	{"golfers": 60, "holes": 18, "hash": "c36530956ac94b59"},
]

## Item 4 (proposed budgets): sim main-thread cost per frame <= 2000 us avg; worker <= 4000 us avg.
const COST_GOLFERS: int = 24
const COST_HOLES: int = 18
const COST_SPEED_X: int = 4
const COST_FPS: int = 60
const BUDGET_MAIN_US: int = 2000
const BUDGET_WORKER_US: int = 4000


static func row_label(row: Dictionary) -> String:
	return "sim_%dx%d" % [int(row["golfers"]), int(row["holes"])]


static func matches(got: String, expected: String) -> bool:
	return got != "" and got.to_lower() == expected.to_lower()


## Executes one golden row. Returns {label, golfers, holes, expected, got, pass, us, total_strokes, max_time}.
static func run_one(row: Dictionary) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var res: Dictionary = MHSimHash.run(COURSE_SEED, BASE_SEED, int(row["golfers"]), int(row["holes"]), true)
	var us: int = Time.get_ticks_usec() - t0
	return make_result(row, str(res["hash"]), us, int(res["total_strokes"]), int(res["max_time"]))


static func make_result(row: Dictionary, got: String, us: int, total_strokes: int, max_time: int) -> Dictionary:
	var expected: String = str(row["hash"])
	return {
		"label": row_label(row), "golfers": int(row["golfers"]), "holes": int(row["holes"]),
		"expected": expected, "got": got, "pass": matches(got, expected),
		"us": us, "total_strokes": total_strokes, "max_time": max_time,
	}


static func all_pass(results: Array) -> bool:
	if results.is_empty():
		return false
	for r: Variant in results:
		var d: Dictionary = r
		if not bool(d["pass"]):
			return false
	return true


@warning_ignore("integer_division")
static func format_result(d: Dictionary) -> String:
	return "%s  %s  got %s\n      expected %s  (%d ms)" % [
		"PASS" if bool(d["pass"]) else "FAIL", d["label"], d["got"], d["expected"], int(d["us"]) / 1000]


## passes: Array of Arrays of result dictionaries (one inner array per pass over all golden rows).
## True when there is at least one pass and every label has the same `got` in every pass.
static func passes_consistent(passes: Array) -> bool:
	if passes.is_empty():
		return false
	var first: Array = passes[0]
	for p: Variant in passes:
		var cur: Array = p
		if cur.size() != first.size():
			return false
		for i: int in range(cur.size()):
			var a: Dictionary = cur[i]
			var b: Dictionary = first[i]
			if str(a["got"]) != str(b["got"]) or str(a["label"]) != str(b["label"]):
				return false
	return true


## Whole-run cost expressed per simulated second (integer microseconds).
@warning_ignore("integer_division")
static func us_per_sim_second(sim_us: int, sim_seconds: int) -> int:
	if sim_seconds <= 0:
		return 0
	return sim_us / sim_seconds


## Cost of one rendered frame when the sim runs at speed_x and the game renders at fps:
## each frame advances speed_x / fps simulated seconds.
@warning_ignore("integer_division")
static func per_frame_us(us_per_sim_s: int, speed_x: int, fps: int) -> int:
	if fps <= 0:
		return 0
	return us_per_sim_s * speed_x / fps


## Runs the item 4 workload once on the calling thread: COST_GOLFERS x COST_HOLES with hashing off.
## Returns {sim_us, sim_seconds, us_per_sim_s, per_frame_us, total_strokes, gen_us}.
static func time_cost_run() -> Dictionary:
	var g0: int = Time.get_ticks_usec()
	var holes: Array = []
	for i: int in range(COST_HOLES):
		holes.append(MHShotSim.make_hole(COURSE_SEED, i))
	var gen_us: int = Time.get_ticks_usec() - g0
	var t0: int = Time.get_ticks_usec()
	var res: Dictionary = MHSimHash.run_with_holes(holes, BASE_SEED, COST_GOLFERS, false)
	var sim_us: int = Time.get_ticks_usec() - t0
	var sim_s: int = int(res["max_time"])
	var ups: int = us_per_sim_second(sim_us, sim_s)
	return {"sim_us": sim_us, "sim_seconds": sim_s, "us_per_sim_s": ups,
		"per_frame_us": per_frame_us(ups, COST_SPEED_X, COST_FPS), "total_strokes": int(res["total_strokes"]), "gen_us": gen_us}


## Verdict against the proposed main-thread budget. The number is the MAIN-THREAD cost the sim would have
## if it ran there; the game plans a worker thread, whose budget is BUDGET_WORKER_US.
static func cost_verdict(per_frame: int) -> String:
	if per_frame <= BUDGET_MAIN_US:
		return "within main-thread budget (%d us)" % BUDGET_MAIN_US
	if per_frame <= BUDGET_WORKER_US:
		return "over main-thread budget, within worker budget (%d us): needs the worker thread" % BUDGET_WORKER_US
	return "over both budgets: GDExtension decision needed"


## Text for the result box. passes: Array of Arrays of result dictionaries.
static func report_text(passes: Array) -> String:
	var lines: Array[String] = []
	for i: int in range(passes.size()):
		lines.append("--- pass %d ---" % (i + 1))
		var rows: Array = passes[i]
		for r: Variant in rows:
			lines.append(format_result(r))
	lines.append("")
	lines.append("all hashes match golden: %s" % ("YES" if not passes.is_empty() and _every_pass_ok(passes) else "NO"))
	lines.append("identical across %d passes: %s" % [passes.size(), "YES" if passes_consistent(passes) else "NO"])
	lines.append("Gate 0 item 3 needs 3 consecutive passes (tap Run again until this says 3).")
	return "\n".join(lines)


static func _every_pass_ok(passes: Array) -> bool:
	for p: Variant in passes:
		if not all_pass(p):
			return false
	return true


## Evidence fields for the item 3 JSON: hashes of the LAST pass keyed by label, and the checks.
static func evidence_fields(passes: Array) -> Dictionary:
	var hashes: Dictionary = {}
	if not passes.is_empty():
		var last: Array = passes[passes.size() - 1]
		for r: Variant in last:
			var d: Dictionary = r
			hashes[str(d["label"])] = str(d["got"])
	return {"hashes": hashes, "passes_run": passes.size(), "all_match_golden": not passes.is_empty() and _every_pass_ok(passes),
		"identical_across_passes": passes_consistent(passes)}


static func overall_result(passes: Array) -> String:
	return "pass" if passes.size() >= 3 and _every_pass_ok(passes) and passes_consistent(passes) else "fail"

extends SceneTree
## Headless benchmark of the shot simulator: 18-hole course, 60 golfers, all playing concurrently.
## Run (from the repo root):  godot --headless --path game -s core/bench_sim.gd
## Prints ONE JSON line to stdout. NOT YET RUN (no Godot binary in the authoring sandbox).
##
## "Simulated second": each golfer's round has a simulated duration (MHShotSim time constants);
## the course clock is the longest golfer round (max_time). us_per_sim_second = wall microseconds
## for the whole 60-golfer round / that many simulated seconds.
## 4x speed means 4 simulated seconds per real second. ASSUMED sim budget: 2 ms per frame at 60 fps
## = 120000 us per real second = 30000 us per simulated second at 4x (budget_us_per_sim_second).
## Timing uses integer microseconds only (Time.get_ticks_usec); no float arithmetic.

const COURSE_SEED: int = 20260929
const BASE_SEED: int = 777
const GOLFERS: int = 60
const HOLES: int = 18
const BUDGET_US_PER_SIM_SECOND: int = 30000


@warning_ignore("integer_division")
func _init() -> void:
	var t_gen0: int = Time.get_ticks_usec()
	var holes: Array = []
	for i in range(HOLES):
		holes.append(MHShotSim.make_hole(COURSE_SEED, i))
	var gen_us: int = Time.get_ticks_usec() - t_gen0

	var t0: int = Time.get_ticks_usec()
	var res: Dictionary = MHSimHash.run_with_holes(holes, BASE_SEED, GOLFERS, false)
	var sim_us: int = Time.get_ticks_usec() - t0

	# Untimed correctness run: compare "hash" against golden/shotsim.json runs[golfers=60, holes=18].
	var hres: Dictionary = MHSimHash.run_with_holes(holes, BASE_SEED, GOLFERS, true)

	var sim_seconds: int = res["max_time"]
	var us_per_sim_s: int = 0
	if sim_seconds > 0:
		us_per_sim_s = sim_us / sim_seconds
	var out: Dictionary = {
		"bench": "mh_shot_sim",
		"godot_version": Engine.get_version_info().get("string", "unknown"),
		"golfers": GOLFERS,
		"holes": HOLES,
		"sim_seconds": sim_seconds,
		"total_strokes": res["total_strokes"],
		"course_gen_us": gen_us,
		"sim_us": sim_us,
		"us_per_sim_second": us_per_sim_s,
		"us_per_sim_second_at_4x_budget": BUDGET_US_PER_SIM_SECOND,
		"within_budget": us_per_sim_s <= BUDGET_US_PER_SIM_SECOND,
		"sim_hash": hres["hash"],
	}
	print(JSON.stringify(out))
	quit()

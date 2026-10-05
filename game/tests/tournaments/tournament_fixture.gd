class_name MHTournamentFixture
extends RefCounted
## Shared helpers for the tournament tests.

const DATA_PATH: String = "res://data/tournaments.json"
const DOCS_COPY: String = "../docs/spec/data/tournaments.json"


static func defs() -> MHTournamentDefs:
	var d: MHTournamentDefs = MHTournamentDefs.new()
	d.load_from_file(DATA_PATH)
	return d


## Club that exactly meets the local entry checklist.
static func local_view() -> Dictionary:
	return {
		"holes": 10,
		"avg_hole_score": 30,
		"pace_score": 50,
		"staff": 4,
		"tiers": {"clubhouse": 3, "cart_barn": 2, "maintenance": 2},
	}


## Club that meets every level including major.
static func strong_view() -> Dictionary:
	return {
		"holes": 18,
		"avg_hole_score": 60,
		"pace_score": 80,
		"staff": 20,
		"tiers": {"clubhouse": 4, "cart_barn": 4, "maintenance": 4, "restaurant": 4, "pro_shop": 2},
	}


## Context used for the golden results (values mirrored by the Python scratch model).
static func golden_ctx(evt_seed: int) -> Dictionary:
	var fair: Array = []
	for i: int in range(10):
		fair.append(60)
	return {
		"event_seed": evt_seed,
		"snapshot_score": 40,
		"pace_score": 60,
		"fairness": fair,
		"maintenance_tier": 3,
		"tiers": {"clubhouse": 3, "cart_barn": 2, "maintenance": 2, "restaurant": 1},
		"total_yards": 3000,
		"pars": [],
	}

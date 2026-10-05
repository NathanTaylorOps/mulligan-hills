class_name MHScoreModel
extends RefCounted
## Pure helpers for the course score and hole lists. Scores are the 0..100 values the player sees.


## Strings key for a course score in tenths (0..1000).
static func band_key(score_x10: int) -> String:
	var s: int = clampi(score_x10, 0, 1000)
	if s < 250:
		return "score.band.poor"
	if s < 400:
		return "score.band.fair"
	if s < 550:
		return "score.band.good"
	if s < 700:
		return "score.band.great"
	return "score.band.superb"


## {hole_no, score} of the lowest scoring hole (first on ties), or {} for no holes.
static func weakest(scores: Array) -> Dictionary:
	if scores.is_empty():
		return {}
	var idx: int = 0
	for i: int in range(scores.size()):
		if int(scores[i]) < int(scores[idx]):
			idx = i
	return {"hole_no": idx + 1, "score": int(scores[idx])}


static func count_dead(scores: Array, dead_below: int) -> int:
	var n: int = 0
	for s: Variant in scores:
		if int(s) < dead_below:
			n += 1
	return n


## The next average-score gate above `avg` (tiers 2..5, lowest requirement over all buildings that tier).
## {tier, need} or {} when the player is above every gate or the catalogue is not loaded.
static func next_gate(defs: MHBuildingDefs, avg: int) -> Dictionary:
	if defs == null or not defs.is_loaded():
		return {}
	for t: int in range(2, MHBuildingDefs.TIER_COUNT + 1):
		var need: int = -1
		for id: Variant in defs.ids():
			var r: Dictionary = defs.tier_requires(str(id), t)
			var n: int = int(r.get("min_avg_hole_score", 0))
			if need < 0 or n < need:
				need = n
		if need > avg:
			return {"tier": t, "need": need}
	return {}

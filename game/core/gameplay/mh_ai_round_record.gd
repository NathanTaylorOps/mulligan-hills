class_name MHAIRoundRecord
extends RefCounted
## Read-only deterministic AI golfer result for a submitted RHI hole.
## This is an adapter over the authoritative MHRSim; it does not invent a second golf model.
## Rendering may consume these records, but never writes simulation state through them.

const DEFAULT_BAND: int = 2


static func play(hole_def: Dictionary, ctx: Dictionary, band: int = DEFAULT_BAND, golfer_index: int = 0) -> Dictionary:
	if band < 0 or band >= 6 or golfer_index < 0:
		return {}
	var validation: Dictionary = MHRatingEngine.validate_input({"schema": 1,
		"engine": MHRatingEngine.RATING_VERSION, "hole": hole_def})
	if not bool(validation.get("ok", false)) or not MHRParams.ensure_loaded():
		return {}
	var hole: MHRHole = MHRHole.from_def(hole_def)
	if not hole.valid:
		return {}
	var condition: Dictionary = ctx.get("condition", {}) as Dictionary
	var sim: MHRSim = MHRSim.new(hole, int(condition.get("wx", 0)), int(condition.get("wy", 0)),
		clampi(int(condition.get("rain", 0)), 0, 3))
	var counts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	counts[band] = golfer_index + 1
	var seed_value: int = MHRatingEngine.seed_for(hole.slot, ctx)
	sim.simulate(seed_value, counts)
	var record_index: int = golfer_index
	if record_index >= sim.n_golfers or sim.rec_band[record_index] != band:
		return {}
	return {"slot_id": hole.slot, "seed": seed_value, "band": band, "golfer_index": golfer_index,
		"skill": sim.rec_skill[record_index], "strokes": sim.rec_strokes[record_index],
		"flags": sim.rec_flags[record_index], "time_s": sim.rec_time[record_index],
		"first_x": sim.rec_fx[record_index], "first_y": sim.rec_fy[record_index],
		"tee_x": hole.tee_x, "tee_y": hole.tee_y, "green_x": hole.gx, "green_y": hole.gy,
		"has_relief": hole.has_relief, "content_hash": hole.content_hash()}

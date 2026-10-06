class_name MHAIRoundTimeline
extends RefCounted
## Cosmetic timing over an authoritative MHAIRoundRecord event list.
## Coordinates/outcomes are never invented here: interpolation only moves between simulator-provided endpoints.

const ADDRESS_S: float = 0.8
const SWING_S: float = 1.2
const FLIGHT_S: float = 1.4
const WALK_SPEED_MPS: float = 3.0
const PUTT_S: float = 1.0
const PAUSE_S: float = 0.4


static func event_duration(event: Dictionary) -> float:
	if str(event.get("kind", "")) == "putt":
		return ADDRESS_S + PUTT_S * float(maxi(1, int(event.get("strokes", 1)))) + PAUSE_S
	var dx_m: float = float(int(event["x1"]) - int(event["x0"])) * 0.009144
	var dy_m: float = float(int(event["y1"]) - int(event["y0"])) * 0.009144
	var walk_m: float = sqrt(dx_m * dx_m + dy_m * dy_m)
	return ADDRESS_S + SWING_S + FLIGHT_S + walk_m / WALK_SPEED_MPS + PAUSE_S


static func total_duration(events: Array) -> float:
	var out: float = 0.0
	for v: Variant in events:
		out += event_duration(v as Dictionary)
	return out


## Returns authoritative centiyard endpoints plus presentation phase/progress.
static func state(events: Array, elapsed_s: float) -> Dictionary:
	if events.is_empty():
		return {"done": true}
	var t: float = maxf(0.0, elapsed_s)
	for i: int in range(events.size()):
		var e: Dictionary = events[i]
		var dur: float = event_duration(e)
		if t > dur:
			t -= dur
			continue
		var kind: String = str(e.get("kind", "shot"))
		var out: Dictionary = {"done": false, "event": i, "kind": kind, "shot": int(e.get("shot", i + 1)),
			"x0": int(e["x0"]), "y0": int(e["y0"]), "x1": int(e["x1"]), "y1": int(e["y1"]),
			"z0": int(e.get("z0", 0)), "z1": int(e.get("z1", 0)), "penalty": int(e.get("penalty", 0)),
			"tree": bool(e.get("tree", false)), "phase": "address", "u": 0.0}
		if kind == "putt":
			var play: float = PUTT_S * float(maxi(1, int(e.get("strokes", 1))))
			if t >= ADDRESS_S:
				out["phase"] = "putt"
				out["u"] = clampf((t - ADDRESS_S) / play, 0.0, 1.0)
			return out
		if t < ADDRESS_S:
			return out
		t -= ADDRESS_S
		if t < SWING_S:
			out["phase"] = "swing"
			out["u"] = t / SWING_S
			return out
		t -= SWING_S
		if t < FLIGHT_S:
			out["phase"] = "flight"
			out["u"] = t / FLIGHT_S
			return out
		t -= FLIGHT_S
		var dx_m: float = float(int(e["x1"]) - int(e["x0"])) * 0.009144
		var dy_m: float = float(int(e["y1"]) - int(e["y0"])) * 0.009144
		var walk_s: float = sqrt(dx_m * dx_m + dy_m * dy_m) / WALK_SPEED_MPS
		out["phase"] = "walk"
		out["u"] = 1.0 if walk_s <= 0.001 else clampf(t / walk_s, 0.0, 1.0)
		return out
	return {"done": true}

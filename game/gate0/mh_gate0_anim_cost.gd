class_name MHGate0AnimCost
extends RefCounted
## Pure helpers for the golfer animation cost scene (Gate 0 item 9, cost half only).


## Grid layout: n positions on the XZ plane, `cols` per row, centred on the origin.
@warning_ignore("integer_division")
static func layout(n: int, cols: int, spacing: float) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	if n <= 0 or cols <= 0:
		return out
	var rows: int = (n + cols - 1) / cols
	var x0: float = -0.5 * float(mini(cols, n) - 1) * spacing
	var z0: float = -0.5 * float(rows - 1) * spacing
	for i: int in range(n):
		out.append(Vector3(x0 + float(i % cols) * spacing, 0.0, z0 + float(i / cols) * spacing))
	return out


## Cost of animating per golfer: (animated - baseline) / n, never negative.
static func per_golfer_ms(baseline_ms: float, animated_ms: float, n: int) -> float:
	if n <= 0:
		return 0.0
	return maxf(0.0, animated_ms - baseline_ms) / float(n)


## Track and key counts of an Animation, as a size proxy. Returns {tracks, keys}.
static func clip_size(anim: Animation) -> Dictionary:
	var keys: int = 0
	for t: int in range(anim.get_track_count()):
		keys += anim.track_get_key_count(t)
	return {"tracks": anim.get_track_count(), "keys": keys}


## Extrapolates the measured per-golfer cost to a target count (linear, an assumption stated in the report).
static func projected_ms(per_golfer: float, count: int) -> float:
	return per_golfer * float(count)


static func verdict(per_golfer: float, budget_per_20_ms: float) -> String:
	return "within budget" if projected_ms(per_golfer, 20) <= budget_per_20_ms else "OVER budget"

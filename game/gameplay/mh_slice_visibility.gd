class_name MHSliceVisibility
extends RefCounted
## Which golfers are drawn how, so the phone keeps its frame rate. Pure logic.
##
## FIGURE: a joint-tree MHGolferFigure (12 draw calls each), only for the few golfers nearest the camera.
## BAKED:  one baked mesh per golfer (1 draw call), swapped between a few frozen poses.
## HIDDEN: not drawn at all (beyond the total cap, the farthest golfers go first).
## A figure is created once per look (see MHSliceSchedule.look_index), so two near golfers with the same look
## cannot both be figures; the second is BAKED. NOT YET RUN in Godot.

const HIDDEN: int = 0
const BAKED: int = 1
const FIGURE: int = 2

## Caps per quality tier: near = max figures, total = max visible golfers. Starting guesses, to be set from
## measurements on the Gate 0 phone (DEC-061). The low tier is the conservative default.
const CAPS: Dictionary = {
	"low": {"near": 2, "total": 10},
	"medium": {"near": 4, "total": 16},
	"high": {"near": 8, "total": 28},
}


static func caps_for_tier(tier_name: String) -> Dictionary:
	var key: String = MHQuality.normalize_name(tier_name)
	return (CAPS[key] as Dictionary).duplicate()


## One state per golfer, in input order. `dist2` is the squared camera distance of each golfer, `looks` the look
## index of each. Ranking is by distance, ties by lower index, so the result is deterministic.
static func classify(dist2: Array, looks: Array, near_cap: int, total_cap: int) -> PackedInt32Array:
	var n: int = dist2.size()
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(n)
	var order: Array = []
	for i: int in range(n):
		order.append([float(dist2[i]), i])
	order.sort_custom(func(a: Array, b: Array) -> bool:
		var da: float = float(a[0])
		var db: float = float(b[0])
		if da == db:
			return int(a[1]) < int(b[1])
		return da < db)
	var figures: int = 0
	var used_looks: Dictionary = {}
	for rank: int in range(n):
		var row: Array = order[rank] as Array
		var idx: int = int(row[1])
		if rank >= maxi(total_cap, 0):
			out[idx] = HIDDEN
			continue
		var look: int = int(looks[idx]) if idx < looks.size() else idx
		if figures < maxi(near_cap, 0) and not used_looks.has(look):
			out[idx] = FIGURE
			used_looks[look] = true
			figures += 1
		else:
			out[idx] = BAKED
	return out


static func count_state(states: PackedInt32Array, wanted: int) -> int:
	var n: int = 0
	for s: int in states:
		if s == wanted:
			n += 1
	return n

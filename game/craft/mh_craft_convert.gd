class_name MHCraftConvert
extends RefCounted
## Turns a painted MHCraftHole into the rating engine's hole input (RHI v1, whole yards, hole-local frame).
## This is the missing step the live construction notes name: painted tiles become rated holes.
## Integer only and deterministic: the same painting always gives the same feature list in the same order.
## NOT YET RUN in Godot.

## Rating feature type for each painted surface ("" = no feature). Greens and tees are not areas for the rating
## engine: the green is a circle at the pin, the tee is a point.
@warning_ignore_start("integer_division")

const FEATURE_OF: Array = [
	"", "fairway", "fairway", "deep_rough", "", "", "", "bunker", "bunker", "water", "ob", "", "",
]
const FEATURE_ORDER: Array = ["fairway", "deep_rough", "bunker", "water", "ob"]
const MAX_FEATURES: int = 3000
const MAX_TREES: int = 1500
const COORD_LIMIT: int = 1200


## Plain-words problem codes that stop a hole from being rated. Empty means the hole can be built.
static func problems(h: MHCraftHole) -> Array:
	var out: Array = []
	if h.tees.is_empty():
		out.append("no_tee")
	if h.count_surface(MHCraftHole.Surface.GREEN) == 0:
		out.append("no_green")
	if h.pins.is_empty():
		out.append("no_pin")
	else:
		for p: Variant in h.pins:
			var v: Vector2i = p as Vector2i
			if h.get_surface(v.x, v.y) != MHCraftHole.Surface.GREEN:
				out.append("pin_not_on_green")
				break
	for t: Variant in h.tees:
		var tv: Vector2i = t as Vector2i
		var s: int = h.get_surface(tv.x, tv.y)
		if s == MHCraftHole.Surface.WATER or s == MHCraftHole.Surface.OUT_OF_BOUNDS:
			out.append("tee_in_hazard")
			break
	if h.trees.size() > MAX_TREES:
		out.append("too_many_trees")
	if out.is_empty():
		var def: Dictionary = _features_only(h)
		if (def["features"] as Array).size() > MAX_FEATURES:
			out.append("too_complex")
		elif absi(h.tile_x0_yd(0)) > COORD_LIMIT or h.tile_y0_yd(h.rows) > COORD_LIMIT:
			out.append("too_large")
	return out


## The hole definition for the tee box `tee_index` and the pin used in `round_no`. Returns {} when problems() is not empty.
static func to_hole_def(h: MHCraftHole, slot_id: int, tee_index: int, round_no: int) -> Dictionary:
	if not problems(h).is_empty():
		return {}
	var tee_tile: Vector2i = h.tees[clampi(tee_index, 0, h.tees.size() - 1)] as Vector2i
	var pin_tile: Vector2i = h.pins[h.pin_for_round(round_no)] as Vector2i
	var tee_pt: Vector2i = h.tile_centre_yd(tee_tile.x, tee_tile.y)
	var pin_pt: Vector2i = h.tile_centre_yd(pin_tile.x, pin_tile.y)
	var area_yd2: int = h.count_surface(MHCraftHole.Surface.GREEN) * MHCraftHole.TILE_YD * MHCraftHole.TILE_YD
	var radius: int = maxi(1, _isqrt(area_yd2 * 7 / 22)) # pi as 22 / 7, whole yards
	var out: Dictionary = _features_only(h)
	out["slot_id"] = slot_id
	out["tee"] = [tee_pt.x, tee_pt.y]
	out["green"] = [pin_pt.x, pin_pt.y, radius]
	out["tee_z_mm"] = h.get_height(tee_tile.x, tee_tile.y) * 1000
	out["green_z_mm"] = h.get_height(pin_tile.x, pin_tile.y) * 1000
	return out


## The full rating input wrapper, ready for MHRatingEngine.validate_input and rate_hole.
static func rating_input(h: MHCraftHole, slot_id: int, tee_index: int, round_no: int) -> Dictionary:
	var def: Dictionary = to_hole_def(h, slot_id, tee_index, round_no)
	if def.is_empty():
		return {}
	return {"schema": 1, "engine": MHRatingEngine.RATING_VERSION, "hole": def}


## Hole length in yards from the chosen tee to the pin (straight line, rounded down).
static func length_yd(h: MHCraftHole, tee_index: int, round_no: int) -> int:
	if h.tees.is_empty() or h.pins.is_empty():
		return 0
	var t: Vector2i = h.tees[clampi(tee_index, 0, h.tees.size() - 1)] as Vector2i
	var p: Vector2i = h.pins[h.pin_for_round(round_no)] as Vector2i
	var a: Vector2i = h.tile_centre_yd(t.x, t.y)
	var b: Vector2i = h.tile_centre_yd(p.x, p.y)
	var dx: int = b.x - a.x
	var dy: int = b.y - a.y
	return _isqrt(dx * dx + dy * dy)


static func _features_only(h: MHCraftHole) -> Dictionary:
	var feats: Array = []
	for ftype: Variant in FEATURE_ORDER:
		for rect: Variant in _rects_for(h, str(ftype)):
			feats.append({"t": str(ftype), "rect": rect})
	if not h.trees.is_empty():
		var pts: Array = h.trees.duplicate()
		pts.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
		var at: Array = []
		for p: Variant in pts:
			at.append([(p as Vector2i).x, (p as Vector2i).y])
		feats.append({"t": "tree", "at": at})
	if h.rocks > 0:
		feats.append({"t": "rock", "count": h.rocks})
	if h.flowers > 0:
		feats.append({"t": "flower", "count": h.flowers})
	return {"features": feats}


## Greedy rectangle cover of every tile whose surface maps to `ftype`: scan rows bottom edge first (row 0 up), left to
## right; take the longest free run, grow it along rows while the same columns are all free, emit, mark used.
static func _rects_for(h: MHCraftHole, ftype: String) -> Array:
	var used: PackedByteArray = PackedByteArray()
	used.resize(h.cols * h.rows)
	used.fill(0)
	var out: Array = []
	for r: int in range(h.rows):
		var c: int = 0
		while c < h.cols:
			if _is_free(h, used, c, r, ftype):
				var c1: int = c
				while c1 + 1 < h.cols and _is_free(h, used, c1 + 1, r, ftype):
					c1 += 1
				var r1: int = r
				while r1 + 1 < h.rows and _run_free(h, used, c, c1, r1 + 1, ftype):
					r1 += 1
				for rr: int in range(r, r1 + 1):
					for cc: int in range(c, c1 + 1):
						used[h.index_of(cc, rr)] = 1
				out.append([h.tile_x0_yd(c), h.tile_y0_yd(r), h.tile_x0_yd(c1) + MHCraftHole.TILE_YD,
					h.tile_y0_yd(r1) + MHCraftHole.TILE_YD])
				c = c1 + 1
			else:
				c += 1
	return out


static func _is_free(h: MHCraftHole, used: PackedByteArray, c: int, r: int, ftype: String) -> bool:
	if used[h.index_of(c, r)] != 0:
		return false
	return str(FEATURE_OF[h.get_surface(c, r)]) == ftype


static func _run_free(h: MHCraftHole, used: PackedByteArray, c0: int, c1: int, r: int, ftype: String) -> bool:
	for c: int in range(c0, c1 + 1):
		if not _is_free(h, used, c, r, ftype):
			return false
	return true


## Integer square root (floor), exact for any non-negative int.
static func _isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var x: int = n
	var y: int = (x + 1) / 2
	while y < x:
		x = y
		y = (x + n / x) / 2
	return x

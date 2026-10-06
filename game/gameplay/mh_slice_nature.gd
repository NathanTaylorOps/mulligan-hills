class_name MHSliceNature
extends RefCounted
## Deterministic nature scatter for the vertical slice. Pure: same (seed, count) always gives the same list.
## Items avoid the hole corridors and the building parcels, so trees stand around the course, not on it.
## Uses MHArtRng (integer RNG); positions are floats because this is presentation only.
## NOT YET RUN in Godot.

## Kind weights (kinds are MHNatureMeshes kind ids). Total 18.
const KIND_WEIGHTS: Array = [["pine", 4], ["oak", 3], ["birch", 2], ["bush", 3], ["rock", 1],
	["tall_grass", 2], ["flower_patch", 1], ["rock_cluster", 1], ["palm", 1]]
## Only variants 0..VARIANTS_USED-1 are used, to keep MultiMesh groups (draw calls) few.
const VARIANTS_USED: int = 2
const LOD_NEAR_RADIUS_M: float = 85.0
## Area scattered over: the map plus a ring this wide around it.
const RING_M: float = 36.0
const CORRIDOR_HALF_WIDTH_M: float = 10.0
const CORRIDOR_PAD_M: float = 6.0
const MAX_TRIES_PER_ITEM: int = 12


## Exclusion rectangles (x, z, width, depth in metres): all hole corridors, all parcels where buildings may
## sit, and the annex strip.
static func exclusion_rects() -> Array:
	var out: Array = []
	for slot: int in range(MHSliceLayout.hole_slot_count()):
		var tee: Vector2 = MHSliceLayout.hole_point_m(slot, 0, 0)
		var green: Vector2 = MHSliceLayout.hole_point_m(slot, 0, MHSliceLayout.HOLE_LENGTH_YD)
		out.append(Rect2(tee.x - CORRIDOR_HALF_WIDTH_M, tee.y - CORRIDOR_PAD_M,
			CORRIDOR_HALF_WIDTH_M * 2.0, green.y - tee.y + CORRIDOR_PAD_M * 2.0))
	for parcel: int in range(MHSliceLayout.PARCEL_COUNT):
		if MHSliceLayout.is_reserved(parcel):
			continue
		var o: Vector2 = MHSliceLayout.parcel_origin_m(parcel)
		out.append(Rect2(o.x, o.y, MHSliceLayout.PARCEL_M, MHSliceLayout.PARCEL_M))
	out.append(Rect2(0.0, MHSliceLayout.MAP_M, MHSliceLayout.MAP_M, 48.0))
	return out


static func is_excluded(x: float, z: float, rects: Array) -> bool:
	var p: Vector2 = Vector2(x, z)
	for r: Variant in rects:
		if (r as Rect2).has_point(p):
			return true
	return false


static func _pick_kind(roll: int) -> String:
	var total: int = 0
	for row: Variant in KIND_WEIGHTS:
		total += int((row as Array)[1])
	var r: int = roll % total
	for row2: Variant in KIND_WEIGHTS:
		var w: int = int((row2 as Array)[1])
		if r < w:
			return str((row2 as Array)[0])
		r -= w
	return "pine"


## Up to `count` items (fewer if the exclusions leave no room). Each is
## {"kind": String, "variant": int, "lod": int, "x": float, "z": float, "yaw": float, "scale": float}.
static func scatter(seed_value: int, count: int) -> Array:
	var rng: MHArtRng = MHArtRng.new(seed_value * 2654435 + 91)
	var rects: Array = exclusion_rects()
	var span: float = MHSliceLayout.MAP_M + RING_M * 2.0
	var items: Array = []
	for i: int in range(maxi(count, 0)):
		for attempt: int in range(MAX_TRIES_PER_ITEM):
			var x: float = -RING_M + rng.unit() * span
			var z: float = -RING_M + rng.unit() * span
			if is_excluded(x, z, rects):
				continue
			var kind: String = _pick_kind(rng.next_u32())
			var variant: int = rng.range_int(VARIANTS_USED)
			var yaw: float = rng.unit() * TAU
			var scale_value: float = 0.85 + rng.unit() * 0.4
			var dx: float = x - MHSliceLayout.MAP_M * 0.5
			var dz: float = z - MHSliceLayout.MAP_M * 0.5
			var lod: int = 0 if dx * dx + dz * dz < LOD_NEAR_RADIUS_M * LOD_NEAR_RADIUS_M else 1
			items.append({"kind": kind, "variant": variant, "lod": lod, "x": x, "z": z, "yaw": yaw, "scale": scale_value})
			break
	return items


## Items grouped by (kind, lod, variant) so each group is one MultiMesh. Keys are "kind|lod|variant", values are
## Arrays of item dictionaries, keys in sorted order for a stable node order.
static func group(items: Array) -> Dictionary:
	var groups: Dictionary = {}
	for it: Variant in items:
		var d: Dictionary = it
		var key: String = "%s|%d|%d" % [str(d["kind"]), int(d["lod"]), int(d["variant"])]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(d)
	var keys: Array = groups.keys()
	keys.sort()
	var out: Dictionary = {}
	for k: Variant in keys:
		out[k] = groups[k]
	return out

class_name MHTreePlacement
extends RefCounted
## Deterministic tree placement in integer millimetres (integers only, no floats).
## World square is WORLD_MM x WORLD_MM, split into GRID x GRID chunks.
## Output is a flat PackedInt32Array, STRIDE ints per tree:
##   [x_mm, z_mm, yaw_deci_deg (0..3599), scale_pct (80..140), variant (0..2), chunk_index]

const WORLD_MM: int = 400000
const GRID: int = 4
const STRIDE: int = 6
const MAX_ATTEMPTS: int = 64
const YAW_STEPS: int = 3600
const SCALE_MIN_PCT: int = 80
const SCALE_SPAN: int = 61
const VARIANTS: int = 3

## Exclusion rectangles [x0, z0, x1, z1] in mm: pond and fairway.
const EXCLUSIONS: Array = [
	[150000, 160000, 250000, 240000],
	[40000, 90000, 360000, 130000],
]


static func is_excluded(x: int, z: int) -> bool:
	for r in EXCLUSIONS:
		var rect: Array = r
		if x >= int(rect[0]) and x <= int(rect[2]) and z >= int(rect[1]) and z <= int(rect[3]):
			return true
	return false


@warning_ignore("integer_division")
static func chunk_size_mm() -> int:
	return WORLD_MM / GRID


static func chunk_count() -> int:
	return GRID * GRID


@warning_ignore("integer_division")
static func chunk_index_for(x: int, z: int) -> int:
	var cs: int = chunk_size_mm()
	var cx: int = clampi(x / cs, 0, GRID - 1)
	var cz: int = clampi(z / cs, 0, GRID - 1)
	return cx + cz * GRID


## Trees that fail 64 attempts are dropped (count may then be below `count`).
static func place(seed_value: int, count: int) -> PackedInt32Array:
	var rng: MHForestRng = MHForestRng.new(seed_value)
	var out: PackedInt32Array = PackedInt32Array()
	for i in range(count):
		var ok: bool = false
		var x: int = 0
		var z: int = 0
		for a in range(MAX_ATTEMPTS):
			x = rng.range_int(WORLD_MM)
			z = rng.range_int(WORLD_MM)
			if not is_excluded(x, z):
				ok = true
				break
		var yaw: int = rng.range_int(YAW_STEPS)
		var sc: int = SCALE_MIN_PCT + rng.range_int(SCALE_SPAN)
		var variant: int = rng.range_int(VARIANTS)
		if not ok:
			continue
		out.append(x)
		out.append(z)
		out.append(yaw)
		out.append(sc)
		out.append(variant)
		out.append(chunk_index_for(x, z))
	return out


## FNV-1a style checksum over the flat array (32-bit).
static func checksum(data: PackedInt32Array) -> int:
	var h: int = 0x811C9DC5
	for v in data:
		h = MHForestRng.mul32(h ^ (v & 0xFFFFFFFF), 16777619)
	return h


## Groups tree indices by chunk. Returns Array (size chunk_count) of PackedInt32Array of tree indices.
@warning_ignore("integer_division")
static func group_by_chunk(data: PackedInt32Array) -> Array:
	var groups: Array = []
	for c in range(chunk_count()):
		groups.append(PackedInt32Array())
	var n: int = data.size() / STRIDE
	for i in range(n):
		var c: int = data[i * STRIDE + 5]
		var g: PackedInt32Array = groups[c]
		g.append(i)
		groups[c] = g
	return groups

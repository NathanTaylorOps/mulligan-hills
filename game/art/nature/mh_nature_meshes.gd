class_name MHNatureMeshes
extends RefCounted
## Procedural nature meshes: pine, oak, birch, palm, bush, rock, rock cluster, flower patch, reeds,
## cattails, tall grass clump. Everything is built from primitives in code (DEC-062), flat shaded with
## vertex colours (palette from MHPalette), one surface per mesh so a MultiMesh can draw it.
##
## LODs: 0 (near), 1 (mid), 2 (far, a handful of triangles). Triangle budgets are in BUDGETS and are
## enforced by tests/art_nature/test_nature_meshes.gd. Every tree LOD0 is under 400 triangles.
## `variant` (0..VARIANTS-1, any int works) changes proportions, jitter and colour drift, but the
## same (kind, lod, variant) always gives the same vertices.
##
## Units are metres, origin on the ground at the centre of the trunk or clump, +Y up.

const KIND_PINE: String = "pine"
const KIND_OAK: String = "oak"
const KIND_BIRCH: String = "birch"
const KIND_PALM: String = "palm"
const KIND_BUSH: String = "bush"
const KIND_ROCK: String = "rock"
const KIND_ROCK_CLUSTER: String = "rock_cluster"
const KIND_FLOWERS: String = "flower_patch"
const KIND_REEDS: String = "reeds"
const KIND_CATTAILS: String = "cattails"
const KIND_TALL_GRASS: String = "tall_grass"

const TREE_KINDS: Array = ["pine", "oak", "birch", "palm"]
const KINDS: Array = ["pine", "oak", "birch", "palm", "bush", "rock", "rock_cluster",
	"flower_patch", "reeds", "cattails", "tall_grass"]
const VARIANTS: int = 4
const LOD_COUNT: int = 3
const TREE_LOD0_LIMIT: int = 400

## Maximum triangles per kind, indexed by LOD. Actual counts are lower; tests check actual <= budget.
const BUDGETS: Dictionary = {
	"pine": [220, 60, 24],
	"oak": [330, 130, 40],
	"birch": [260, 70, 24],
	"palm": [230, 90, 24],
	"bush": [150, 40, 16],
	"rock": [64, 30, 12],
	"rock_cluster": [130, 50, 16],
	"flower_patch": [80, 40, 12],
	"reeds": [80, 20, 8],
	"cattails": [170, 64, 12],
	"tall_grass": [40, 20, 8],
}

## Rough height in metres at variant 0 (for galleries and placement; not a hard bound).
const HEIGHTS: Dictionary = {
	"pine": 9.0, "oak": 7.5, "birch": 7.0, "palm": 7.5, "bush": 1.3, "rock": 1.0,
	"rock_cluster": 1.2, "flower_patch": 0.5, "reeds": 1.8, "cattails": 1.6, "tall_grass": 0.9,
}


static func is_tree(kind: String) -> bool:
	return TREE_KINDS.has(kind)


static func budget(kind: String, lod: int) -> int:
	var arr: Array = BUDGETS[kind]
	return int(arr[clampi(lod, 0, LOD_COUNT - 1)])


static func height_of(kind: String) -> float:
	return float(HEIGHTS[kind])


## Builds the mesh for (kind, lod, variant). Unknown kinds return an empty mesh.
static func build(kind: String, lod: int, variant: int) -> ArrayMesh:
	return build_builder(kind, lod, variant).to_mesh()


## Same geometry as `build` but returns the builder (for hashing and counting without a Mesh).
static func build_builder(kind: String, lod: int, variant: int) -> MHMeshBuilder:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	var l: int = clampi(lod, 0, LOD_COUNT - 1)
	var v: int = ((variant % 1024) + 1024) % 1024
	match kind:
		"pine":
			_pine(b, l, v)
		"oak":
			_oak(b, l, v)
		"birch":
			_birch(b, l, v)
		"palm":
			_palm(b, l, v)
		"bush":
			_bush(b, l, v)
		"rock":
			_rock(b, l, v)
		"rock_cluster":
			_rock_cluster(b, l, v)
		"flower_patch":
			_flowers(b, l, v)
		"reeds":
			_reeds(b, l, v)
		"cattails":
			_cattails(b, l, v)
		"tall_grass":
			_tall_grass(b, l, v)
	return b


# ---------------------------------------------------------------- helpers

static func _rng(kind_id: int, lod: int, variant: int) -> MHArtRng:
	return MHArtRng.new(kind_id * 100003 + variant * 7919 + 17)


## Thin leaning blade, visible from both sides (2 triangles).
static func _blade(b: MHMeshBuilder, base: Vector3, yaw: float, lean: float, height: float,
		width: float, c_base: Color, c_tip: Color) -> void:
	var side: Vector3 = Vector3(cos(yaw), 0.0, sin(yaw)) * (width * 0.5)
	var fwd: Vector3 = Vector3(-sin(yaw), 0.0, cos(yaw)) * lean
	b.tri_two_sided(base - side, base + side, base + fwd + Vector3(0.0, height, 0.0), c_base, c_base, c_tip)


## Two-segment bent blade (6 triangles): a quad then a tip triangle, bending further at the top.
static func _bent_blade(b: MHMeshBuilder, base: Vector3, yaw: float, lean: float, height: float,
		width: float, c_base: Color, c_tip: Color) -> void:
	var side: Vector3 = Vector3(cos(yaw), 0.0, sin(yaw)) * (width * 0.5)
	var fwd: Vector3 = Vector3(-sin(yaw), 0.0, cos(yaw))
	var mid: Vector3 = base + fwd * (lean * 0.25) + Vector3(0.0, height * 0.6, 0.0)
	var tip: Vector3 = base + fwd * lean + Vector3(0.0, height, 0.0)
	var c_mid: Color = c_base.lerp(c_tip, 0.5)
	b.quad_two_sided(base - side, base + side, mid + side * 0.6, mid - side * 0.6, c_base, c_mid)
	b.tri_two_sided(mid - side * 0.6, mid + side * 0.6, tip, c_mid, c_mid, c_tip)


static func _crown(b: MHMeshBuilder, centre: Vector3, radii: Vector3, stacks: int, sides: int,
		low: Color, high: Color, seed_value: int, jitter: float) -> void:
	b.blob(centre, radii, stacks, sides, low, high, seed_value, jitter)


# ---------------------------------------------------------------- trees

## Scots-style pine: tall bare trunk, flat cloud-like crown of three blobs. LOD0 about 156 tris.
static func _pine(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var rng: MHArtRng = _rng(1, lod, variant)
	var h: float = 5.4 + rng.range_f(0.0, 1.2)
	var lean: float = rng.range_f(-0.25, 0.25)
	var drift: float = rng.signed()
	var low: Color = MHPalette.drift(MHPalette.PINE_LOW, drift, 0.08)
	var high: Color = MHPalette.drift(MHPalette.PINE_HIGH, drift, 0.08)
	var bark: Color = MHPalette.BARK
	var top: Vector3 = Vector3(lean, h, 0.0)
	if lod == 0:
		var p1: Vector3 = Vector3(lean * 0.3, h * 0.35, 0.05)
		var p2: Vector3 = Vector3(lean * 0.7, h * 0.7, -0.05)
		b.tube(Vector3.ZERO, p1, 0.30, 0.25, 6, bark, bark)
		b.tube(p1, p2, 0.25, 0.20, 6, bark, bark)
		b.tube(p2, top, 0.20, 0.14, 6, bark, MHPalette.BARK_DARK)
		_crown(b, top + Vector3(0.0, -0.5, 0.0), Vector3(2.1, 1.05, 2.0), 3, 9, low, high, variant * 3 + 1, 0.16)
		_crown(b, top + Vector3(1.0, -1.3, 0.6), Vector3(1.5, 0.8, 1.4), 3, 9, low, high, variant * 3 + 2, 0.16)
		_crown(b, top + Vector3(-0.9, -1.5, -0.6), Vector3(1.4, 0.75, 1.3), 3, 9, low, high, variant * 3 + 3, 0.16)
		_crown(b, top + Vector3(0.1, 0.5, 0.0), Vector3(1.0, 0.6, 1.0), 2, 6, low, high, variant * 3 + 4, 0.12)
	elif lod == 1:
		b.tube(Vector3.ZERO, top, 0.30, 0.16, 5, bark, bark)
		_crown(b, top + Vector3(0.0, -0.6, 0.0), Vector3(2.1, 1.1, 2.0), 2, 6, low, high, variant + 11, 0.14)
		_crown(b, top + Vector3(0.6, -1.4, 0.5), Vector3(1.4, 0.8, 1.3), 2, 6, low, high, variant + 12, 0.14)
	else:
		b.tube(Vector3.ZERO, top, 0.28, 0.16, 3, bark, bark)
		_crown(b, top + Vector3(0.0, -0.8, 0.0), Vector3(2.0, 1.2, 2.0), 2, 5, low, high, variant + 21, 0.1)


## Broad oak: flared trunk, three branches, six-blob canopy. LOD0 about 244 tris.
static func _oak(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var rng: MHArtRng = _rng(2, lod, variant)
	var scale: float = 0.9 + rng.range_f(0.0, 0.25)
	var drift: float = rng.signed()
	var low: Color = MHPalette.drift(MHPalette.OAK_LOW, drift, 0.08)
	var high: Color = MHPalette.drift(MHPalette.OAK_HIGH, drift, 0.08)
	var bark: Color = MHPalette.BARK
	var cy: float = 4.6 * scale
	if lod == 0:
		b.frustum(0.0, 0.6, 0.58, 0.38, 7, bark, bark, false, false)
		b.frustum(0.6, 2.3, 0.38, 0.30, 7, bark, MHPalette.BARK_DARK, false, false)
		b.tube(Vector3(0.0, 2.1, 0.0), Vector3(1.3, 3.5, 0.3) * scale, 0.20, 0.10, 4, bark, bark)
		b.tube(Vector3(0.0, 2.2, 0.0), Vector3(-1.2, 3.6, -0.5) * scale, 0.20, 0.10, 4, bark, bark)
		b.tube(Vector3(0.0, 2.3, 0.0), Vector3(0.2, 3.9, 1.2) * scale, 0.18, 0.09, 4, bark, bark)
		_crown(b, Vector3(0.0, cy, 0.0), Vector3(2.6, 1.7, 2.5) * scale, 3, 8, low, high, variant * 7 + 1, 0.15)
		_crown(b, Vector3(1.9, cy - 0.5, 0.5) * scale, Vector3(1.8, 1.3, 1.8) * scale, 3, 8, low, high, variant * 7 + 2, 0.15)
		_crown(b, Vector3(-1.8, cy - 0.4, -0.6) * scale, Vector3(1.8, 1.3, 1.7) * scale, 3, 8, low, high, variant * 7 + 3, 0.15)
		_crown(b, Vector3(0.3, cy - 0.3, 1.9) * scale, Vector3(1.7, 1.2, 1.6) * scale, 3, 8, low, high, variant * 7 + 4, 0.15)
		_crown(b, Vector3(-0.4, cy - 0.4, -1.9) * scale, Vector3(1.6, 1.2, 1.5) * scale, 3, 8, low, high, variant * 7 + 5, 0.15)
		_crown(b, Vector3(0.2, cy + 1.0 * scale, 0.1), Vector3(1.6, 1.0, 1.5) * scale, 3, 8, low, high, variant * 7 + 6, 0.15)
	elif lod == 1:
		b.frustum(0.0, 2.4, 0.5, 0.3, 5, bark, bark, false, false)
		_crown(b, Vector3(0.0, cy, 0.0), Vector3(2.7, 1.8, 2.6) * scale, 3, 7, low, high, variant + 31, 0.14)
		_crown(b, Vector3(1.6, cy - 0.5, 0.6) * scale, Vector3(1.8, 1.3, 1.8) * scale, 3, 7, low, high, variant + 32, 0.14)
		_crown(b, Vector3(-1.5, cy - 0.4, -0.7) * scale, Vector3(1.8, 1.3, 1.7) * scale, 3, 7, low, high, variant + 33, 0.14)
	else:
		b.frustum(0.0, 2.4, 0.45, 0.3, 4, bark, bark, false, false)
		_crown(b, Vector3(0.0, cy, 0.0), Vector3(3.2, 2.0, 3.0) * scale, 3, 6, low, high, variant + 41, 0.1)


## Slim birch: white trunk with dark bands, airy light-green canopy. LOD0 about 200 tris.
static func _birch(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var rng: MHArtRng = _rng(3, lod, variant)
	var h: float = 5.0 + rng.range_f(0.0, 1.0)
	var lean: float = rng.range_f(-0.2, 0.2)
	var drift: float = rng.signed()
	var low: Color = MHPalette.drift(MHPalette.BIRCH_LOW, drift, 0.08)
	var high: Color = MHPalette.drift(MHPalette.BIRCH_HIGH, drift, 0.06)
	var white: Color = MHPalette.BIRCH_BARK
	var mark: Color = MHPalette.BIRCH_MARK
	if lod == 0:
		var seg: float = h / 4.0
		for i in range(4):
			var f0: float = float(i) / 4.0
			var f1: float = float(i + 1) / 4.0
			var col: Color = white
			if i % 2 == 1:
				col = mark.lerp(white, 0.35)
			b.tube(Vector3(lean * f0, seg * float(i), 0.0), Vector3(lean * f1, seg * float(i + 1), 0.0),
				0.20 - 0.03 * float(i), 0.20 - 0.03 * float(i + 1), 6, col, col)
		b.tube(Vector3(lean * 0.6, h * 0.6, 0.0), Vector3(lean + 1.1, h * 0.95, 0.4), 0.06, 0.03, 3, white, white)
		b.tube(Vector3(lean * 0.6, h * 0.65, 0.0), Vector3(lean - 1.0, h * 0.98, -0.4), 0.06, 0.03, 3, white, white)
		var top: Vector3 = Vector3(lean, h, 0.0)
		_crown(b, top + Vector3(0.0, 0.2, 0.0), Vector3(1.5, 1.4, 1.5), 3, 7, low, high, variant * 5 + 1, 0.2)
		_crown(b, top + Vector3(1.1, -0.5, 0.4), Vector3(1.1, 1.0, 1.1), 3, 7, low, high, variant * 5 + 2, 0.2)
		_crown(b, top + Vector3(-1.0, -0.6, -0.4), Vector3(1.1, 1.0, 1.0), 3, 7, low, high, variant * 5 + 3, 0.2)
		_crown(b, top + Vector3(0.2, -1.1, 0.9), Vector3(1.0, 0.9, 1.0), 3, 7, low, high, variant * 5 + 4, 0.2)
		_crown(b, top + Vector3(-0.2, -1.0, -1.0), Vector3(1.0, 0.9, 1.0), 3, 7, low, high, variant * 5 + 5, 0.2)
	elif lod == 1:
		b.tube(Vector3.ZERO, Vector3(lean, h, 0.0), 0.20, 0.10, 5, white, white)
		var t1: Vector3 = Vector3(lean, h, 0.0)
		_crown(b, t1 + Vector3(0.0, 0.1, 0.0), Vector3(1.6, 1.5, 1.6), 2, 6, low, high, variant + 51, 0.15)
		_crown(b, t1 + Vector3(0.9, -0.9, 0.3), Vector3(1.2, 1.0, 1.2), 2, 6, low, high, variant + 52, 0.15)
		_crown(b, t1 + Vector3(-0.9, -1.0, -0.3), Vector3(1.2, 1.0, 1.1), 2, 6, low, high, variant + 53, 0.15)
	else:
		b.tube(Vector3.ZERO, Vector3(lean, h, 0.0), 0.2, 0.1, 3, white, white)
		_crown(b, Vector3(lean, h - 0.3, 0.0), Vector3(1.8, 1.7, 1.8), 2, 5, low, high, variant + 61, 0.1)


## Palm: gently curved segmented trunk, radiating fronds, coconuts. LOD0 about 170 tris.
static func _palm(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var rng: MHArtRng = _rng(4, lod, variant)
	var h: float = 6.0 + rng.range_f(0.0, 1.4)
	var bend: float = rng.range_f(0.6, 1.4)
	var yaw0: float = rng.range_f(0.0, TAU)
	var dirx: float = cos(yaw0)
	var dirz: float = sin(yaw0)
	var bark: Color = MHPalette.PALM_BARK
	var dark: Color = MHPalette.drift(MHPalette.PALM_BARK, -1.0, 0.18)
	var segs: int = 5
	var sides: int = 6
	if lod == 1:
		segs = 2
		sides = 5
	elif lod == 2:
		segs = 1
		sides = 3
	var prev: Vector3 = Vector3.ZERO
	for i in range(segs):
		var f: float = float(i + 1) / float(segs)
		var off: float = bend * f * f
		var cur: Vector3 = Vector3(dirx * off, h * f, dirz * off)
		var r0: float = 0.26 - 0.08 * (float(i) / float(segs))
		var r1: float = 0.26 - 0.08 * f
		var col: Color = bark
		if i % 2 == 1:
			col = dark
		b.tube(prev, cur, r0, r1, sides, col, col)
		prev = cur
	var crown: Vector3 = prev
	var frond_n: int = 8
	if lod == 1:
		frond_n = 6
	elif lod == 2:
		frond_n = 4
	var lo: Color = MHPalette.PALM_LOW
	var hi: Color = MHPalette.PALM_HIGH
	for i in range(frond_n):
		var yaw: float = TAU * float(i) / float(frond_n) + rng.range_f(-0.15, 0.15)
		var len_f: float = 2.4 + rng.range_f(0.0, 0.5)
		var w: float = 0.55
		var out: Vector3 = Vector3(cos(yaw), 0.0, sin(yaw))
		var side: Vector3 = Vector3(-sin(yaw), 0.0, cos(yaw)) * w
		if lod == 0:
			var p1: Vector3 = crown + out * (len_f * 0.4) + Vector3(0.0, 0.55, 0.0)
			var p2: Vector3 = crown + out * (len_f * 0.8) + Vector3(0.0, 0.35, 0.0)
			var p3: Vector3 = crown + out * len_f + Vector3(0.0, -0.45, 0.0)
			b.quad_two_sided(crown - side * 0.15, crown + side * 0.15, p1 + side * 0.8, p1 - side * 0.8, lo, lo.lerp(hi, 0.5))
			b.quad_two_sided(p1 - side * 0.8, p1 + side * 0.8, p2 + side * 0.5, p2 - side * 0.5, lo.lerp(hi, 0.5), hi)
			b.tri_two_sided(p2 - side * 0.5, p2 + side * 0.5, p3, hi, hi, lo)
		elif lod == 1:
			var q1: Vector3 = crown + out * (len_f * 0.55) + Vector3(0.0, 0.5, 0.0)
			var q2: Vector3 = crown + out * len_f + Vector3(0.0, -0.4, 0.0)
			b.quad_two_sided(crown - side * 0.15, crown + side * 0.15, q1 + side * 0.7, q1 - side * 0.7, lo, hi)
			b.tri_two_sided(q1 - side * 0.7, q1 + side * 0.7, q2, hi, hi, lo)
		else:
			var r2: Vector3 = crown + out * len_f + Vector3(0.0, -0.3, 0.0)
			b.tri_two_sided(crown - side * 0.6, crown + side * 0.6, r2, lo, lo, hi)
	if lod == 0:
		var nut: Color = MHPalette.COCONUT
		for i in range(3):
			var a: float = yaw0 + TAU * float(i) / 3.0
			b.blob(crown + Vector3(cos(a) * 0.25, -0.25, sin(a) * 0.25), Vector3(0.13, 0.13, 0.13), 2, 5, nut, nut, variant + i, 0.05)


## Rounded bush of overlapping blobs; odd variants carry flower specks. LOD0 up to 136 tris.
static func _bush(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var rng: MHArtRng = _rng(5, lod, variant)
	var drift: float = rng.signed()
	var low: Color = MHPalette.drift(MHPalette.BUSH_LOW, drift, 0.08)
	var high: Color = MHPalette.drift(MHPalette.BUSH_HIGH, drift, 0.08)
	var s: float = 0.85 + rng.range_f(0.0, 0.35)
	if lod == 0:
		_crown(b, Vector3(0.0, 0.55, 0.0) * s, Vector3(0.9, 0.6, 0.85) * s, 3, 7, low, high, variant * 4 + 1, 0.16)
		_crown(b, Vector3(0.65, 0.42, 0.25) * s, Vector3(0.6, 0.45, 0.6) * s, 3, 7, low, high, variant * 4 + 2, 0.16)
		_crown(b, Vector3(-0.6, 0.4, -0.2) * s, Vector3(0.6, 0.45, 0.55) * s, 3, 7, low, high, variant * 4 + 3, 0.16)
		_crown(b, Vector3(0.1, 0.38, -0.65) * s, Vector3(0.55, 0.4, 0.5) * s, 3, 7, low, high, variant * 4 + 4, 0.16)
		if variant % 2 == 1:
			var petal: Color = MHPalette.pick(MHPalette.FLOWERS, variant)
			for i in range(6):
				var a: float = TAU * float(i) / 6.0 + rng.range_f(0.0, 0.5)
				var r: float = 0.5 + rng.range_f(0.0, 0.35)
				var p: Vector3 = Vector3(cos(a) * r, 0.75 + rng.range_f(0.0, 0.3), sin(a) * r) * s
				b.set_xf(Transform3D(Basis(), p))
				b.frustum(0.0, 0.07, 0.09, 0.0, 4, petal, petal, false, false)
				b.reset_xf()
	elif lod == 1:
		_crown(b, Vector3(0.0, 0.55, 0.0) * s, Vector3(1.0, 0.65, 0.95) * s, 2, 6, low, high, variant + 71, 0.14)
		_crown(b, Vector3(0.5, 0.4, -0.3) * s, Vector3(0.6, 0.45, 0.6) * s, 2, 6, low, high, variant + 72, 0.14)
	else:
		_crown(b, Vector3(0.0, 0.5, 0.0) * s, Vector3(1.2, 0.6, 1.1) * s, 2, 5, low, high, variant + 81, 0.1)


# ---------------------------------------------------------------- rocks

static func _rock_colors(variant: int) -> Array:
	var n: float = MHArtRng.noise2(variant, 5)
	return [MHPalette.drift(MHPalette.STONE_DARK, n, 0.1), MHPalette.drift(MHPalette.STONE_LIGHT, n, 0.06)]


## Single boulder. LOD0 48 tris (8 sides, 4 stacks), LOD1 24, LOD2 10.
static func _rock(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var cols: Array = _rock_colors(variant)
	var lo: Color = cols[0] as Color
	var hi: Color = cols[1] as Color
	var rng: MHArtRng = _rng(6, lod, variant)
	var rx: float = 0.55 + rng.range_f(0.0, 0.25)
	var ry: float = 0.38 + rng.range_f(0.0, 0.2)
	var rz: float = 0.5 + rng.range_f(0.0, 0.25)
	var c: Vector3 = Vector3(0.0, ry * 0.6, 0.0)
	if lod == 0:
		b.blob(c, Vector3(rx, ry, rz), 4, 8, lo, hi, variant + 101, 0.28)
	elif lod == 1:
		b.blob(c, Vector3(rx, ry, rz), 3, 6, lo, hi, variant + 101, 0.25)
	else:
		b.blob(c, Vector3(rx, ry, rz), 2, 5, lo, hi, variant + 101, 0.2)


## Three rocks of different sizes. LOD0 100 tris, LOD1 34, LOD2 10.
static func _rock_cluster(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var cols: Array = _rock_colors(variant + 3)
	var lo: Color = cols[0] as Color
	var hi: Color = cols[1] as Color
	var rng: MHArtRng = _rng(7, lod, variant)
	var ja: float = rng.range_f(-0.2, 0.2)
	if lod == 0:
		b.blob(Vector3(0.0, 0.42, 0.0), Vector3(0.8, 0.55, 0.7), 4, 8, lo, hi, variant + 111, 0.28)
		b.blob(Vector3(1.0 + ja, 0.25, 0.3), Vector3(0.5, 0.32, 0.45), 3, 7, lo, hi, variant + 112, 0.25)
		b.blob(Vector3(-0.7, 0.2, 0.7 + ja), Vector3(0.4, 0.26, 0.4), 3, 6, lo, hi, variant + 113, 0.25)
	elif lod == 1:
		b.blob(Vector3(0.0, 0.42, 0.0), Vector3(0.8, 0.55, 0.7), 3, 6, lo, hi, variant + 111, 0.25)
		b.blob(Vector3(1.0 + ja, 0.25, 0.3), Vector3(0.5, 0.32, 0.45), 2, 5, lo, hi, variant + 112, 0.2)
	else:
		b.blob(Vector3(0.2, 0.4, 0.1), Vector3(1.2, 0.55, 0.9), 2, 5, lo, hi, variant + 111, 0.2)


# ---------------------------------------------------------------- ground cover

## Patch of flowers on thin stems. LOD0 8 flowers x 7 tris = 56.
static func _flowers(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var rng: MHArtRng = _rng(8, lod, variant)
	var count: int = 8
	var head_sides: int = 5
	if lod == 1:
		count = 4
		head_sides = 4
	elif lod == 2:
		count = 3
		head_sides = 3
	var stem_lo: Color = MHPalette.GRASS_DARK
	var stem_hi: Color = MHPalette.GRASS
	for i in range(count):
		var a: float = rng.range_f(0.0, TAU)
		var r: float = 0.05 + rng.range_f(0.0, 0.45)
		var base: Vector3 = Vector3(cos(a) * r, 0.0, sin(a) * r)
		var h: float = 0.28 + rng.range_f(0.0, 0.2)
		var head: Color = MHPalette.pick(MHPalette.FLOWERS, variant + i * (1 + variant % 2))
		if lod < 2:
			_blade(b, base, rng.range_f(0.0, PI), 0.04, h, 0.04, stem_lo, stem_hi)
		b.set_xf(Transform3D(Basis(), base + Vector3(0.0, h, 0.0)))
		b.frustum(0.0, 0.05, 0.10, 0.0, head_sides, head.lerp(Color(1, 1, 1), 0.25), head, false, false)
		b.reset_xf()


## Reed clump: 10 bent blades. LOD0 60 tris.
static func _reeds(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var rng: MHArtRng = _rng(9, lod, variant)
	var count: int = 10
	if lod == 1:
		count = 6
	elif lod == 2:
		count = 3
	for i in range(count):
		var a: float = rng.range_f(0.0, TAU)
		var r: float = rng.range_f(0.0, 0.3)
		var base: Vector3 = Vector3(cos(a) * r, 0.0, sin(a) * r)
		var h: float = 1.3 + rng.range_f(0.0, 0.6)
		var lean: float = rng.range_f(0.1, 0.5)
		var yaw: float = a + rng.range_f(-0.5, 0.5)
		if lod == 0:
			_bent_blade(b, base, yaw, lean, h, 0.07, MHPalette.REED, MHPalette.REED_TIP)
		else:
			_blade(b, base, yaw, lean, h, 0.07, MHPalette.REED, MHPalette.REED_TIP)


## Cattails: brown-headed stalks plus leaf blades. LOD0 about 135 tris.
static func _cattails(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var rng: MHArtRng = _rng(10, lod, variant)
	var stalks: int = 5
	var blades: int = 5
	if lod == 1:
		stalks = 3
		blades = 3
	elif lod == 2:
		stalks = 3
		blades = 0
	for i in range(stalks):
		var a: float = rng.range_f(0.0, TAU)
		var r: float = rng.range_f(0.0, 0.3)
		var base: Vector3 = Vector3(cos(a) * r, 0.0, sin(a) * r)
		var h: float = 1.2 + rng.range_f(0.0, 0.4)
		var tip: Vector3 = base + Vector3(rng.range_f(-0.08, 0.08), h, rng.range_f(-0.08, 0.08))
		if lod == 0:
			b.tube(base, tip, 0.022, 0.014, 3, MHPalette.REED, MHPalette.REED)
			var head_base: Vector3 = tip - Vector3(0.0, 0.32, 0.0)
			b.tube(head_base, tip, 0.05, 0.032, 5, MHPalette.CATTAIL_HEAD, MHPalette.CATTAIL_HEAD, false, true)
		elif lod == 1:
			b.tube(base, tip, 0.022, 0.014, 3, MHPalette.REED, MHPalette.REED)
			b.tube(tip - Vector3(0.0, 0.3, 0.0), tip, 0.05, 0.03, 4, MHPalette.CATTAIL_HEAD, MHPalette.CATTAIL_HEAD)
		else:
			b.tri_two_sided(base + Vector3(-0.05, 0.0, 0.0), base + Vector3(0.05, 0.0, 0.0), tip,
				MHPalette.REED, MHPalette.REED, MHPalette.CATTAIL_HEAD)
	for i in range(blades):
		var a2: float = rng.range_f(0.0, TAU)
		var r2: float = rng.range_f(0.0, 0.35)
		var base2: Vector3 = Vector3(cos(a2) * r2, 0.0, sin(a2) * r2)
		var h2: float = 1.0 + rng.range_f(0.0, 0.5)
		if lod == 0:
			_bent_blade(b, base2, a2, rng.range_f(0.1, 0.4), h2, 0.07, MHPalette.REED, MHPalette.REED_TIP)
		else:
			_blade(b, base2, a2, rng.range_f(0.1, 0.4), h2, 0.07, MHPalette.REED, MHPalette.REED_TIP)


## Tall grass clump of 14 leaning blades. LOD0 28 tris.
static func _tall_grass(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var rng: MHArtRng = _rng(11, lod, variant)
	var count: int = 14
	if lod == 1:
		count = 7
	elif lod == 2:
		count = 3
	for i in range(count):
		var a: float = rng.range_f(0.0, TAU)
		var r: float = rng.range_f(0.0, 0.28)
		var base: Vector3 = Vector3(cos(a) * r, 0.0, sin(a) * r)
		var h: float = 0.6 + rng.range_f(0.0, 0.4)
		var lean: float = rng.range_f(0.1, 0.45)
		_blade(b, base, a + rng.range_f(-0.6, 0.6), lean, h, 0.09, MHPalette.TALL_GRASS_LOW, MHPalette.TALL_GRASS_HIGH)

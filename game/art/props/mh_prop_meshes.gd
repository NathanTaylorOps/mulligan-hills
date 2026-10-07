class_name MHPropMeshes
extends RefCounted
## Procedural course props: flag, hole cup, tee marker, bench, golf cart, sign, fence section, golf bag, bin,
## umbrella, golf ball. Built from primitives in code (DEC-062), flat shaded with vertex colours from
## MHPalette, one surface per mesh so a MultiMesh can draw it.
##
## LODs: 0 (near) and 1 (far). Triangle budgets are in BUDGETS (tests/art/test_prop_meshes.gd).
## `variant` (any int, 0..VARIANTS-1 are distinct) changes colour and sometimes shape. Same
## (kind, lod, variant) always gives the same vertices.
##
## Units are metres, origin on the ground. Things with a front (bench, cart, sign) face +Z, the same
## way golfers do. A fence section runs along +X from x = 0 to x = FENCE_LENGTH, so sections tile
## by stepping FENCE_LENGTH along X.

const KIND_FLAG: String = "flag"
const KIND_CUP: String = "hole_cup"
const KIND_TEE: String = "tee_marker"
const KIND_BENCH: String = "bench"
const KIND_CART: String = "cart"
const KIND_SIGN: String = "sign"
const KIND_FENCE: String = "fence"
const KIND_BAG: String = "golf_bag"
const KIND_BIN: String = "bin"
const KIND_UMBRELLA: String = "umbrella"
const KIND_BALL: String = "golf_ball"

const KINDS: Array = ["flag", "hole_cup", "tee_marker", "bench", "cart", "sign", "fence", "golf_bag", "bin",
	"umbrella", "golf_ball"]
const VARIANTS: int = 4
const LOD_COUNT: int = 2
const FENCE_LENGTH: float = 2.0

## Centre and size of the printable face of the sign (front, +Z side), for a Label3D.
const SIGN_FACE_CENTER: Vector3 = Vector3(0.0, 1.25, 0.03)
const SIGN_FACE_SIZE: Vector2 = Vector2(0.68, 0.44)

## Maximum triangles per kind, indexed by LOD. Actual counts are lower.
const BUDGETS: Dictionary = {
	"flag": [40, 14],
	"hole_cup": [28, 8],
	"tee_marker": [40, 20],
	"bench": [180, 56],
	"cart": [380, 100],
	"sign": [60, 28],
	"fence": [120, 40],
	"golf_bag": [60, 28],
	"bin": [48, 20],
	"umbrella": [28, 22],
	"golf_ball": [14, 10],
}

## Rough height in metres (for galleries and placement).
const HEIGHTS: Dictionary = {
	"flag": 2.2, "hole_cup": 0.02, "tee_marker": 0.25, "bench": 0.95, "cart": 1.95, "sign": 1.5,
	"fence": 0.95, "golf_bag": 1.15, "bin": 0.76, "umbrella": 2.65, "golf_ball": 0.1,
}


static func is_known(kind: String) -> bool:
	return KINDS.has(kind)


static func budget(kind: String, lod: int) -> int:
	var arr: Array = BUDGETS[kind]
	return int(arr[clampi(lod, 0, LOD_COUNT - 1)])


static func height_of(kind: String) -> float:
	return float(HEIGHTS[kind])


static func build(kind: String, lod: int, variant: int) -> ArrayMesh:
	return build_builder(kind, lod, variant).to_mesh()


static func build_builder(kind: String, lod: int, variant: int) -> MHMeshBuilder:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	var l: int = clampi(lod, 0, LOD_COUNT - 1)
	var v: int = ((variant % 1024) + 1024) % 1024
	match kind:
		"flag":
			_flag(b, l, v)
		"hole_cup":
			_cup(b, l, v)
		"tee_marker":
			_tee(b, l, v)
		"bench":
			_bench(b, l, v)
		"cart":
			_cart(b, l, v)
		"sign":
			_sign(b, l, v)
		"fence":
			_fence(b, l, v)
		"golf_bag":
			_bag(b, l, v)
		"bin":
			_bin(b, l, v)
		"umbrella":
			_umbrella(b, l, v)
		"golf_ball":
			_ball(b, l, v)
	return b


# ---------------------------------------------------------------- pieces

## Flag on a pole. LOD0 29 tris, LOD1 8.
static func _flag(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var cols: Array = [MHPalette.FLAG_RED, MHPalette.FLAG_YELLOW, MHPalette.FLAG_WHITE, MHPalette.TEE_BLUE]
	var c: Color = MHPalette.pick(cols, variant)
	var c_far: Color = c.lerp(Color(1.0, 1.0, 1.0), 0.18)
	var c_near: Color = MHPalette.shade(c, 0.85)
	if lod == 0:
		b.tube(Vector3.ZERO, Vector3(0.0, 2.1, 0.0), 0.014, 0.010, 4, MHPalette.METAL, MHPalette.METAL)
		b.tube(Vector3.ZERO, Vector3(0.0, 0.10, 0.0), 0.035, 0.022, 5, MHPalette.METAL_DARK, MHPalette.METAL_DARK)
		b.set_xf(Transform3D(Basis(), Vector3(0.0, 2.1, 0.0)))
		b.frustum(0.0, 0.06, 0.028, 0.0, 5, MHPalette.FLAG_YELLOW, MHPalette.FLAG_YELLOW, false, false)
		b.reset_xf()
		b.quad_two_sided(Vector3(0.014, 2.08, 0.0), Vector3(0.30, 2.08, 0.05), Vector3(0.30, 1.86, 0.05),
			Vector3(0.014, 1.86, 0.0), c_near, c)
		b.tri_two_sided(Vector3(0.30, 2.08, 0.05), Vector3(0.58, 1.97, -0.02), Vector3(0.30, 1.86, 0.05), c, c_far, c)
	else:
		b.tube(Vector3.ZERO, Vector3(0.0, 2.1, 0.0), 0.016, 0.012, 3, MHPalette.METAL, MHPalette.METAL)
		b.tri_two_sided(Vector3(0.014, 2.08, 0.0), Vector3(0.58, 1.97, 0.0), Vector3(0.014, 1.86, 0.0), c_near, c_far, c_near)


## Hole cup seen from above: dark disc with a pale ring. LOD0 8 + 16 = 24 tris, LOD1 6.
static func _cup(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var rims: Array = [MHPalette.CUP_RIM, MHPalette.FLAG_WHITE, MHPalette.SAND, MHPalette.PATH_STONE]
	var rim: Color = MHPalette.pick(rims, variant)
	if lod == 0:
		b.disc(Vector3(0.0, 0.012, 0.0), 0.10, 8, MHPalette.CUP_DARK, true)
		var down: Vector3 = Vector3(0.0, -1.0, 0.0)
		for i in range(8):
			var a0: Vector3 = MHMeshBuilder.ring_point(0.10, 0.008, 8, i)
			var a1: Vector3 = MHMeshBuilder.ring_point(0.10, 0.008, 8, i + 1)
			var b0: Vector3 = MHMeshBuilder.ring_point(0.145, 0.008, 8, i)
			var b1: Vector3 = MHMeshBuilder.ring_point(0.145, 0.008, 8, i + 1)
			b.quad(a0, a1, b1, b0, rim, down)
	else:
		b.disc(Vector3(0.0, 0.012, 0.0), 0.12, 6, MHPalette.CUP_DARK, true)


## Tee marker: peg and ball in one of the tee colours. LOD0 34 tris, LOD1 16.
static func _tee(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var cols: Array = [MHPalette.TEE_WHITE, MHPalette.TEE_YELLOW, MHPalette.TEE_BLUE, MHPalette.TEE_RED]
	var c: Color = MHPalette.pick(cols, variant)
	var peg: Color = MHPalette.shade(c, 0.7)
	if lod == 0:
		b.frustum(0.0, 0.10, 0.03, 0.02, 5, peg, peg, false, false)
		b.blob(Vector3(0.0, 0.16, 0.0), Vector3(0.08, 0.08, 0.08), 3, 6, peg, c, variant + 301, 0.04)
	else:
		b.frustum(0.0, 0.10, 0.03, 0.02, 3, peg, peg, false, false)
		b.blob(Vector3(0.0, 0.15, 0.0), Vector3(0.08, 0.08, 0.08), 2, 5, peg, c, variant + 301, 0.04)


## Park bench facing +Z. LOD0 108 tris, LOD1 48.
static func _bench(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var seats: Array = [MHPalette.WOOD_LIGHT, MHPalette.SIGN_GREEN, MHPalette.WOOD_DARK, MHPalette.CANVAS_WHITE]
	var seat: Color = MHPalette.pick(seats, variant)
	var seat_dark: Color = MHPalette.shade(seat, 0.8)
	var frame: Color = MHPalette.WOOD_DARK
	if variant % 2 == 1:
		frame = MHPalette.METAL_DARK
	if lod == 0:
		for i in range(3):
			var z: float = -0.15 + 0.15 * float(i)
			b.box(Vector3(0.0, 0.45, z), Vector3(1.6, 0.04, 0.13), seat, seat, seat_dark)
		b.box(Vector3(0.0, 0.70, -0.23), Vector3(1.6, 0.12, 0.03), seat, seat, seat_dark)
		b.box(Vector3(0.0, 0.86, -0.23), Vector3(1.6, 0.12, 0.03), seat, seat, seat_dark)
		# Arm rests give the near silhouette the resort-furniture character visible
		# in the richer references while the far LOD stays unchanged.
		for ax in [-0.68, 0.68]:
			b.box(Vector3(float(ax), 0.62, 0.03), Vector3(0.06, 0.06, 0.46), frame, frame, frame)
			b.box(Vector3(float(ax), 0.52, -0.16), Vector3(0.05, 0.24, 0.05), frame, frame, frame)
		for sx in [-0.72, 0.72]:
			var x: float = float(sx)
			b.box(Vector3(x, 0.225, 0.0), Vector3(0.06, 0.45, 0.46), frame, frame, frame)
			b.box(Vector3(x, 0.70, -0.23), Vector3(0.05, 0.50, 0.05), frame, frame, frame)
	else:
		b.box(Vector3(0.0, 0.45, 0.0), Vector3(1.6, 0.06, 0.46), seat, seat, seat_dark)
		b.box(Vector3(0.0, 0.78, -0.23), Vector3(1.6, 0.34, 0.04), seat, seat, seat_dark)
		for sx in [-0.72, 0.72]:
			var x1: float = float(sx)
			b.box(Vector3(x1, 0.225, 0.0), Vector3(0.06, 0.45, 0.46), frame, frame, frame)


## Golf cart facing +Z (2.3 m long, 1.2 m wide). LOD0 about 208 tris, LOD1 92.
static func _cart(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var body: Color = MHPalette.CART_BODY
	if variant > 0:
		body = MHPalette.pick(MHPalette.UMBRELLA_COLORS, variant - 1)
	var body_dark: Color = MHPalette.shade(body, 0.82)
	var seat: Color = MHPalette.CART_ACCENT
	var roof: Color = MHPalette.shade(body, 1.0)
	var rubber: Color = MHPalette.RUBBER
	var metal: Color = MHPalette.METAL
	if lod == 0:
		b.box(Vector3(0.0, 0.36, 0.0), Vector3(1.15, 0.14, 2.3), body, body_dark, MHPalette.METAL_DARK)
		b.box(Vector3(0.0, 0.52, -0.45), Vector3(1.1, 0.24, 0.9), body, body_dark, body_dark)
		b.box(Vector3(0.0, 0.50, 0.85), Vector3(1.1, 0.30, 0.55), body, body_dark, body_dark)
		b.box(Vector3(0.0, 0.70, -0.45), Vector3(1.0, 0.12, 0.55), seat, seat, seat)
		b.box(Vector3(0.0, 0.98, -0.78), Vector3(1.0, 0.45, 0.10), seat, seat, seat)
		# Steering wheel, dashboard and rear bag well are cheap hero details that
		# make parked/celebrity carts read as vehicles rather than coloured boxes.
		b.box(Vector3(0.0, 0.88, 0.43), Vector3(0.82, 0.12, 0.08), body_dark, body_dark, body_dark)
		b.tube(Vector3(0.0, 0.80, 0.42), Vector3(0.0, 1.04, 0.28), 0.022, 0.018, 5, metal, metal)
		b.set_xf(Transform3D(Basis(Vector3(1.0, 0.0, 0.0), PI * 0.5), Vector3(0.0, 1.05, 0.26)))
		b.frustum(-0.025, 0.025, 0.16, 0.16, 8, rubber, rubber, false, false)
		b.reset_xf()
		b.box(Vector3(0.0, 0.58, -1.02), Vector3(0.82, 0.32, 0.08), MHPalette.METAL_DARK, MHPalette.METAL_DARK, MHPalette.METAL_DARK)
		b.tube(Vector3(0.0, 0.62, 0.55), Vector3(0.0, 0.92, 0.38), 0.025, 0.025, 4, MHPalette.METAL_DARK, MHPalette.METAL_DARK)
		b.box(Vector3(0.0, 1.92, 0.05), Vector3(1.2, 0.06, 1.7), roof, roof, body_dark)
		for px in [-0.52, 0.52]:
			for pz in [-0.70, 0.70]:
				b.tube(Vector3(float(px), 0.50, float(pz)), Vector3(float(px), 1.90, float(pz)), 0.025, 0.025, 4, metal, metal)
		for wx in [-0.62, 0.62]:
			for wz in [-0.75, 0.75]:
				b.set_xf(Transform3D(Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5), Vector3(float(wx), 0.22, float(wz))))
				b.frustum(-0.07, 0.07, 0.22, 0.22, 6, rubber, rubber, true, true)
				b.reset_xf()
	else:
		b.box(Vector3(0.0, 0.36, 0.0), Vector3(1.15, 0.14, 2.3), body, body_dark, MHPalette.METAL_DARK)
		b.box(Vector3(0.0, 0.62, -0.1), Vector3(1.1, 0.40, 1.9), body, body_dark, body_dark)
		b.box(Vector3(0.0, 1.92, 0.05), Vector3(1.2, 0.06, 1.7), roof, roof, body_dark)
		for px in [-0.52, 0.52]:
			for pz in [-0.70, 0.70]:
				b.tube(Vector3(float(px), 0.50, float(pz)), Vector3(float(px), 1.90, float(pz)), 0.03, 0.03, 3, metal, metal)
		for wx in [-0.62, 0.62]:
			for wz in [-0.75, 0.75]:
				b.set_xf(Transform3D(Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5), Vector3(float(wx), 0.22, float(wz))))
				b.frustum(-0.07, 0.07, 0.22, 0.22, 4, rubber, rubber, false, false)
				b.reset_xf()


## Sign on a post, readable from +Z and -Z. LOD0 28 tris, LOD1 24.
static func _sign(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var borders: Array = [MHPalette.SIGN_GREEN, MHPalette.WOOD_DARK, MHPalette.TEE_BLUE, MHPalette.FLAG_RED]
	var faces: Array = [MHPalette.SIGN_CREAM, MHPalette.SIGN_CREAM, MHPalette.FLAG_WHITE, MHPalette.FLAG_WHITE]
	var border: Color = MHPalette.pick(borders, variant)
	var face: Color = MHPalette.pick(faces, variant)
	var post: Color = MHPalette.WOOD_DARK
	b.box(Vector3(0.0, 0.6, 0.0), Vector3(0.07, 1.2, 0.07), post, post, post)
	b.box(Vector3(0.0, 1.25, 0.0), Vector3(0.80, 0.50, 0.05), border, border, border)
	if lod == 0:
		var hx: float = SIGN_FACE_SIZE.x * 0.5
		var hy: float = SIGN_FACE_SIZE.y * 0.5
		var cy: float = SIGN_FACE_CENTER.y
		var centre: Vector3 = Vector3(0.0, cy, 0.0)
		var zf: float = SIGN_FACE_CENTER.z
		b.quad(Vector3(-hx, cy + hy, zf), Vector3(hx, cy + hy, zf), Vector3(hx, cy - hy, zf), Vector3(-hx, cy - hy, zf), face, centre)
		b.quad(Vector3(-hx, cy + hy, -zf), Vector3(hx, cy + hy, -zf), Vector3(hx, cy - hy, -zf), Vector3(-hx, cy - hy, -zf), face, centre)


## One fence section from x = 0 to x = FENCE_LENGTH. Variants: 0 post and rail, 1 picket, 2 post and rope,
## 3 low stone wall. LOD0 24 to 108 tris, LOD1 12 to 36.
static func _fence(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var kind: int = variant % 4
	var wood: Color = MHPalette.WOOD_LIGHT
	var wood_dark: Color = MHPalette.WOOD_DARK
	var flen: float = FENCE_LENGTH
	if kind == 3:
		var s: Color = MHPalette.STONE_LIGHT
		var sd: Color = MHPalette.STONE_DARK
		b.box(Vector3(flen * 0.5, 0.25, 0.0), Vector3(flen, 0.50, 0.30), s, sd, sd)
		if lod == 0:
			b.box(Vector3(flen * 0.5, 0.54, 0.0), Vector3(flen + 0.05, 0.08, 0.34), s, s, sd)
		return
	var post_h: float = 0.95
	var post_w: float = 0.09
	if kind == 2:
		post_h = 1.0
		post_w = 0.10
		wood = MHPalette.PALM_BARK
	for px in [0.0, flen]:
		b.box(Vector3(float(px), post_h * 0.5, 0.0), Vector3(post_w, post_h, post_w), wood, wood_dark, wood_dark)
	if kind == 0:
		b.box(Vector3(flen * 0.5, 0.75, 0.0), Vector3(flen, 0.07, 0.04), wood, wood, wood_dark)
		if lod == 0:
			b.box(Vector3(flen * 0.5, 0.45, 0.0), Vector3(flen, 0.07, 0.04), wood, wood, wood_dark)
	elif kind == 1:
		if lod == 0:
			b.box(Vector3(flen * 0.5, 0.35, 0.0), Vector3(flen, 0.06, 0.04), wood_dark, wood_dark, wood_dark)
			for i in range(6):
				var x: float = 0.17 + float(i) * 0.33
				b.box(Vector3(x, 0.40, 0.04), Vector3(0.07, 0.80, 0.03), MHPalette.FLAG_WHITE, MHPalette.FLAG_WHITE, MHPalette.SAND_SHADE)
		else:
			b.box(Vector3(flen * 0.5, 0.40, 0.03), Vector3(flen, 0.70, 0.03), MHPalette.FLAG_WHITE, MHPalette.FLAG_WHITE, MHPalette.SAND_SHADE)
	else:
		var rope: Color = MHPalette.SAND_SHADE
		if lod == 0:
			b.tube(Vector3(0.0, 0.86, 0.0), Vector3(flen * 0.5, 0.74, 0.0), 0.02, 0.02, 3, rope, rope)
			b.tube(Vector3(flen * 0.5, 0.74, 0.0), Vector3(flen, 0.86, 0.0), 0.02, 0.02, 3, rope, rope)
		else:
			b.tube(Vector3(0.0, 0.80, 0.0), Vector3(flen, 0.80, 0.0), 0.02, 0.02, 3, rope, rope)


## Golf bag standing upright, three clubs poking out. LOD0 54 tris, LOD1 22.
static func _bag(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var c: Color = MHPalette.pick(MHPalette.OUTFIT_COLORS, variant)
	var c_dark: Color = MHPalette.shade(c, 0.75)
	var metal: Color = MHPalette.METAL
	if lod == 0:
		b.frustum(0.0, 0.85, 0.13, 0.11, 6, c_dark, c, true, true)
		b.box(Vector3(0.0, 0.40, 0.13), Vector3(0.18, 0.30, 0.08), c_dark, c_dark, c_dark)
		b.tube(Vector3(-0.04, 0.80, 0.0), Vector3(-0.06, 1.12, 0.02), 0.012, 0.010, 3, metal, metal)
		b.tube(Vector3(0.03, 0.80, -0.02), Vector3(0.05, 1.15, -0.03), 0.012, 0.010, 3, metal, metal)
		b.tube(Vector3(0.0, 0.80, 0.04), Vector3(0.01, 1.08, 0.07), 0.012, 0.010, 3, metal, metal)
	else:
		b.frustum(0.0, 0.85, 0.13, 0.11, 4, c_dark, c, true, true)
		b.tube(Vector3(0.0, 0.80, 0.0), Vector3(0.0, 1.12, 0.02), 0.014, 0.010, 3, metal, metal)


## Litter bin. LOD0 42 tris, LOD1 16.
static func _bin(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var cols: Array = [MHPalette.SIGN_GREEN, MHPalette.METAL_DARK, MHPalette.WOOD_DARK, MHPalette.METAL]
	var c: Color = MHPalette.pick(cols, variant)
	var c_dark: Color = MHPalette.shade(c, 0.75)
	if lod == 0:
		b.frustum(0.0, 0.70, 0.22, 0.26, 6, c_dark, c, true, true)
		b.frustum(0.70, 0.76, 0.27, 0.27, 6, MHPalette.METAL_DARK, MHPalette.METAL_DARK, false, true)
	else:
		b.frustum(0.0, 0.76, 0.22, 0.26, 4, c_dark, c, true, true)


## Beach-style umbrella, open canopy of eight panels. LOD0 24 tris, LOD1 18.
static func _umbrella(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var c: Color = MHPalette.pick(MHPalette.UMBRELLA_COLORS, variant)
	var white: Color = MHPalette.FLAG_WHITE
	var apex: Vector3 = Vector3(0.0, 2.65, 0.0)
	var panels: int = 8
	var pole_sides: int = 4
	if lod == 1:
		panels = 6
		pole_sides = 3
	b.tube(Vector3.ZERO, Vector3(0.0, 2.3, 0.0), 0.025, 0.02, pole_sides, MHPalette.METAL, MHPalette.METAL)
	for i in range(panels):
		var p0: Vector3 = MHMeshBuilder.ring_point(1.4, 2.2, panels, i)
		var p1: Vector3 = MHMeshBuilder.ring_point(1.4, 2.2, panels, i + 1)
		var col: Color = c
		if i % 2 == 1:
			col = white
		b.tri_two_sided(apex, p0, p1, col, MHPalette.shade(col, 0.9), MHPalette.shade(col, 0.9))


## Golf ball. LOD0 12 tris, LOD1 8.
static func _ball(b: MHMeshBuilder, lod: int, variant: int) -> void:
	var cols: Array = [MHPalette.BALL_WHITE, MHPalette.FLAG_YELLOW, Color(0.98, 0.58, 0.20), Color(0.95, 0.42, 0.55)]
	var c: Color = MHPalette.pick(cols, variant)
	var shadow: Color = MHPalette.shade(c, 0.82)
	if lod == 0:
		b.blob(Vector3(0.0, 0.05, 0.0), Vector3(0.05, 0.05, 0.05), 2, 6, shadow, c, 401, 0.0)
	else:
		b.blob(Vector3(0.0, 0.05, 0.0), Vector3(0.05, 0.05, 0.05), 2, 4, shadow, c, 401, 0.0)

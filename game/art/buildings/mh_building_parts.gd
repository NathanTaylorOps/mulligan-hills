class_name MHBuildingParts
extends RefCounted
## Reusable building parts on top of MHMeshBuilder. Every part is built in a local frame (origin on the
## ground, +Y up, front = +Z) and is flat shaded with vertex colours. No part draws a face that can never
## be seen (no undersides, no roof caps hidden by walls). Triangle cost of each part is in its comment so
## the budgets in MHBuildingMeshes can be checked by hand.
##
## Yaw: rotating by +90 degrees about Y turns local +Z into world +X.

const ROOF_GABLE: int = 0
const ROOF_HIP: int = 1
const ROOF_FLAT: int = 2
const NO_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)


## Value for a 1-based tier from a 5-entry array.
static func at(arr: Array, tier: int) -> float:
	return float(arr[clampi(tier, 1, 5) - 1])


static func at_i(arr: Array, tier: int) -> int:
	return int(arr[clampi(tier, 1, 5) - 1])


## Moves the builder frame by `pos` and `yaw`. Returns the previous frame; give it back to `pop`.
static func push(b: MHMeshBuilder, pos: Vector3, yaw: float) -> Transform3D:
	var saved: Transform3D = b.xf
	b.xf = saved * Transform3D(Basis(Vector3.UP, yaw), pos)
	return saved


static func pop(b: MHMeshBuilder, saved: Transform3D) -> void:
	b.xf = saved


## Quad a,b (bottom edge) c,d (top edge) with a vertical colour gradient. 2 triangles.
static func gquad(b: MHMeshBuilder, a: Vector3, bb: Vector3, c: Vector3, d: Vector3,
		col_bottom: Color, col_top: Color, outward: Vector3) -> void:
	b.tri(a, bb, c, col_bottom, col_bottom, col_top, outward)
	b.tri(a, c, d, col_bottom, col_top, col_top, outward)


## Four walls, no top and no bottom. `base` is the centre of the bottom. 8 triangles.
static func walls(b: MHMeshBuilder, base: Vector3, size: Vector3, col: Color) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var c: Vector3 = base + Vector3(0.0, size.y * 0.5, 0.0)
	var lo: Color = MHPalette.shade(col, 0.86)
	var y0: float = base.y
	var y1: float = base.y + size.y
	var x0: float = base.x - hx
	var x1: float = base.x + hx
	var z0: float = base.z - hz
	var z1: float = base.z + hz
	gquad(b, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), lo, col, c)
	gquad(b, Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), lo, col, c)
	gquad(b, Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), lo, col, c)
	gquad(b, Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), lo, col, c)


## Box without a bottom face. `base` is the centre of the bottom. 10 triangles.
static func slab(b: MHMeshBuilder, base: Vector3, size: Vector3, top: Color, side: Color) -> void:
	walls(b, base, size, side)
	var c: Vector3 = base + Vector3(0.0, size.y * 0.5, 0.0)
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var y1: float = base.y + size.y
	b.quad(Vector3(base.x - hx, y1, base.z - hz), Vector3(base.x + hx, y1, base.z - hz),
		Vector3(base.x + hx, y1, base.z + hz), Vector3(base.x - hx, y1, base.z + hz), top, c)


## Flat quad lying on the ground (a mat, a path, a water surface). 2 triangles.
static func flat(b: MHMeshBuilder, centre: Vector3, sx: float, sz: float, col: Color) -> void:
	var hx: float = sx * 0.5
	var hz: float = sz * 0.5
	b.quad(centre + Vector3(-hx, 0.0, -hz), centre + Vector3(hx, 0.0, -hz),
		centre + Vector3(hx, 0.0, hz), centre + Vector3(-hx, 0.0, hz), col, centre + Vector3(0.0, -1.0, 0.0))


## Gable roof, ridge along local X, centred on `base` (the eave height). 6 triangles.
static func gable(b: MHMeshBuilder, base: Vector3, w: float, d: float, rise: float, over: float,
		roof: Color, end_col: Color) -> void:
	var x: float = w * 0.5 + over
	var z: float = d * 0.5 + over
	var e_lo: Color = MHPalette.shade(roof, 0.88)
	var fl: Vector3 = base + Vector3(-x, 0.0, z)
	var fr: Vector3 = base + Vector3(x, 0.0, z)
	var bl: Vector3 = base + Vector3(-x, 0.0, -z)
	var br: Vector3 = base + Vector3(x, 0.0, -z)
	var rl: Vector3 = base + Vector3(-x, rise, 0.0)
	var rr: Vector3 = base + Vector3(x, rise, 0.0)
	var inside: Vector3 = base + Vector3(0.0, rise * 0.3, 0.0)
	gquad(b, fl, fr, rr, rl, e_lo, roof, inside)
	gquad(b, br, bl, rl, rr, e_lo, roof, inside)
	var ex: float = w * 0.5
	b.tri(base + Vector3(-ex, 0.0, -d * 0.5), base + Vector3(-ex, 0.0, d * 0.5), rl + Vector3(x - ex, 0.0, 0.0),
		end_col, end_col, end_col, inside)
	b.tri(base + Vector3(ex, 0.0, d * 0.5), base + Vector3(ex, 0.0, -d * 0.5), rr + Vector3(ex - x, 0.0, 0.0),
		end_col, end_col, end_col, inside)


## Hip roof (top rectangle is `tr` times the base rectangle; 0 gives a pyramid). 8 triangles, plus 2 for
## the flat top when tr > 0.01 (pyramid: 4 triangles).
static func hip(b: MHMeshBuilder, base: Vector3, w: float, d: float, rise: float, over: float,
		tr: float, roof: Color) -> void:
	var x: float = w * 0.5 + over
	var z: float = d * 0.5 + over
	var tx: float = w * 0.5 * tr
	var tz: float = d * 0.5 * tr
	var e_lo: Color = MHPalette.shade(roof, 0.88)
	var a: Vector3 = base + Vector3(-x, 0.0, z)
	var bb: Vector3 = base + Vector3(x, 0.0, z)
	var c: Vector3 = base + Vector3(x, 0.0, -z)
	var dd: Vector3 = base + Vector3(-x, 0.0, -z)
	var ta: Vector3 = base + Vector3(-tx, rise, tz)
	var tb: Vector3 = base + Vector3(tx, rise, tz)
	var tc: Vector3 = base + Vector3(tx, rise, -tz)
	var td: Vector3 = base + Vector3(-tx, rise, -tz)
	var inside: Vector3 = base + Vector3(0.0, rise * 0.2, 0.0)
	gquad(b, a, bb, tb, ta, e_lo, roof, inside)
	gquad(b, bb, c, tc, tb, e_lo, roof, inside)
	gquad(b, c, dd, td, tc, e_lo, roof, inside)
	gquad(b, dd, a, ta, td, e_lo, roof, inside)
	if tr > 0.01:
		b.quad(ta, tb, tc, td, roof, base + Vector3(0.0, -1.0, 0.0))


## One-slope roof rising toward -Z: low edge at the front (y = base.y), high edge at the back.
## 4 triangles (slope and two side triangles).
static func shed(b: MHMeshBuilder, base: Vector3, w: float, d: float, rise: float, roof: Color) -> void:
	var x: float = w * 0.5
	var z: float = d * 0.5
	var lo: Color = MHPalette.shade(roof, 0.88)
	var fl: Vector3 = base + Vector3(-x, 0.0, z)
	var fr: Vector3 = base + Vector3(x, 0.0, z)
	var bl: Vector3 = base + Vector3(-x, rise, -z)
	var br: Vector3 = base + Vector3(x, rise, -z)
	var inside: Vector3 = base + Vector3(0.0, -1.0, 0.0)
	gquad(b, fl, fr, br, bl, lo, roof, inside)
	b.tri(fl, bl, base + Vector3(-x, 0.0, -z), lo, roof, lo, base + Vector3(x, rise * 0.5, 0.0))
	b.tri(fr, base + Vector3(x, 0.0, -z), br, lo, lo, roof, base + Vector3(-x, rise * 0.5, 0.0))


## Windows on a vertical plane at depth `z`, facing local +Z when sign > 0 and -Z when sign < 0.
## `n` windows centred on x = cx, spaced `pitch` apart. Opaque glass, optional trim frame behind each
## (pass NO_COLOR for none). 2 triangles per window, 4 with a frame. skip_centre drops any window within
## 0.45 pitch of the middle (so a door can sit there).
static func windows(b: MHMeshBuilder, cx: float, cy: float, z: float, sign_z: float, n: int, ww: float,
		wh: float, pitch: float, glass: Color, frame: Color, skip_centre: bool) -> void:
	for i in range(n):
		var x: float = cx + (float(i) - float(n - 1) * 0.5) * pitch
		if skip_centre and absf(x - cx) < pitch * 0.45:
			continue
		var out: Vector3 = Vector3(x, cy, z - sign_z)
		if frame.a > 0.5:
			var fw: float = ww * 0.5 + 0.1
			var fh: float = wh * 0.5 + 0.1
			b.quad(Vector3(x - fw, cy - fh, z), Vector3(x + fw, cy - fh, z), Vector3(x + fw, cy + fh, z),
				Vector3(x - fw, cy + fh, z), frame, out)
		var zg: float = z + sign_z * 0.03
		var gw: float = ww * 0.5
		var gh: float = wh * 0.5
		gquad(b, Vector3(x - gw, cy - gh, zg), Vector3(x + gw, cy - gh, zg), Vector3(x + gw, cy + gh, zg),
			Vector3(x - gw, cy + gh, zg), MHPalette.shade(glass, 0.85), glass, out)


## Door on the +Z facade at x = cx. Frame plus leaf. 4 triangles.
static func door(b: MHMeshBuilder, cx: float, z: float, dw: float, dh: float, leaf: Color, frame: Color) -> void:
	var out: Vector3 = Vector3(cx, dh * 0.5, z - 1.0)
	var fw: float = dw * 0.5 + 0.12
	b.quad(Vector3(cx - fw, 0.0, z), Vector3(cx + fw, 0.0, z), Vector3(cx + fw, dh + 0.12, z),
		Vector3(cx - fw, dh + 0.12, z), frame, out)
	var zl: float = z + 0.03
	b.quad(Vector3(cx - dw * 0.5, 0.0, zl), Vector3(cx + dw * 0.5, 0.0, zl), Vector3(cx + dw * 0.5, dh, zl),
		Vector3(cx - dw * 0.5, dh, zl), leaf, out)


## Round column or pole from y0 to y1. 2 * sides triangles.
static func column(b: MHMeshBuilder, x: float, z: float, y0: float, y1: float, r: float, sides: int,
		col: Color) -> void:
	b.tube(Vector3(x, y0, z), Vector3(x, y1, z), r, r * 0.9, sides, MHPalette.shade(col, 0.9), col)


## Row of `n` posts between two ground points plus one two-sided rail at height h (rail = 4 triangles,
## each post 6 triangles). Used for fences, balcony rails and net lines.
static func fence(b: MHMeshBuilder, p0: Vector3, p1: Vector3, n: int, h: float, col: Color) -> void:
	for i in range(n):
		var t: float = 0.0
		if n > 1:
			t = float(i) / float(n - 1)
		var p: Vector3 = p0.lerp(p1, t)
		b.tube(p, p + Vector3(0.0, h, 0.0), 0.06, 0.05, 3, MHPalette.shade(col, 0.9), col)
	var up: Vector3 = Vector3(0.0, h, 0.0)
	var dn: Vector3 = Vector3(0.0, h - 0.12, 0.0)
	b.quad_two_sided(p0 + dn, p1 + dn, p1 + up, p0 + up, col, col)


## Flagpole with a two-sided pennant. Pole 6 triangles (3 sides), pennant 2 (one two-sided triangle) = 8.
static func flagpole(b: MHMeshBuilder, base: Vector3, h: float, col: Color) -> void:
	b.tube(base, base + Vector3(0.0, h, 0.0), 0.07, 0.04, 3, MHPalette.METAL_DARK, MHPalette.METAL)
	b.tri_two_sided(base + Vector3(0.0, h, 0.0), base + Vector3(0.0, h - 0.6, 0.0),
		base + Vector3(0.95, h - 0.3, 0.0), col, col, col)


## Low shrub. 10 triangles.
static func shrub(b: MHMeshBuilder, c: Vector3, r: float, seed_value: int) -> void:
	b.blob(c + Vector3(0.0, r * 0.7, 0.0), Vector3(r, r * 0.8, r), 2, 5, MHPalette.BUSH_LOW,
		MHPalette.BUSH_HIGH, seed_value, 0.15)


## Striped awning sloping out from a wall at +Z. `n` stripes of 2 triangles each, alternating c1/c2.
static func awning(b: MHMeshBuilder, cx: float, y: float, z: float, w: float, depth: float, n: int,
		c1: Color, c2: Color) -> void:
	var sw: float = w / float(n)
	for i in range(n):
		var x0: float = cx - w * 0.5 + sw * float(i)
		var col: Color = c1 if i % 2 == 0 else c2
		b.quad(Vector3(x0, y, z), Vector3(x0 + sw, y, z), Vector3(x0 + sw, y - 0.55, z + depth),
			Vector3(x0, y - 0.55, z + depth), col, Vector3(x0 + sw * 0.5, y - 2.0, z - 1.0))


## Umbrella with pole: hip roof pyramid 4 + pole 6 = 10 triangles.
static func umbrella(b: MHMeshBuilder, base: Vector3, r: float, col: Color) -> void:
	b.tube(base, base + Vector3(0.0, 2.2, 0.0), 0.04, 0.04, 3, MHPalette.METAL_DARK, MHPalette.METAL)
	hip(b, base + Vector3(0.0, 2.1, 0.0), r * 2.0, r * 2.0, 0.45, 0.0, 0.0, col)


## Picnic table: top slab 10 + two bench slabs 20 = 30 triangles.
static func table(b: MHMeshBuilder, base: Vector3, yaw: float, top: Color, bench: Color) -> void:
	var s: Transform3D = push(b, base, yaw)
	slab(b, Vector3(0.0, 0.55, 0.0), Vector3(1.8, 0.08, 0.8), top, top)
	slab(b, Vector3(0.0, 0.3, 0.7), Vector3(1.8, 0.08, 0.3), bench, bench)
	slab(b, Vector3(0.0, 0.3, -0.7), Vector3(1.8, 0.08, 0.3), bench, bench)
	pop(b, s)


## Golf cart: body slab 10, seat back 10, roof slab 10, two posts 12 = 42 triangles. About 1.2 x 2.4 m.
static func cart(b: MHMeshBuilder, base: Vector3, yaw: float, body: Color, accent: Color) -> void:
	var s: Transform3D = push(b, base, yaw)
	slab(b, Vector3(0.0, 0.15, 0.0), Vector3(1.2, 0.55, 2.4), body, body)
	slab(b, Vector3(0.0, 0.7, -0.8), Vector3(1.1, 0.5, 0.2), accent, accent)
	column(b, -0.55, 0.9, 0.7, 1.75, 0.04, 3, MHPalette.METAL)
	column(b, 0.55, 0.9, 0.7, 1.75, 0.04, 3, MHPalette.METAL)
	slab(b, Vector3(0.0, 1.75, 0.1), Vector3(1.3, 0.06, 2.1), accent, accent)
	pop(b, s)


## Solid building block: walls, roof, windows front/back/sides per floor and an optional front door.
## `pos` is the centre of the wall base, `yaw` turns the whole block. `h` is the height of one floor.
## Triangles: walls 8 + roof (gable 6, hip 10, flat 10) + per floor (front 4 per window, back 2 per window,
## sides 4) + door 4.
static func wing(b: MHMeshBuilder, pos: Vector3, yaw: float, w: float, d: float, h: float, floors: int,
		wall: Color, roof: Color, trim: Color, glass: Color, kind: int, rise: float, win_n: int,
		has_door: bool) -> void:
	var s: Transform3D = push(b, pos, yaw)
	var top: float = h * float(floors)
	walls(b, Vector3.ZERO, Vector3(w, top, d), wall)
	var nn: int = maxi(win_n, 1)
	var pitch: float = w / float(nn)
	var ww: float = minf(1.2, pitch * 0.5)
	var wh: float = h * 0.4
	for f in range(floors):
		var cy: float = h * float(f) + h * 0.58
		if win_n > 0:
			windows(b, 0.0, cy, d * 0.5 + 0.03, 1.0, win_n, ww, wh, pitch, glass, trim, has_door and f == 0)
			windows(b, 0.0, cy, -d * 0.5 - 0.03, -1.0, win_n, ww, wh, pitch, glass, NO_COLOR, false)
		var s2: Transform3D = push(b, Vector3.ZERO, PI * 0.5)
		windows(b, 0.0, cy, w * 0.5 + 0.03, 1.0, 1, minf(1.2, d * 0.25), wh, 1.0, glass, NO_COLOR, false)
		pop(b, s2)
		var s3: Transform3D = push(b, Vector3.ZERO, -PI * 0.5)
		windows(b, 0.0, cy, w * 0.5 + 0.03, 1.0, 1, minf(1.2, d * 0.25), wh, 1.0, glass, NO_COLOR, false)
		pop(b, s3)
	if has_door:
		door(b, 0.0, d * 0.5 + 0.03, 1.2, minf(h * 0.72, 2.3), MHPalette.WOOD_DARK, trim)
	var apex: Vector3 = Vector3(0.0, top, 0.0)
	if kind == ROOF_GABLE:
		gable(b, apex, w, d, rise, 0.4, roof, wall)
	elif kind == ROOF_HIP:
		hip(b, apex, w, d, rise, 0.4, 0.35, roof)
	else:
		slab(b, apex, Vector3(w + 0.3, 0.3, d + 0.3), roof, trim)
	pop(b, s)

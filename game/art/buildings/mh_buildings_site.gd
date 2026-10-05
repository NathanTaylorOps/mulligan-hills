class_name MHBuildingsSite
extends MHBuildingParts
## Operations, stay and prestige buildings: cart barn, maintenance, lodging, homes, landmark.
## Same rules as MHBuildingsGolf: each function adds everything up to `tier`, so higher tiers are the
## lower tier plus more and bigger. Origin on the ground, front is +Z.


## Ride-on mower: body slab 10, cutter deck 10, handle 8 = 28 triangles.
static func mower(b: MHMeshBuilder, base: Vector3, yaw: float, body: Color, accent: Color) -> void:
	var s: Transform3D = push(b, base, yaw)
	slab(b, Vector3(0.0, 0.2, -0.2), Vector3(0.8, 0.55, 1.2), body, body)
	slab(b, Vector3(0.0, 0.0, 0.7), Vector3(1.1, 0.25, 0.6), accent, MHPalette.METAL_DARK)
	b.tube(Vector3(0.0, 0.7, -0.7), Vector3(0.0, 1.3, -1.0), 0.04, 0.04, 4, MHPalette.METAL_DARK, MHPalette.METAL)
	pop(b, s)


## Pick-up truck: cab slab 10, bed slab 10, hood slab 10 = 30 triangles.
static func ute(b: MHMeshBuilder, base: Vector3, yaw: float, body: Color) -> void:
	var s: Transform3D = push(b, base, yaw)
	slab(b, Vector3(0.0, 0.2, 0.3), Vector3(1.8, 1.0, 1.4), body, body)
	slab(b, Vector3(0.0, 0.2, -1.2), Vector3(1.8, 0.7, 1.6), MHPalette.shade(body, 0.8), body)
	slab(b, Vector3(0.0, 0.2, 1.4), Vector3(1.8, 0.6, 1.1), body, body)
	pop(b, s)


## Row of solar panels on the front (+Z) slope of a gable roof with eave height `top`, rise `rise`
## and depth `d` (including the 0.4 overhang). 2 triangles per panel.
static func solar_row(b: MHMeshBuilder, top: float, rise: float, d: float, w: float, n: int) -> void:
	var ze: float = d * 0.5 + 0.4
	var slope: Vector3 = Vector3(0.0, rise, -ze)
	var nrm: Vector3 = Vector3(1.0, 0.0, 0.0).cross(slope).normalized() * 0.06
	var pw: float = (w - 0.6) / float(n)
	for i in range(n):
		var x0: float = -w * 0.5 + 0.3 + pw * float(i) + 0.05
		var x1: float = x0 + pw - 0.1
		var e0: Vector3 = Vector3(0.0, top, ze) + slope * 0.2 + nrm
		var e1: Vector3 = Vector3(0.0, top, ze) + slope * 0.8 + nrm
		b.quad(Vector3(x0, e0.y, e0.z), Vector3(x1, e0.y, e0.z), Vector3(x1, e1.y, e1.z),
			Vector3(x0, e1.y, e1.z), MHBuildingTheme.SOLAR, Vector3(0.5 * (x0 + x1), top - 2.0, 0.0))


static func cart_barn(b: MHMeshBuilder, tier: int, spec: int, th: MHBuildingTheme) -> void:
	var w: float = at([6.0, 8.0, 10.0, 13.0, 16.0], tier)
	var d: float = at([5.0, 6.0, 7.0, 8.0, 9.0], tier)
	var h: float = at([3.0, 3.2, 3.4, 3.6, 3.8], tier)
	var rise: float = at([1.4, 1.7, 2.0, 2.2, 2.5], tier)
	var doors: int = at_i([1, 2, 3, 4, 5], tier)
	var carts: int = at_i([1, 3, 4, 6, 8], tier)
	var sx: float = 1.0 if spec == 0 else -1.0
	var top: float = 0.2 + h
	slab(b, Vector3.ZERO, Vector3(w + 0.6, 0.2, d + 0.6), th.base, MHPalette.shade(th.base, 0.85))
	wing(b, Vector3(0.0, 0.2, 0.0), 0.0, w, d, h, 1, th.wall, th.roof, th.trim, th.glass, ROOF_GABLE, rise, 0, false)
	windows(b, 0.0, 1.4, d * 0.5 + 0.03, 1.0, doors, minf(2.4, w / float(doors) * 0.7), 2.5, w / float(doors),
		th.wall_alt, th.trim, false)
	flat(b, Vector3(0.0, 0.03, d * 0.5 + 2.2), w, 3.6, MHPalette.PATH_STONE)
	for i in range(carts):
		var cx: float = (float(i) - float(carts - 1) * 0.5) * 1.7
		cart(b, Vector3(cx, 0.0, d * 0.5 + 2.2), 0.0, MHPalette.CART_BODY, th.accent)
	if tier >= 2:
		slab(b, Vector3(sx * (w * 0.5 + 1.5), 0.0, 0.0), Vector3(3.0, 0.15, d * 0.8), th.base, th.base)
		shed(b, Vector3(sx * (w * 0.5 + 1.5), 2.4, 0.0), 3.0, d * 0.8, 0.6, th.roof)
		column(b, sx * (w * 0.5 + 2.8), d * 0.4 - 0.2, 0.15, 2.4, 0.07, 4, th.trim)
		column(b, sx * (w * 0.5 + 2.8), -d * 0.4 + 0.2, 0.15, 2.4, 0.07, 4, th.trim)
		slab(b, Vector3(-sx * (w * 0.5 + 0.9), 0.0, d * 0.5 + 0.9), Vector3(0.1, 1.4, 0.1), MHPalette.METAL,
			MHPalette.METAL)
		slab(b, Vector3(-sx * (w * 0.5 + 0.9), 1.0, d * 0.5 + 0.9), Vector3(1.4, 0.6, 0.1), th.accent, th.accent)
	if tier >= 3:
		walls(b, Vector3(0.0, top + rise * 0.6, 0.0), Vector3(1.4, 1.0, 1.4), th.wall_alt)
		hip(b, Vector3(0.0, top + rise * 0.6 + 1.0, 0.0), 1.4, 1.4, 0.8, 0.2, 0.0, th.roof)
		b.tube(Vector3(0.0, top + rise * 0.6 + 1.8, 0.0), Vector3(0.0, top + rise * 0.6 + 2.6, 0.0), 0.04,
			0.03, 3, MHPalette.METAL_DARK, MHPalette.METAL)
		slab(b, Vector3(-sx * (w * 0.5 + 2.2), 0.0, -d * 0.2), Vector3(3.6, 0.2, 3.6), th.base,
			MHPalette.shade(th.base, 0.85))
		wing(b, Vector3(-sx * (w * 0.5 + 2.2), 0.2, -d * 0.2), 0.0, 3.2, 3.2, 2.6, 1, th.wall_alt, th.roof,
			th.trim, th.glass, ROOF_GABLE, 1.2, 1, true)
		shrub(b, Vector3(w * 0.5 + 0.8, 0.0, d * 0.5 + 3.8), 0.7, 101)
		shrub(b, Vector3(-w * 0.5 - 0.8, 0.0, d * 0.5 + 3.8), 0.7, 102)
	if tier >= 4:
		solar_row(b, top, rise, d, w, 6)
		for i in range(4):
			var px: float = (float(i) - 1.5) * 1.7
			column(b, px, d * 0.5 + 4.6, 0.0, 1.1, 0.05, 3, MHPalette.METAL)
			slab(b, Vector3(px, 1.0, d * 0.5 + 4.6), Vector3(0.3, 0.3, 0.2), th.accent, th.accent)
		slab(b, Vector3(0.0, 0.0, -d * 0.5 - 2.0), Vector3(w * 0.7, 0.2, 3.0), th.base, th.base)
		walls(b, Vector3(0.0, 0.2, -d * 0.5 - 2.0), Vector3(w * 0.7, 2.6, 3.0), th.wall_alt)
		shed(b, Vector3(0.0, 2.8, -d * 0.5 - 2.0), w * 0.7 + 0.4, 3.4, 0.7, th.roof)
	if tier >= 5:
		fence(b, Vector3(-w * 0.5 - 1.5, 0.0, d * 0.5 + 5.6), Vector3(w * 0.5 + 1.5, 0.0, d * 0.5 + 5.6), 8, 1.1, th.trim)
		fence(b, Vector3(-w * 0.5 - 1.5, 0.0, d * 0.5 + 5.6), Vector3(-w * 0.5 - 1.5, 0.0, -d * 0.5 - 4.0), 6,
			1.1, th.trim)
		fence(b, Vector3(w * 0.5 + 1.5, 0.0, d * 0.5 + 5.6), Vector3(w * 0.5 + 1.5, 0.0, -d * 0.5 - 4.0), 6,
			1.1, th.trim)
		flagpole(b, Vector3(0.0, 0.0, d * 0.5 + 6.2), 8.0, th.accent)
		slab(b, Vector3(w * 0.5 + 3.0, 0.0, d * 0.5 + 1.0), Vector3(2.8, 0.15, 4.0), th.base, th.base)
		for i in range(2):
			column(b, w * 0.5 + 3.0 + (float(i) - 0.5) * 2.2, d * 0.5 + 2.6, 0.15, 3.0, 0.08, 4, th.trim)
		slab(b, Vector3(w * 0.5 + 3.0, 3.0, d * 0.5 + 1.0), Vector3(3.0, 0.15, 4.2), th.roof, th.trim)


static func maintenance(b: MHMeshBuilder, tier: int, spec: int, th: MHBuildingTheme) -> void:
	var w: float = at([5.0, 6.5, 8.0, 10.0, 13.0], tier)
	var d: float = at([4.0, 5.0, 6.0, 7.0, 8.0], tier)
	var h: float = at([3.0, 3.2, 3.4, 3.6, 3.8], tier)
	var rise: float = at([0.8, 1.0, 1.2, 1.4, 1.6], tier)
	var bays: int = at_i([1, 2, 2, 3, 4], tier)
	var mowers: int = at_i([1, 2, 3, 5, 7], tier)
	var sx: float = 1.0 if spec == 0 else -1.0
	slab(b, Vector3.ZERO, Vector3(w + 0.6, 0.2, d + 0.6), MHPalette.STONE_DARK, MHPalette.STONE_DARK)
	wing(b, Vector3(0.0, 0.2, 0.0), 0.0, w, d, h, 1, th.wall, th.roof, th.trim, th.glass, ROOF_GABLE, rise, 0, false)
	windows(b, 0.0, 1.5, d * 0.5 + 0.03, 1.0, bays, minf(2.6, w / float(bays) * 0.7), 2.8, w / float(bays),
		th.wall_alt, th.accent, false)
	for i in range(mowers):
		var mx: float = (float(i) - float(mowers - 1) * 0.5) * 1.5
		mower(b, Vector3(mx, 0.0, d * 0.5 + 2.4), 0.0, th.accent, MHPalette.METAL)
	if tier >= 2:
		var ts: Transform3D = push(b, Vector3(sx * (w * 0.5 + 1.6), 0.0, -d * 0.2), 0.0)
		b.frustum(0.3, 2.2, 0.9, 0.9, 8, MHPalette.METAL, MHPalette.CANVAS_WHITE, false, true)
		b.frustum(0.0, 0.3, 0.7, 0.7, 4, MHPalette.METAL_DARK, MHPalette.METAL_DARK, false, false)
		pop(b, ts)
		for i in range(2):
			var cs: Transform3D = push(b, Vector3(-sx * (w * 0.5 + 1.5 + float(i) * 1.6), 0.0, -d * 0.3), 0.0)
			b.frustum(0.0, 1.0 + float(i) * 0.4, 0.9, 0.0, 7, MHPalette.SAND_SHADE, MHPalette.SAND, false, false)
			pop(b, cs)
	if tier >= 3:
		slab(b, Vector3(sx * (w * 0.5 + 3.4), 0.0, d * 0.5 + 1.6), Vector3(4.0, 0.1, 4.0), th.base, th.base)
		wing(b, Vector3(-sx * (w * 0.5 + 2.2), 0.2, d * 0.1), 0.0, 3.4, 3.4, 2.8, 1, th.wall_alt, th.roof,
			th.trim, th.glass, ROOF_GABLE, 1.0, 1, true)
		for i in range(3):
			b.tube(Vector3(-w * 0.4 + float(i) * 0.5, 0.2, -d * 0.5 - 0.8), Vector3(-w * 0.4 + float(i) * 0.5, 0.9,
				-d * 0.5 - 2.6), 0.1, 0.1, 4, MHPalette.METAL, MHPalette.METAL)
		shrub(b, Vector3(w * 0.5 + 1.0, 0.0, d * 0.5 + 0.6), 0.6, 111)
	if tier >= 4:
		wing(b, Vector3(0.0, 0.2, -d * 0.5 - 3.5), 0.0, w * 0.8, 5.0, 4.4, 1, th.wall, th.roof, th.trim,
			th.glass, ROOF_GABLE, 1.6, 3, false)
		var ws: Transform3D = push(b, Vector3(sx * (w * 0.5 + 4.0), 0.0, -d * 0.5), 0.0)
		b.frustum(4.0, 6.0, 1.5, 1.5, 10, MHPalette.METAL, MHPalette.CANVAS_WHITE, false, true)
		for i in range(4):
			var lx: float = 1.0 if i % 2 == 0 else -1.0
			var lz: float = 1.0 if i < 2 else -1.0
			b.tube(Vector3(lx, 0.0, lz), Vector3(lx * 1.2, 4.0, lz * 1.2), 0.08, 0.08, 3, MHPalette.METAL_DARK,
				MHPalette.METAL_DARK)
		pop(b, ws)
		fence(b, Vector3(-w * 0.5 - 1.0, 0.0, d * 0.5 + 5.0), Vector3(w * 0.5 + 1.0, 0.0, d * 0.5 + 5.0), 6, 1.2,
			MHPalette.METAL)
	if tier >= 5:
		slab(b, Vector3(-sx * (w * 0.5 + 5.5), 0.0, d * 0.5 + 1.0), Vector3(4.0, 0.15, 5.0), MHPalette.STONE_DARK,
			MHPalette.STONE_DARK)
		slab(b, Vector3(-sx * (w * 0.5 + 5.5), 3.2, d * 0.5 + 1.0), Vector3(4.4, 0.2, 5.4), th.accent, th.roof)
		for i in range(4):
			column(b, -sx * (w * 0.5 + 5.5) + (1.0 if i % 2 == 0 else -1.0) * 1.8,
				d * 0.5 + 1.0 + (1.0 if i < 2 else -1.0) * 2.2, 0.15, 3.2, 0.08, 4, MHPalette.METAL)
		ute(b, Vector3(sx * (w * 0.5 + 3.0), 0.0, d * 0.5 + 6.0), 0.0, th.accent)
		ute(b, Vector3(sx * (w * 0.5 + 6.0), 0.0, d * 0.5 + 6.0), 0.0, MHBuildingTheme.WALL_WHITE)
		fence(b, Vector3(-w * 0.5 - 1.0, 0.0, d * 0.5 + 5.0), Vector3(-w * 0.5 - 1.0, 0.0, -d * 0.5 - 6.5), 6, 1.2,
			MHPalette.METAL)
		fence(b, Vector3(w * 0.5 + 1.0, 0.0, d * 0.5 + 5.0), Vector3(w * 0.5 + 1.0, 0.0, -d * 0.5 - 6.5), 6, 1.2,
			MHPalette.METAL)
		for i in range(3):
			var ps: Transform3D = push(b, Vector3((float(i) - 1.0) * 3.0, 0.0, -d * 0.5 - 7.5), 0.0)
			b.frustum(0.0, 1.3, 1.2, 0.0, 8, MHPalette.DIRT, MHPalette.DIRT, false, false)
			pop(b, ps)


static func lodging(b: MHMeshBuilder, tier: int, spec: int, th: MHBuildingTheme) -> void:
	var w: float = at([6.0, 8.0, 10.0, 13.0, 16.0], tier)
	var d: float = at([5.0, 6.0, 7.0, 8.0, 9.0], tier)
	var h: float = at([2.8, 3.0, 3.2, 3.2, 3.2], tier)
	var floors: int = at_i([1, 1, 2, 2, 3], tier)
	var rise: float = at([1.4, 1.7, 2.0, 2.3, 2.7], tier)
	var sx: float = 1.0 if spec == 0 else -1.0
	var top: float = 0.3 + h * float(floors)
	slab(b, Vector3.ZERO, Vector3(w + 0.8, 0.3, d + 0.8), th.base, MHPalette.shade(th.base, 0.85))
	wing(b, Vector3(0.0, 0.3, 0.0), 0.0, w, d, h, floors, th.wall, th.roof, th.trim, th.glass, ROOF_GABLE, rise,
		at_i([2, 3, 4, 5, 6], tier), true)
	slab(b, Vector3(0.0, 0.0, d * 0.5 + 1.2), Vector3(minf(w * 0.5, 5.0), 0.2, 2.0), MHPalette.PATH_STONE,
		MHPalette.PATH_EDGE)
	shed(b, Vector3(0.0, 2.5, d * 0.5 + 1.2), minf(w * 0.5, 5.0), 2.0, 0.6, th.roof)
	column(b, -minf(w * 0.25, 2.5) + 0.1, d * 0.5 + 2.0, 0.2, 2.5, 0.07, 4, th.trim)
	column(b, minf(w * 0.25, 2.5) - 0.1, d * 0.5 + 2.0, 0.2, 2.5, 0.07, 4, th.trim)
	slab(b, Vector3(-w * 0.3, top + rise * 0.3, -d * 0.15), Vector3(0.7, rise * 0.9, 0.7),
		MHBuildingTheme.WALL_BRICK, MHBuildingTheme.WALL_BRICK)
	if tier >= 2:
		slab(b, Vector3(sx * (w * 0.5 + 3.0), 0.0, 0.5), Vector3(4.8, 0.3, 4.8), th.base,
			MHPalette.shade(th.base, 0.85))
		wing(b, Vector3(sx * (w * 0.5 + 3.0), 0.3, 0.5), 0.0, 4.4, 4.4, 2.8, 1, th.wall, th.roof, th.trim,
			th.glass, ROOF_GABLE, 1.5, 2, true)
		for i in range(3):
			flat(b, Vector3(sx * (w * 0.25 + 1.0 + float(i) * 1.0), 0.04, d * 0.5 + 2.6), 0.9, 0.9,
				MHPalette.PATH_STONE)
		shrub(b, Vector3(-w * 0.5 - 0.9, 0.0, d * 0.5 + 0.6), 0.7, 121)
		shrub(b, Vector3(w * 0.5 + 0.9, 0.0, d * 0.5 + 0.6), 0.7, 122)
	if tier >= 3:
		slab(b, Vector3(0.0, 0.3 + h, d * 0.5 + 0.9), Vector3(w * 0.6, 0.15, 1.8), MHPalette.WOOD_LIGHT,
			MHPalette.WOOD_DARK)
		fence(b, Vector3(-w * 0.3, 0.3 + h + 0.15, d * 0.5 + 1.75), Vector3(w * 0.3, 0.3 + h + 0.15, d * 0.5 + 1.75),
			6, 0.9, th.trim)
		slab(b, Vector3(-sx * (w * 0.5 + 3.0), 0.0, 0.5), Vector3(4.8, 0.3, 4.8), th.base,
			MHPalette.shade(th.base, 0.85))
		wing(b, Vector3(-sx * (w * 0.5 + 3.0), 0.3, 0.5), 0.0, 4.4, 4.4, 2.8, 1, th.wall, th.roof, th.trim,
			th.glass, ROOF_GABLE, 1.5, 2, true)
		flagpole(b, Vector3(w * 0.5 + 0.5, 0.0, d * 0.5 + 3.4), 6.0, th.accent)
	if tier >= 4:
		wing(b, Vector3(0.0, 0.3, -d * 0.5 - 2.5), 0.0, w * 0.6, 5.0, h, floors, th.wall_alt, th.roof, th.trim,
			th.glass, ROOF_GABLE, rise * 0.9, 3, false)
		for i in range(4):
			umbrella(b, Vector3((float(i) - 1.5) * w * 0.2, 0.0, d * 0.5 + 4.0), 1.1, th.accent)
		for i in range(4):
			var lx: float = (float(i) - 1.5) * w * 0.28
			column(b, lx, d * 0.5 + 6.0, 0.0, 1.6, 0.05, 3, MHPalette.METAL)
			slab(b, Vector3(lx, 1.5, d * 0.5 + 6.0), Vector3(0.3, 0.3, 0.3), MHPalette.FLAG_YELLOW,
				MHPalette.FLAG_YELLOW)
	if tier >= 5:
		wing(b, Vector3(0.0, 0.3, 0.0), 0.0, 3.4, 3.4, 3.2, 4, th.wall_alt, th.roof, th.trim, th.glass, ROOF_HIP,
			2.2, 1, false)
		for i in range(4):
			column(b, (float(i) - 1.5) * w * 0.2, d * 0.5 + 4.6, 0.0, 3.6, 0.12, 5, th.trim)
		slab(b, Vector3(0.0, 3.6, d * 0.5 + 3.4), Vector3(w * 0.7, 0.2, 3.0), th.roof, th.trim)
		var fs: Transform3D = push(b, Vector3(0.0, 0.0, d * 0.5 + 8.5), 0.0)
		b.frustum(0.0, 0.55, 1.7, 1.6, 10, MHPalette.STONE_DARK, MHPalette.STONE_LIGHT, false, false)
		b.disc(Vector3(0.0, 0.45, 0.0), 1.45, 10, MHPalette.WATER, true)
		pop(b, fs)
		for i in range(6):
			shrub(b, Vector3((float(i) - 2.5) * w * 0.17, 0.0, -d * 0.5 - 6.0), 0.8, 130 + i)
		flagpole(b, Vector3(-w * 0.5 - 0.5, 0.0, d * 0.5 + 3.4), 6.0, th.accent)


static func homes(b: MHMeshBuilder, tier: int, spec: int, th: MHBuildingTheme) -> void:
	var w: float = at([6.0, 7.5, 9.0, 11.0, 14.0], tier)
	var d: float = at([5.0, 6.0, 7.0, 8.0, 9.0], tier)
	var h: float = at([2.6, 2.7, 2.8, 3.0, 3.2], tier)
	var floors: int = at_i([1, 1, 2, 2, 2], tier)
	var rise: float = at([1.4, 1.6, 2.0, 2.3, 2.6], tier)
	var kind: int = ROOF_GABLE if tier < 4 else ROOF_HIP
	var sx: float = 1.0 if spec == 0 else -1.0
	var top: float = 0.2 + h * float(floors)
	slab(b, Vector3.ZERO, Vector3(w + 0.6, 0.2, d + 0.6), th.base, MHPalette.shade(th.base, 0.85))
	wing(b, Vector3(0.0, 0.2, 0.0), 0.0, w, d, h, floors, th.wall, th.roof, th.trim, th.glass, kind, rise,
		at_i([2, 2, 3, 4, 5], tier), true)
	slab(b, Vector3(0.0, 0.0, d * 0.5 + 0.9), Vector3(1.8, 0.15, 1.4), MHPalette.PATH_STONE, MHPalette.PATH_EDGE)
	fence(b, Vector3(-w * 0.5 - 1.0, 0.0, d * 0.5 + 3.0), Vector3(w * 0.5 + 1.0, 0.0, d * 0.5 + 3.0), 5, 0.9, th.trim)
	column(b, w * 0.5 + 1.0, d * 0.5 + 3.4, 0.0, 1.0, 0.04, 3, MHPalette.METAL)
	slab(b, Vector3(w * 0.5 + 1.0, 1.0, d * 0.5 + 3.4), Vector3(0.3, 0.25, 0.4), th.accent, th.accent)
	if tier >= 2:
		slab(b, Vector3(sx * (w * 0.5 + 2.2), 0.0, 0.5), Vector3(4.4, 0.2, d * 0.9), th.base, th.base)
		wing(b, Vector3(sx * (w * 0.5 + 2.2), 0.2, 0.5), 0.0, 4.0, d * 0.8, 2.6, 1, th.wall_alt, th.roof,
			th.trim, th.glass, ROOF_GABLE, 1.2, 0, false)
		windows(b, sx * (w * 0.5 + 2.2), 1.2, 0.5 + d * 0.4 + 0.03, 1.0, 1, 3.0, 2.2, 1.0, th.wall, th.trim, false)
		flat(b, Vector3(sx * (w * 0.5 + 2.2), 0.03, d * 0.5 + 3.0), 3.4, 4.0, MHPalette.STONE_DARK)
		slab(b, Vector3(-w * 0.28, top + rise * 0.3, -d * 0.15), Vector3(0.7, rise * 0.9, 0.7),
			MHBuildingTheme.WALL_BRICK, MHBuildingTheme.WALL_BRICK)
		shrub(b, Vector3(-w * 0.5 - 0.8, 0.0, d * 0.5 + 0.6), 0.7, 141)
		shrub(b, Vector3(w * 0.5 + 0.8, 0.0, d * 0.5 + 0.6), 0.7, 142)
	if tier >= 3:
		shed(b, Vector3(0.0, 2.5, d * 0.5 + 1.0), 3.0, 1.6, 0.6, th.roof)
		column(b, -1.3, d * 0.5 + 1.7, 0.15, 2.5, 0.07, 4, th.trim)
		column(b, 1.3, d * 0.5 + 1.7, 0.15, 2.5, 0.07, 4, th.trim)
		fence(b, Vector3(-w * 0.5 - 1.0, 0.0, d * 0.5 + 3.0), Vector3(-w * 0.5 - 1.0, 0.0, -d * 0.5 - 2.0), 5, 0.9,
			th.trim)
		fence(b, Vector3(w * 0.5 + 1.0, 0.0, d * 0.5 + 3.0), Vector3(w * 0.5 + 1.0, 0.0, -d * 0.5 - 2.0), 5, 0.9,
			th.trim)
		flagpole(b, Vector3(-w * 0.5 - 0.4, 0.0, d * 0.5 + 2.0), 4.0, th.accent)
	if tier >= 4:
		slab(b, Vector3(0.0, 0.2 + h, d * 0.5 + 0.8), Vector3(w * 0.4, 0.15, 1.6), MHPalette.WOOD_LIGHT,
			MHPalette.WOOD_DARK)
		fence(b, Vector3(-w * 0.2, 0.35 + h, d * 0.5 + 1.55), Vector3(w * 0.2, 0.35 + h, d * 0.5 + 1.55), 4, 0.9,
			th.trim)
		slab(b, Vector3(-sx * (w * 0.5 + 2.4), 0.0, 0.0), Vector3(4.8, 0.2, 5.0), th.base, th.base)
		wing(b, Vector3(-sx * (w * 0.5 + 2.4), 0.2, 0.0), 0.0, 4.4, 4.6, 2.8, 1, th.wall, th.roof, th.trim,
			th.glass, ROOF_HIP, 1.5, 2, false)
		for i in range(4):
			shrub(b, Vector3((float(i) - 1.5) * w * 0.25, 0.0, d * 0.5 + 2.2), 0.55, 150 + i)
	if tier >= 5:
		for i in range(4):
			column(b, (float(i) - 1.5) * w * 0.18, d * 0.5 + 2.2, 0.0, h * 2.0, 0.14, 6, th.trim)
		gable(b, Vector3(0.0, 0.2 + h * 2.0, d * 0.5 + 2.2), w * 0.55, 3.0, 1.6, 0.2, th.roof, th.trim)
		slab(b, Vector3(0.0, 0.0, d * 0.5 + 2.2), Vector3(w * 0.6, 0.3, 3.4), MHPalette.PATH_STONE,
			MHPalette.PATH_EDGE)
		slab(b, Vector3(0.0, 0.0, d * 0.5 + 7.0), Vector3(5.0, 0.12, 4.0), MHPalette.WATER, MHPalette.WATER_DEEP)
		fence(b, Vector3(-w * 0.5 - 4.0, 0.0, d * 0.5 + 9.5), Vector3(w * 0.5 + 4.0, 0.0, d * 0.5 + 9.5), 7, 1.1,
			th.trim)
		for i in range(2):
			slab(b, Vector3((float(i) - 0.5) * 6.0, 0.0, d * 0.5 + 9.5), Vector3(0.5, 1.8, 0.5), th.base,
				th.base)
		for i in range(4):
			shrub(b, Vector3((float(i) - 1.5) * w * 0.3, 0.0, -d * 0.5 - 1.0), 0.8, 160 + i)


static func landmark(b: MHMeshBuilder, tier: int, spec: int, th: MHBuildingTheme) -> void:
	var k: float = at([1.0, 1.3, 1.6, 2.0, 2.5], tier)
	var sx: float = -1.0 if spec == 0 else 1.0
	slab(b, Vector3.ZERO, Vector3(8.0 * k, 0.15, 8.0 * k), MHPalette.PATH_STONE, MHPalette.PATH_EDGE)
	slab(b, Vector3(0.0, 0.15, 0.0), Vector3(5.6 * k, 0.15, 5.6 * k), th.wall, MHPalette.shade(th.wall, 0.85))
	slab(b, Vector3(0.0, 0.3, 0.0), Vector3(3.6 * k, 0.15, 3.6 * k), th.wall_alt, MHPalette.shade(th.wall, 0.85))
	b.frustum(0.45, 2.6, 0.9, 0.55, 6, MHPalette.STONE_DARK, th.wall_alt, false, true)
	b.blob(Vector3(0.0, 3.2, 0.0), Vector3(0.6, 0.6, 0.6), 3, 8, MHBuildingTheme.GOLD, MHBuildingTheme.GOLD, 7, 0.0)
	flagpole(b, Vector3(3.2 * k, 0.0, 3.2 * k), 6.0, th.accent)
	flagpole(b, Vector3(-3.2 * k, 0.0, 3.2 * k), 6.0, th.accent)
	if tier >= 2:
		var pr: float = 2.6 * k
		for i in range(6):
			var ang: float = TAU * float(i) / 6.0
			column(b, cos(ang) * pr, sin(ang) * pr, 0.45, 4.45, 0.16, 6, th.wall_alt)
		hip(b, Vector3(0.0, 4.45, 0.0), pr * 2.0 + 0.6, pr * 2.0 + 0.6, 1.3, 0.2, 0.2, th.roof)
		slab(b, Vector3(0.0, 0.45, pr + 1.5), Vector3(2.0, 0.4, 0.7), MHPalette.WOOD_LIGHT, MHPalette.WOOD_DARK)
		slab(b, Vector3(0.0, 0.45, -pr - 1.5), Vector3(2.0, 0.4, 0.7), MHPalette.WOOD_LIGHT, MHPalette.WOOD_DARK)
	if tier >= 3:
		var tx: float = sx * 5.0 * k
		var tz: float = -3.0 * k
		slab(b, Vector3(tx, 0.0, tz), Vector3(4.0, 0.3, 4.0), th.wall_alt, th.wall)
		walls(b, Vector3(tx, 0.3, tz), Vector3(3.0, 9.0, 3.0), th.wall)
		hip(b, Vector3(tx, 9.3, tz), 3.0, 3.0, 2.2, 0.3, 0.0, th.roof)
		for i in range(4):
			var ts: Transform3D = push(b, Vector3(tx, 0.0, tz), PI * 0.5 * float(i))
			windows(b, 0.0, 7.6, 1.53, 1.0, 1, 1.5, 1.5, 1.0, MHBuildingTheme.WALL_WHITE, MHPalette.METAL_DARK,
				false)
			windows(b, 0.0, 4.0, 1.53, 1.0, 1, 0.7, 1.4, 1.0, th.glass, th.trim, false)
			pop(b, ts)
		b.tube(Vector3(tx, 11.5, tz), Vector3(tx, 13.0, tz), 0.06, 0.03, 3, MHBuildingTheme.GOLD, MHBuildingTheme.GOLD)
		for i in range(3):
			flat(b, Vector3(sx * (2.0 * k + float(i) * 1.2 * k), 0.17, -1.0 * k), 1.0 * k, 0.8 * k, MHPalette.PATH_EDGE)
	if tier >= 4:
		for i in range(2):
			var gx: float = (float(i) - 0.5) * 9.0 * k
			walls(b, Vector3(gx, 0.0, 4.5 * k), Vector3(2.0, 3.0, 1.0), th.wall)
			slab(b, Vector3(gx, 3.0, 4.5 * k), Vector3(2.4, 0.3, 1.4), th.roof, th.wall_alt)
		for i in range(6):
			var lx: float = (float(i) - 2.5) * 1.6 * k
			column(b, lx, 6.2 * k, 0.0, 2.2, 0.06, 3, MHPalette.METAL_DARK)
			b.blob(Vector3(lx, 2.5, 6.2 * k), Vector3(0.22, 0.22, 0.22), 2, 5, MHBuildingTheme.GOLD,
				MHBuildingTheme.GOLD, 20 + i, 0.0)
		slab(b, Vector3(0.0, 0.0, 6.2 * k), Vector3(10.0 * k, 0.1, 1.0), MHPalette.PATH_STONE, MHPalette.PATH_EDGE)
		flagpole(b, Vector3(0.0, 0.0, 8.0 * k), 8.0, MHPalette.FLAG_WHITE)
	if tier >= 5:
		b.blob(Vector3(0.0, 6.1, 0.0), Vector3(1.9 * k, 1.5 * k, 1.9 * k), 4, 10, th.roof, MHBuildingTheme.GOLD, 9, 0.0)
		b.tube(Vector3(0.0, 6.1 + 1.5 * k, 0.0), Vector3(0.0, 6.1 + 1.5 * k + 2.5, 0.0), 0.12, 0.03, 4,
			MHBuildingTheme.GOLD, MHBuildingTheme.GOLD)
		var rs: Transform3D = push(b, Vector3.ZERO, 0.0)
		b.frustum(0.0, 0.3, 4.4 * k, 4.2 * k, 12, MHPalette.STONE_LIGHT, MHPalette.STONE_LIGHT, false, false)
		pop(b, rs)
		for i in range(12):
			var ang2: float = TAU * float(i) / 12.0
			shrub(b, Vector3(cos(ang2) * 5.2 * k, 0.0, sin(ang2) * 5.2 * k), 0.6, 30 + i)
		flagpole(b, Vector3(3.2 * k, 0.0, -3.2 * k), 7.0, th.accent)
		flagpole(b, Vector3(-3.2 * k, 0.0, -3.2 * k), 7.0, th.accent)

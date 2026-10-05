class_name MHBuildingsGolf
extends MHBuildingParts
## Golf-facing buildings: clubhouse, pro shop, driving range, restaurant, pool and spa.
## Each function adds everything up to `tier` (1..5), so a higher tier is always the lower tier plus more
## and bigger (triangle counts and bounds only grow). `spec` (0 or 1) is the tier-3 specialisation; it
## swaps the colour scheme (via MHBuildingTheme) and which side the extra wing goes on, never the
## triangle count. Origin: ground, centre of the main block. Front is +Z.


static func clubhouse(b: MHMeshBuilder, tier: int, spec: int, th: MHBuildingTheme) -> void:
	var w: float = at([8.0, 10.0, 13.0, 16.0, 20.0], tier)
	var d: float = at([6.0, 7.0, 8.0, 9.0, 10.0], tier)
	var h: float = at([3.0, 3.0, 3.2, 3.0, 3.2], tier)
	var floors: int = at_i([1, 1, 1, 2, 2], tier)
	var rise: float = at([1.6, 1.9, 2.2, 2.6, 3.0], tier)
	var top: float = 0.3 + h * float(floors)
	var sx: float = -1.0 if spec == 0 else 1.0
	slab(b, Vector3.ZERO, Vector3(w + 0.8, 0.3, d + 0.8), th.base, MHPalette.shade(th.base, 0.85))
	wing(b, Vector3(0.0, 0.3, 0.0), 0.0, w, d, h, floors, th.wall, th.roof, th.trim, th.glass,
		ROOF_GABLE, rise, at_i([2, 3, 4, 6, 8], tier), true)
	var pw: float = minf(w * 0.4, 6.0)
	slab(b, Vector3(0.0, 0.0, d * 0.5 + 1.3), Vector3(pw, 0.2, 2.2), MHPalette.PATH_STONE, MHPalette.PATH_EDGE)
	slab(b, Vector3(w * 0.28, top + rise * 0.3, -d * 0.15), Vector3(0.7, rise * 0.9, 0.7),
		MHBuildingTheme.WALL_BRICK, MHBuildingTheme.WALL_BRICK)
	if tier >= 2:
		flagpole(b, Vector3(w * 0.5 + 1.8, 0.0, d * 0.5 + 1.5), 6.0, th.accent)
		shed(b, Vector3(0.0, 2.5, d * 0.5 + 1.3), pw, 2.2, 0.7, th.roof)
		column(b, -pw * 0.5 + 0.15, d * 0.5 + 2.2, 0.2, 2.5, 0.07, 4, th.trim)
		column(b, pw * 0.5 - 0.15, d * 0.5 + 2.2, 0.2, 2.5, 0.07, 4, th.trim)
		shrub(b, Vector3(-w * 0.5 - 0.9, 0.0, d * 0.5 + 0.8), 0.7, 11)
		shrub(b, Vector3(w * 0.5 + 0.9, 0.0, d * 0.5 + 0.8), 0.7, 12)
	if tier >= 3:
		slab(b, Vector3(sx * (w * 0.5 + 2.5), 0.0, -0.5), Vector3(6.0, 0.3, 6.0), th.base,
			MHPalette.shade(th.base, 0.85))
		wing(b, Vector3(sx * (w * 0.5 + 2.5), 0.3, -0.5), 0.0, 5.0, 5.0, 3.0, 1, th.wall_alt, th.roof,
			th.trim, th.glass, ROOF_GABLE, 1.5, 2, false)
		for i in range(4):
			column(b, (float(i) - 1.5) * w * 0.18, d * 0.5 + 2.4, 0.0, 2.4, 0.07, 4, th.trim)
		awning(b, -sx * w * 0.3, 2.7, d * 0.5, w * 0.3, 1.1, 6, th.accent, MHBuildingTheme.AWNING_B)
		for i in range(3):
			flat(b, Vector3(0.0, 0.04, d * 0.5 + 3.4 + float(i) * 1.2), 1.6, 0.8, MHPalette.PATH_STONE)
		shrub(b, Vector3(-w * 0.3, 0.0, -d * 0.5 - 0.8), 0.8, 13)
		shrub(b, Vector3(w * 0.3, 0.0, -d * 0.5 - 0.8), 0.8, 14)
		shrub(b, Vector3(-w * 0.1, 0.0, -d * 0.5 - 0.8), 0.6, 15)
		shrub(b, Vector3(w * 0.1, 0.0, -d * 0.5 - 0.8), 0.6, 16)
	if tier >= 4:
		var tx: float = -sx * (w * 0.5 - 2.2)
		wing(b, Vector3(tx, 0.3, -d * 0.5 + 0.5), 0.0, 3.4, 3.4, 3.0, 3, th.wall_alt, th.roof, th.trim,
			th.glass, ROOF_HIP, 2.2, 1, false)
		windows(b, tx, 7.6, -d * 0.5 + 0.5 + 1.73, 1.0, 1, 1.4, 1.4, 1.0, MHBuildingTheme.WALL_WHITE,
			MHPalette.METAL_DARK, false)
		slab(b, Vector3(-sx * (w * 0.5 + 2.5), 0.0, -0.5), Vector3(6.0, 0.3, 6.0), th.base,
			MHPalette.shade(th.base, 0.85))
		wing(b, Vector3(-sx * (w * 0.5 + 2.5), 0.3, -0.5), 0.0, 5.0, 5.0, 3.0, 1, th.wall_alt, th.roof,
			th.trim, th.glass, ROOF_GABLE, 1.5, 2, false)
		slab(b, Vector3(0.0, 3.3, d * 0.5 + 0.9), Vector3(w * 0.5, 0.15, 1.8), MHPalette.WOOD_LIGHT,
			MHPalette.WOOD_DARK)
		fence(b, Vector3(-w * 0.25, 3.45, d * 0.5 + 1.75), Vector3(w * 0.25, 3.45, d * 0.5 + 1.75), 5, 0.9,
			th.trim)
	if tier >= 5:
		for i in range(4):
			var rz: float = -(d * 0.5 + 1.2 + float(i) * 1.1)
			var rh: float = 0.6 + 0.6 * float(i)
			var seat: Color = th.accent if i % 2 == 0 else MHBuildingTheme.AWNING_B
			slab(b, Vector3(0.0, 0.0, rz), Vector3(w * 0.7, rh, 1.1), seat, MHPalette.shade(seat, 0.8))
		slab(b, Vector3(0.0, 4.2, -(d * 0.5 + 3.0)), Vector3(w * 0.7, 0.15, 5.0), th.roof, th.trim)
		for i in range(4):
			var px: float = (float(i) - 1.5) * w * 0.7 / 3.0
			column(b, px, -(d * 0.5 + 5.3), 0.0, 4.2, 0.1, 4, th.trim)
		var fs: Transform3D = push(b, Vector3(0.0, 0.0, d * 0.5 + 5.5), 0.0)
		b.frustum(0.0, 0.55, 1.7, 1.6, 10, MHPalette.STONE_DARK, MHPalette.STONE_LIGHT, false, false)
		b.disc(Vector3(0.0, 0.45, 0.0), 1.45, 10, MHPalette.WATER, true)
		b.frustum(0.45, 1.6, 0.18, 0.12, 5, MHPalette.STONE_LIGHT, MHPalette.STONE_LIGHT, false, false)
		pop(b, fs)
		flagpole(b, Vector3(-(w * 0.5 + 1.8), 0.0, d * 0.5 + 1.5), 6.0, th.accent)
		flagpole(b, Vector3(0.0, 0.0, d * 0.5 + 9.0), 7.0, MHPalette.FLAG_WHITE)
		for i in range(6):
			shrub(b, Vector3((float(i) - 2.5) * w * 0.14, 0.0, d * 0.5 + 3.8), 0.7, 20 + i)
		b.tube(Vector3(0.0, top + rise, 0.0), Vector3(0.0, top + rise + 1.2, 0.0), 0.05, 0.03, 3,
			MHBuildingTheme.GOLD, MHBuildingTheme.GOLD)
		b.tri_two_sided(Vector3(0.0, top + rise + 1.2, 0.0), Vector3(0.0, top + rise + 0.7, 0.0),
			Vector3(0.6, top + rise + 0.95, 0.0), MHBuildingTheme.GOLD, MHBuildingTheme.GOLD,
			MHBuildingTheme.GOLD)


static func pro_shop(b: MHMeshBuilder, tier: int, spec: int, th: MHBuildingTheme) -> void:
	var w: float = at([5.0, 6.5, 8.0, 10.0, 13.0], tier)
	var d: float = at([4.0, 5.0, 6.0, 7.0, 8.0], tier)
	var h: float = at([2.8, 3.0, 3.0, 3.2, 3.0], tier)
	var floors: int = at_i([1, 1, 1, 2, 2], tier)
	var rise: float = at([1.2, 1.4, 1.7, 2.0, 2.4], tier)
	var sx: float = 1.0 if spec == 0 else -1.0
	slab(b, Vector3.ZERO, Vector3(w + 0.8, 0.3, d + 0.8), th.base, MHPalette.shade(th.base, 0.85))
	wing(b, Vector3(0.0, 0.3, 0.0), 0.0, w, d, h, floors, th.wall, th.roof, th.trim, th.glass,
		ROOF_HIP, rise, at_i([1, 2, 3, 4, 5], tier), true)
	awning(b, 0.0, 2.7, d * 0.5, minf(w * 0.5, 4.0), 1.3, 4, th.accent, MHBuildingTheme.AWNING_B)
	column(b, w * 0.5 + 1.2, d * 0.5 + 1.2, 0.0, 1.6, 0.06, 4, th.trim)
	column(b, w * 0.5 + 1.2 + 1.6, d * 0.5 + 1.2, 0.0, 1.6, 0.06, 4, th.trim)
	slab(b, Vector3(w * 0.5 + 1.2 + 0.8, 1.2, d * 0.5 + 1.2), Vector3(2.0, 0.6, 0.1), th.accent, th.accent)
	if tier >= 2:
		for i in range(3):
			var rx: float = -w * 0.5 + 0.8 + float(i) * 0.9
			slab(b, Vector3(rx, 0.0, d * 0.5 + 0.9), Vector3(0.5, 1.1, 0.3), MHPalette.WOOD_LIGHT,
				MHPalette.WOOD_DARK)
		flagpole(b, Vector3(-w * 0.5 - 1.2, 0.0, d * 0.5 + 1.0), 4.5, th.accent)
		shrub(b, Vector3(-w * 0.5 - 1.0, 0.0, 0.0), 0.6, 31)
		shrub(b, Vector3(w * 0.5 + 1.0, 0.0, -d * 0.3), 0.6, 32)
	if tier >= 3:
		slab(b, Vector3(sx * (w * 0.5 + 2.2), 0.0, 0.0), Vector3(4.4, 0.3, 5.0), th.base,
			MHPalette.shade(th.base, 0.85))
		wing(b, Vector3(sx * (w * 0.5 + 2.2), 0.3, 0.0), 0.0, 4.0, 4.5, 2.8, 1, th.wall_alt, th.roof,
			th.trim, th.glass, ROOF_GABLE, 1.3, 2, false)
		for i in range(3):
			var cz: float = d * 0.5 + 3.0 + float(i) * 1.6
			b.disc(Vector3(-sx * 1.5, 0.05, cz), 0.7, 8, MHPalette.GRASS_LIGHT, true)
			flagpole(b, Vector3(-sx * 1.5, 0.0, cz), 1.6, MHPalette.FLAG_YELLOW)
	if tier >= 4:
		slab(b, Vector3(0.0, 2.5, d * 0.5 + 1.0), Vector3(w * 0.6, 0.12, 2.0), th.roof, th.trim)
		column(b, -w * 0.3 + 0.1, d * 0.5 + 1.9, 0.0, 2.5, 0.08, 4, th.trim)
		column(b, w * 0.3 - 0.1, d * 0.5 + 1.9, 0.0, 2.5, 0.08, 4, th.trim)
		column(b, 0.0, -d * 0.5 - 1.2, 0.0, 6.0, 0.12, 5, MHPalette.METAL)
		slab(b, Vector3(0.0, 4.6, -d * 0.5 - 1.2), Vector3(2.4, 1.0, 0.2), th.accent, th.accent)
	if tier >= 5:
		slab(b, Vector3(-sx * (w * 0.5 + 2.2), 0.0, 0.0), Vector3(4.4, 0.3, 5.0), th.base,
			MHPalette.shade(th.base, 0.85))
		wing(b, Vector3(-sx * (w * 0.5 + 2.2), 0.3, 0.0), 0.0, 4.0, 4.5, 3.2, 2, th.wall_alt, th.roof,
			th.trim, th.glass, ROOF_FLAT, 0.0, 2, false)
		fence(b, Vector3(-w * 0.4, 0.0, d * 0.5 + 8.0), Vector3(w * 0.4, 0.0, d * 0.5 + 8.0), 6, 3.5,
			MHPalette.METAL_DARK)
		awning(b, 0.0, 3.4, d * 0.5, w * 0.7, 1.2, 8, th.accent, MHBuildingTheme.AWNING_B)
		for i in range(6):
			shrub(b, Vector3((float(i) - 2.5) * w * 0.17, 0.0, -d * 0.5 - 0.9), 0.7, 40 + i)


static func driving_range(b: MHMeshBuilder, tier: int, spec: int, th: MHBuildingTheme) -> void:
	var w: float = at([6.0, 8.0, 10.0, 13.0, 16.0], tier)
	var d: float = at([4.0, 5.0, 6.0, 7.0, 8.0], tier)
	var bays: int = at_i([2, 3, 4, 6, 8], tier)
	var sx: float = 1.0 if spec == 0 else -1.0
	slab(b, Vector3.ZERO, Vector3(w, 0.2, d), th.base, MHPalette.shade(th.base, 0.85))
	walls(b, Vector3(0.0, 0.2, -d * 0.5 + 0.15), Vector3(w, 3.0, 0.3), th.wall)
	shed(b, Vector3(0.0, 3.0, 0.0), w + 0.6, d + 0.6, 0.8, th.roof)
	for i in range(bays + 1):
		var px: float = (float(i) / float(bays) - 0.5) * (w - 0.4)
		column(b, px, d * 0.5 - 0.2, 0.2, 3.0, 0.1, 4, th.wall_alt)
	for i in range(bays):
		var mx: float = ((float(i) + 0.5) / float(bays) - 0.5) * (w - 0.4)
		flat(b, Vector3(mx, 0.22, 0.4), minf(1.6, w / float(bays) * 0.7), 1.4, MHBuildingTheme.TURF_MAT)
	if tier >= 2:
		wing(b, Vector3(sx * (w * 0.5 + 1.8), 0.0, -d * 0.5 + 1.8), 0.0, 3.0, 3.0, 2.6, 1, th.wall_alt,
			th.roof, th.trim, th.glass, ROOF_GABLE, 1.1, 1, true)
		column(b, -w * 0.5 - 0.8, d * 0.5 + 0.6, 0.0, 1.5, 0.06, 4, th.trim)
		slab(b, Vector3(-w * 0.5 - 0.8, 1.3, d * 0.5 + 0.6), Vector3(1.4, 0.7, 0.1), th.accent, th.accent)
		shrub(b, Vector3(-w * 0.5 - 0.9, 0.0, -d * 0.5), 0.7, 51)
		shrub(b, Vector3(w * 0.5 + 0.9, 0.0, d * 0.5), 0.7, 52)
	if tier >= 3:
		for i in range(3):
			var lx: float = (float(i) - 1.0) * w * 0.4
			column(b, lx, d * 0.5 + 0.8, 0.0, 6.0, 0.1, 4, MHPalette.METAL)
			slab(b, Vector3(lx, 6.0, d * 0.5 + 0.8), Vector3(0.9, 0.2, 0.5), MHPalette.METAL_DARK,
				MHPalette.METAL_DARK)
		for i in range(2):
			var mz: float = d * 0.5 + 8.0 + float(i) * 8.0
			column(b, 0.0, mz, 0.0, 1.8, 0.05, 3, MHPalette.METAL)
			slab(b, Vector3(0.0, 1.5, mz), Vector3(0.9, 0.5, 0.06), th.accent, th.accent)
	if tier >= 4:
		slab(b, Vector3(0.0, 3.8, 0.0), Vector3(w + 0.6, 0.2, d + 0.6), MHPalette.WOOD_LIGHT, MHPalette.WOOD_DARK)
		fence(b, Vector3(-w * 0.5, 4.0, d * 0.5 + 0.2), Vector3(w * 0.5, 4.0, d * 0.5 + 0.2), 7, 1.0, th.trim)
		for i in range(2):
			var nx: float = (float(i) - 0.5) * (w + 4.0)
			column(b, nx, d * 0.5 + 12.0, 0.0, 9.0, 0.12, 5, MHPalette.METAL)
		fence(b, Vector3(-(w + 4.0) * 0.5, 8.5, d * 0.5 + 12.0), Vector3((w + 4.0) * 0.5, 8.5, d * 0.5 + 12.0),
			2, 0.3, MHPalette.METAL_DARK)
	if tier >= 5:
		wing(b, Vector3(-sx * (w * 0.5 + 2.4), 0.0, -d * 0.5 + 2.4), 0.0, 4.6, 4.6, 3.0, 1, th.wall_alt, th.roof,
			th.trim, th.glass, ROOF_HIP, 1.6, 2, true)
		for i in range(3):
			var gz: float = d * 0.5 + 11.0 + float(i) * 5.0
			b.disc(Vector3((float(i) - 1.0) * 5.0, 0.05, gz), 2.0, 10, MHPalette.GRASS_LIGHT, true)
			flagpole(b, Vector3((float(i) - 1.0) * 5.0, 0.0, gz), 2.4, MHPalette.FLAG_YELLOW)
		for i in range(2):
			table(b, Vector3(-sx * (w * 0.5 + 2.0), 0.0, d * 0.5 + 2.0 + float(i) * 2.2), 0.0,
				MHPalette.WOOD_LIGHT, MHPalette.WOOD_DARK)
		umbrella(b, Vector3(-sx * (w * 0.5 + 2.0), 0.0, d * 0.5 + 3.1), 1.4, th.accent)


static func restaurant(b: MHMeshBuilder, tier: int, spec: int, th: MHBuildingTheme) -> void:
	var w: float = at([5.0, 8.0, 10.0, 12.0, 15.0], tier)
	var d: float = at([4.0, 6.0, 7.0, 8.0, 9.0], tier)
	var h: float = at([2.8, 3.0, 3.2, 3.0, 3.2], tier)
	var floors: int = at_i([1, 1, 1, 2, 2], tier)
	var rise: float = at([1.3, 1.6, 1.9, 2.2, 2.6], tier)
	var sx: float = -1.0 if spec == 0 else 1.0
	slab(b, Vector3.ZERO, Vector3(w + 0.8, 0.3, d + 0.8), th.base, MHPalette.shade(th.base, 0.85))
	wing(b, Vector3(0.0, 0.3, 0.0), 0.0, w, d, h, floors, th.wall, th.roof, th.trim, th.glass,
		ROOF_GABLE, rise, at_i([1, 3, 4, 5, 6], tier), true)
	awning(b, 0.0, 2.6, d * 0.5, minf(w * 0.7, 6.0), 1.2, 6, th.accent, MHBuildingTheme.AWNING_B)
	slab(b, Vector3(w * 0.3, 0.3 + h * float(floors) + rise * 0.3, -d * 0.2), Vector3(0.8, rise * 0.9, 0.8),
		MHBuildingTheme.WALL_BRICK, MHBuildingTheme.WALL_BRICK)
	table(b, Vector3(w * 0.5 + 1.6, 0.0, d * 0.5 + 0.8), 0.0, MHPalette.WOOD_LIGHT, MHPalette.WOOD_DARK)
	if tier >= 2:
		slab(b, Vector3(0.0, 0.0, d * 0.5 + 2.6), Vector3(w * 0.8, 0.15, 3.6), MHPalette.PATH_STONE,
			MHPalette.PATH_EDGE)
		for i in range(3):
			var ux: float = (float(i) - 1.0) * w * 0.25
			umbrella(b, Vector3(ux, 0.15, d * 0.5 + 2.8), 1.2, th.accent if i % 2 == 0 else MHPalette.FLAG_WHITE)
		fence(b, Vector3(-w * 0.4, 0.15, d * 0.5 + 4.4), Vector3(w * 0.4, 0.15, d * 0.5 + 4.4), 6, 0.8, th.trim)
	if tier >= 3:
		slab(b, Vector3(sx * (w * 0.5 + 2.5), 0.0, -0.5), Vector3(5.4, 0.3, 5.4), th.base,
			MHPalette.shade(th.base, 0.85))
		wing(b, Vector3(sx * (w * 0.5 + 2.5), 0.3, -0.5), 0.0, 5.0, 5.0, 3.0, 1, th.wall_alt, th.roof,
			th.trim, th.glass, ROOF_HIP, 1.8, 2, false)
		for i in range(2):
			table(b, Vector3(-sx * (w * 0.5 + 1.6), 0.0, d * 0.5 + 0.8 + float(i) * 2.0), 0.0,
				MHPalette.WOOD_LIGHT, MHPalette.WOOD_DARK)
		shrub(b, Vector3(-w * 0.5 - 0.8, 0.0, -d * 0.5), 0.7, 61)
		shrub(b, Vector3(w * 0.5 + 0.8, 0.0, d * 0.5 + 0.2), 0.7, 62)
	if tier >= 4:
		slab(b, Vector3(0.0, 3.3, d * 0.5 + 0.9), Vector3(w * 0.6, 0.15, 1.8), MHPalette.WOOD_LIGHT,
			MHPalette.WOOD_DARK)
		fence(b, Vector3(-w * 0.3, 3.45, d * 0.5 + 1.75), Vector3(w * 0.3, 3.45, d * 0.5 + 1.75), 6, 0.9,
			th.trim)
		for i in range(4):
			umbrella(b, Vector3((float(i) - 1.5) * w * 0.2, 0.15, d * 0.5 + 3.8), 1.1, th.accent)
		flagpole(b, Vector3(-w * 0.5 - 1.2, 0.0, d * 0.5 + 1.2), 6.0, th.accent)
	if tier >= 5:
		slab(b, Vector3(-sx * (w * 0.5 + 2.8), 0.0, -0.5), Vector3(5.6, 0.3, 6.0), th.base,
			MHPalette.shade(th.base, 0.85))
		wing(b, Vector3(-sx * (w * 0.5 + 2.8), 0.3, -0.5), 0.0, 5.2, 5.6, 3.4, 1, th.wall_alt, th.roof,
			th.trim, th.glass, ROOF_HIP, 2.4, 3, false)
		for i in range(5):
			var tx: float = (float(i) - 2.0) * w * 0.17
			column(b, tx, d * 0.5 + 5.6, 0.0, 2.6, 0.05, 3, MHPalette.METAL)
			slab(b, Vector3(tx, 2.6, d * 0.5 + 5.6), Vector3(0.3, 0.3, 0.3), MHPalette.FLAG_YELLOW,
				MHPalette.FLAG_YELLOW)
		var fs: Transform3D = push(b, Vector3(0.0, 0.0, d * 0.5 + 7.5), 0.0)
		b.frustum(0.0, 0.5, 1.5, 1.4, 10, MHPalette.STONE_DARK, MHPalette.STONE_LIGHT, false, false)
		b.disc(Vector3(0.0, 0.42, 0.0), 1.3, 10, MHPalette.WATER, true)
		pop(b, fs)
		for i in range(6):
			shrub(b, Vector3((float(i) - 2.5) * w * 0.17, 0.0, -d * 0.5 - 0.9), 0.7, 70 + i)


static func pool_spa(b: MHMeshBuilder, tier: int, spec: int, th: MHBuildingTheme) -> void:
	var pw: float = at([7.0, 9.0, 11.0, 13.0, 16.0], tier)
	var pd: float = at([4.0, 5.0, 6.0, 7.0, 8.0], tier)
	var sx: float = 1.0 if spec == 0 else -1.0
	slab(b, Vector3.ZERO, Vector3(pw + 3.0, 0.2, pd + 3.0), MHPalette.PATH_STONE, MHPalette.PATH_EDGE)
	slab(b, Vector3(0.0, 0.2, 0.0), Vector3(pw, 0.06, pd), MHPalette.WATER, MHPalette.WATER_DEEP)
	for i in range(4):
		var lx: float = (float(i) - 1.5) * pw * 0.2
		slab(b, Vector3(lx, 0.2, pd * 0.5 + 1.0), Vector3(0.7, 0.3, 1.8), MHBuildingTheme.AWNING_B, th.accent)
	if tier >= 2:
		wing(b, Vector3(sx * (pw * 0.5 + 3.0), 0.0, 0.0), 0.0, 4.0, 4.0, 2.8, 1, th.wall, th.roof, th.trim,
			th.glass, ROOF_FLAT, 0.0, 1, true)
		fence(b, Vector3(-pw * 0.5 - 1.4, 0.0, -pd * 0.5 - 1.4), Vector3(pw * 0.5 + 1.4, 0.0, -pd * 0.5 - 1.4),
			6, 1.1, th.trim)
		umbrella(b, Vector3(-pw * 0.3, 0.2, pd * 0.5 + 1.6), 1.2, th.accent)
	if tier >= 3:
		var hs: Transform3D = push(b, Vector3(-sx * (pw * 0.5 + 2.2), 0.0, 0.0), 0.0)
		b.frustum(0.0, 0.6, 1.5, 1.5, 8, MHPalette.STONE_LIGHT, MHPalette.STONE_LIGHT, false, false)
		b.disc(Vector3(0.0, 0.5, 0.0), 1.3, 8, MHPalette.WATER, true)
		pop(b, hs)
		hip(b, Vector3(-sx * (pw * 0.5 + 2.2), 2.6, 0.0), 3.6, 3.6, 0.9, 0.2, 0.0, th.roof)
		for i in range(4):
			var cx: float = -sx * (pw * 0.5 + 2.2) + (1.0 if i % 2 == 0 else -1.0) * 1.5
			var cz: float = (1.0 if i < 2 else -1.0) * 1.5
			column(b, cx, cz, 0.0, 2.6, 0.07, 4, th.trim)
		shrub(b, Vector3(pw * 0.5 + 1.0, 0.0, pd * 0.5 + 1.0), 0.7, 81)
		shrub(b, Vector3(-pw * 0.5 - 1.0, 0.0, pd * 0.5 + 1.0), 0.7, 82)
	if tier >= 4:
		wing(b, Vector3(0.0, 0.0, -pd * 0.5 - 4.0), 0.0, pw * 0.6, 4.0, 3.0, 2, th.wall_alt, th.roof, th.trim,
			th.glass, ROOF_FLAT, 0.0, 3, false)
		walls(b, Vector3(pw * 0.5 + 2.0, 0.0, pd * 0.5 + 2.0), Vector3(1.6, 5.0, 1.6), th.wall_alt)
		slab(b, Vector3(pw * 0.5 + 2.0, 5.0, pd * 0.5 + 2.0), Vector3(2.0, 0.2, 2.0), th.accent, th.trim)
		b.tube(Vector3(pw * 0.5 + 2.0, 5.2, pd * 0.5 + 2.8), Vector3(pw * 0.5 + 0.2, 0.3, pd * 0.5 - 0.6),
			0.5, 0.5, 4, th.accent, th.accent)
	if tier >= 5:
		for i in range(4):
			column(b, (float(i) - 1.5) * pw * 0.25, pd * 0.5 + 2.4, 0.0, 3.0, 0.1, 5, th.trim)
		slab(b, Vector3(0.0, 3.0, pd * 0.5 + 2.4), Vector3(pw * 0.8, 0.15, 1.2), th.roof, th.trim)
		b.tube(Vector3(-pw * 0.5, 0.2, 0.0), Vector3(-pw * 0.5 + 1.8, 0.8, 0.0), 0.15, 0.15, 4,
			MHPalette.METAL, MHPalette.METAL)
		slab(b, Vector3(-pw * 0.5 + 0.9, 0.7, 0.0), Vector3(1.8, 0.08, 0.5), th.accent, th.accent)
		for i in range(6):
			umbrella(b, Vector3((float(i) - 2.5) * pw * 0.16, 0.0, pd * 0.5 + 4.6), 1.1,
				th.accent if i % 2 == 0 else MHPalette.FLAG_WHITE)
		for i in range(4):
			shrub(b, Vector3((float(i) - 1.5) * pw * 0.3, 0.0, -pd * 0.5 - 7.0), 0.8, 90 + i)

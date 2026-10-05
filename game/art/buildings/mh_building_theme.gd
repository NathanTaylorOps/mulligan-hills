class_name MHBuildingTheme
extends RefCounted
## Per-building colour scheme. Built only from fixed values (no randomness), so a (building id, spec)
## pair always gives the same colours. `spec` is the tier-3 specialisation: 0 = "a", 1 = "b". Spec b
## swaps the roof and accent colours so the two branches are told apart at a glance.
## Extra building colours live here (not in MHPalette, which belongs to the shared art kit).

const WALL_CREAM: Color = Color(0.96, 0.92, 0.80)
const WALL_SAND: Color = Color(0.93, 0.85, 0.68)
const WALL_WHITE: Color = Color(0.97, 0.96, 0.92)
const WALL_BRICK: Color = Color(0.72, 0.41, 0.32)
const WALL_BARN: Color = Color(0.70, 0.24, 0.20)
const WALL_SAGE: Color = Color(0.70, 0.78, 0.66)
const WALL_SKY: Color = Color(0.74, 0.86, 0.92)
const WALL_TIMBER: Color = Color(0.66, 0.47, 0.30)
const WALL_GREY: Color = Color(0.74, 0.76, 0.76)
const ROOF_RED: Color = Color(0.72, 0.27, 0.22)
const ROOF_TERRACOTTA: Color = Color(0.80, 0.42, 0.26)
const ROOF_SLATE: Color = Color(0.36, 0.40, 0.46)
const ROOF_BLUE: Color = Color(0.25, 0.42, 0.62)
const ROOF_GREEN: Color = Color(0.20, 0.45, 0.30)
const ROOF_BROWN: Color = Color(0.45, 0.30, 0.22)
const GLASS: Color = Color(0.55, 0.78, 0.90)
const GLASS_DARK: Color = Color(0.30, 0.48, 0.62)
const GOLD: Color = Color(0.95, 0.75, 0.25)
const SOLAR: Color = Color(0.18, 0.26, 0.45)
const TURF_MAT: Color = Color(0.30, 0.62, 0.26)
const AWNING_B: Color = Color(0.98, 0.96, 0.90)

var wall: Color = WALL_CREAM
var wall_alt: Color = WALL_WHITE
var roof: Color = ROOF_RED
var trim: Color = WALL_WHITE
var accent: Color = MHPalette.FLAG_RED
var accent_b: Color = MHPalette.FLAG_WHITE
var glass: Color = GLASS
var base: Color = MHPalette.STONE_LIGHT
var door: Color = MHPalette.WOOD_DARK


## Theme for a building id and spec (0 or 1; anything else counts as 0).
static func make(id: String, spec: int) -> MHBuildingTheme:
	var t: MHBuildingTheme = MHBuildingTheme.new()
	var s: int = 1 if spec == 1 else 0
	match id:
		"clubhouse":
			t.wall = WALL_CREAM
			t.roof = ROOF_RED if s == 0 else ROOF_SLATE
			t.accent = MHPalette.FLAG_RED if s == 0 else MHPalette.TEE_BLUE
		"pro_shop":
			t.wall = WALL_SAND
			t.wall_alt = WALL_CREAM
			t.roof = ROOF_GREEN if s == 0 else ROOF_BLUE
			t.accent = MHPalette.FLAG_YELLOW if s == 0 else MHPalette.FLAG_RED
		"driving_range":
			t.wall = WALL_GREY
			t.wall_alt = WALL_WHITE
			t.roof = ROOF_GREEN if s == 0 else ROOF_SLATE
			t.accent = MHPalette.FLAG_YELLOW if s == 0 else MHPalette.FLAG_RED
		"restaurant":
			t.wall = WALL_CREAM
			t.wall_alt = WALL_BRICK
			t.roof = ROOF_TERRACOTTA if s == 0 else ROOF_BROWN
			t.accent = MHPalette.FLAG_RED if s == 0 else MHPalette.CART_ACCENT
		"pool_spa":
			t.wall = WALL_WHITE
			t.wall_alt = WALL_SKY
			t.roof = ROOF_BLUE if s == 0 else ROOF_GREEN
			t.accent = MHPalette.WATER if s == 0 else MHPalette.FLAG_YELLOW
		"cart_barn":
			t.wall = WALL_BARN if s == 0 else WALL_SAGE
			t.wall_alt = WALL_WHITE
			t.roof = MHPalette.METAL if s == 0 else MHPalette.METAL_DARK
			t.accent = MHPalette.CART_ACCENT
		"maintenance":
			t.wall = WALL_SAGE if s == 0 else WALL_GREY
			t.wall_alt = WALL_GREY
			t.roof = MHPalette.METAL_DARK
			t.accent = MHPalette.FLAG_YELLOW
		"lodging":
			t.wall = WALL_TIMBER if s == 0 else WALL_CREAM
			t.wall_alt = WALL_CREAM
			t.roof = ROOF_SLATE if s == 0 else ROOF_BROWN
			t.accent = MHPalette.FLAG_RED if s == 0 else MHPalette.TEE_BLUE
		"homes":
			t.wall = WALL_SKY if s == 0 else WALL_SAND
			t.wall_alt = WALL_WHITE
			t.roof = ROOF_TERRACOTTA if s == 0 else ROOF_SLATE
			t.accent = MHPalette.CART_ACCENT if s == 0 else MHPalette.FLAG_RED
		"landmark":
			t.wall = MHPalette.STONE_LIGHT
			t.wall_alt = WALL_WHITE
			t.roof = ROOF_GREEN if s == 0 else ROOF_BLUE
			t.accent = MHPalette.FLAG_RED if s == 0 else MHPalette.FLAG_YELLOW
		_:
			pass
	t.base = MHPalette.STONE_LIGHT
	return t

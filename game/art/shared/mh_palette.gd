class_name MHPalette
extends RefCounted
## Warm, friendly golf-country palette. Day only (DEC-005). All values are sRGB and are meant to be
## used as vertex colours through MHArtMaterials (which marks vertex colours as sRGB).
## Pure data plus small colour helpers; no engine state, safe to call from tests.

# Ground
const GRASS_LIGHT: Color = Color(0.58, 0.80, 0.32)
const GRASS: Color = Color(0.42, 0.69, 0.27)
const GRASS_DARK: Color = Color(0.28, 0.54, 0.24)
const ROUGH: Color = Color(0.47, 0.60, 0.25)
const SAND: Color = Color(0.95, 0.87, 0.62)
const SAND_SHADE: Color = Color(0.85, 0.74, 0.50)
const DIRT: Color = Color(0.56, 0.41, 0.27)
const PATH_STONE: Color = Color(0.82, 0.75, 0.60)
const PATH_EDGE: Color = Color(0.68, 0.60, 0.46)
const WATER: Color = Color(0.30, 0.66, 0.82)
const WATER_DEEP: Color = Color(0.16, 0.45, 0.66)

# Wood and stone
const BARK: Color = Color(0.42, 0.29, 0.18)
const BARK_DARK: Color = Color(0.30, 0.20, 0.13)
const BIRCH_BARK: Color = Color(0.94, 0.92, 0.86)
const BIRCH_MARK: Color = Color(0.22, 0.20, 0.19)
const PALM_BARK: Color = Color(0.62, 0.48, 0.32)
const WOOD_LIGHT: Color = Color(0.76, 0.56, 0.34)
const WOOD_DARK: Color = Color(0.48, 0.32, 0.19)
const STONE_LIGHT: Color = Color(0.72, 0.71, 0.68)
const STONE_DARK: Color = Color(0.48, 0.48, 0.47)
const MOSS: Color = Color(0.40, 0.55, 0.28)

# Foliage
const PINE_LOW: Color = Color(0.14, 0.38, 0.22)
const PINE_HIGH: Color = Color(0.26, 0.55, 0.30)
const OAK_LOW: Color = Color(0.25, 0.50, 0.20)
const OAK_HIGH: Color = Color(0.46, 0.72, 0.28)
const BIRCH_LOW: Color = Color(0.50, 0.72, 0.26)
const BIRCH_HIGH: Color = Color(0.76, 0.88, 0.36)
const PALM_LOW: Color = Color(0.20, 0.55, 0.28)
const PALM_HIGH: Color = Color(0.45, 0.75, 0.32)
const BUSH_LOW: Color = Color(0.22, 0.48, 0.22)
const BUSH_HIGH: Color = Color(0.40, 0.66, 0.28)
const REED: Color = Color(0.62, 0.68, 0.30)
const REED_TIP: Color = Color(0.80, 0.78, 0.40)
const CATTAIL_HEAD: Color = Color(0.45, 0.27, 0.15)
const TALL_GRASS_LOW: Color = Color(0.50, 0.65, 0.24)
const TALL_GRASS_HIGH: Color = Color(0.86, 0.80, 0.42)
const COCONUT: Color = Color(0.40, 0.28, 0.16)

# Accents
const FLAG_RED: Color = Color(0.91, 0.22, 0.20)
const FLAG_YELLOW: Color = Color(1.00, 0.80, 0.18)
const FLAG_WHITE: Color = Color(0.98, 0.98, 0.95)
const BALL_WHITE: Color = Color(0.99, 0.99, 0.97)
const CUP_DARK: Color = Color(0.10, 0.10, 0.10)
const CUP_RIM: Color = Color(0.92, 0.92, 0.90)
const TEE_WHITE: Color = Color(0.97, 0.97, 0.94)
const TEE_YELLOW: Color = Color(0.98, 0.80, 0.20)
const TEE_BLUE: Color = Color(0.20, 0.42, 0.85)
const TEE_RED: Color = Color(0.88, 0.22, 0.20)
const TEE_BLACK: Color = Color(0.12, 0.12, 0.13)
const SIGN_GREEN: Color = Color(0.14, 0.38, 0.24)
const SIGN_CREAM: Color = Color(0.98, 0.94, 0.80)
const METAL: Color = Color(0.62, 0.65, 0.68)
const METAL_DARK: Color = Color(0.32, 0.34, 0.37)
const CART_BODY: Color = Color(0.96, 0.96, 0.92)
const CART_ACCENT: Color = Color(0.18, 0.50, 0.32)
const RUBBER: Color = Color(0.16, 0.16, 0.17)
const CANVAS_WHITE: Color = Color(0.97, 0.95, 0.90)
const BLACK_TEXT: Color = Color(0.09, 0.09, 0.10)
const WHITE_TEXT: Color = Color(0.98, 0.98, 0.98)

# Sky and light (one directional light, ambient fill)
const SKY_TOP: Color = Color(0.36, 0.60, 0.92)
const SKY_HORIZON: Color = Color(0.80, 0.90, 0.98)
const SKY_GROUND: Color = Color(0.55, 0.66, 0.50)
const SUN: Color = Color(1.00, 0.95, 0.84)
const AMBIENT: Color = Color(0.64, 0.74, 0.88)

const FLOWERS: Array = [
	Color(0.98, 0.86, 0.20),
	Color(0.95, 0.42, 0.55),
	Color(0.96, 0.96, 0.96),
	Color(0.62, 0.45, 0.85),
	Color(0.98, 0.58, 0.20),
	Color(0.40, 0.62, 0.95),
]

const SKIN_TONES: Array = [
	Color(0.99, 0.87, 0.75),
	Color(0.94, 0.76, 0.60),
	Color(0.85, 0.64, 0.46),
	Color(0.71, 0.50, 0.34),
	Color(0.54, 0.36, 0.24),
	Color(0.38, 0.25, 0.17),
]

const HAIR_COLORS: Array = [
	Color(0.10, 0.08, 0.07),
	Color(0.25, 0.16, 0.10),
	Color(0.45, 0.28, 0.14),
	Color(0.72, 0.50, 0.22),
	Color(0.90, 0.78, 0.45),
	Color(0.62, 0.22, 0.12),
	Color(0.72, 0.72, 0.72),
]

const OUTFIT_COLORS: Array = [
	Color(0.90, 0.30, 0.28),
	Color(0.20, 0.45, 0.80),
	Color(0.96, 0.78, 0.22),
	Color(0.22, 0.62, 0.42),
	Color(0.96, 0.96, 0.94),
	Color(0.90, 0.50, 0.70),
	Color(0.95, 0.60, 0.20),
	Color(0.42, 0.30, 0.65),
]

const TROUSER_COLORS: Array = [
	Color(0.90, 0.86, 0.74),
	Color(0.25, 0.30, 0.42),
	Color(0.55, 0.55, 0.52),
	Color(0.96, 0.96, 0.94),
	Color(0.36, 0.42, 0.30),
]

const UMBRELLA_COLORS: Array = [
	Color(0.91, 0.22, 0.20),
	Color(0.98, 0.80, 0.20),
	Color(0.20, 0.45, 0.80),
	Color(0.22, 0.62, 0.42),
]


## Relative luminance per WCAG 2.x (sRGB input).
static func luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


static func _lin(v: float) -> float:
	if v <= 0.04045:
		return v / 12.92
	return pow((v + 0.055) / 1.055, 2.4)


## WCAG contrast ratio, 1.0 (identical) to 21.0 (black on white).
static func contrast_ratio(a: Color, b: Color) -> float:
	var la: float = luminance(a)
	var lb: float = luminance(b)
	var hi: float = maxf(la, lb)
	var lo: float = minf(la, lb)
	return (hi + 0.05) / (lo + 0.05)


## True when `fg` is easy enough to pick out on `bg`. Objects on grass use a small minimum (1.5),
## text on signs should use 4.5.
static func has_contrast(fg: Color, bg: Color, min_ratio: float) -> bool:
	return contrast_ratio(fg, bg) >= min_ratio


## Black or white text, whichever reads better on `bg`.
static func text_on(bg: Color) -> Color:
	if contrast_ratio(BLACK_TEXT, bg) >= contrast_ratio(WHITE_TEXT, bg):
		return BLACK_TEXT
	return WHITE_TEXT


## Multiply RGB by `factor` (below 1 darkens). Alpha is kept.
static func shade(c: Color, factor: float) -> Color:
	return Color(clampf(c.r * factor, 0.0, 1.0), clampf(c.g * factor, 0.0, 1.0),
		clampf(c.b * factor, 0.0, 1.0), c.a)


## Deterministic small colour drift for variety. `amount` about 0.05; `n` in [-1, 1].
static func drift(c: Color, n: float, amount: float) -> Color:
	return shade(c, 1.0 + n * amount)


## Pick from a colour list by index, wrapping. Negative indices wrap too.
static func pick(list: Array, index: int) -> Color:
	var n: int = list.size()
	if n == 0:
		return Color(1.0, 0.0, 1.0)
	return list[((index % n) + n) % n] as Color

class_name MHGolferLook
extends RefCounted
## Appearance of one low-poly golfer: colours, hair or hat style, height and build. Pure data, no engine
## state. `from_seed` is deterministic (same seed, same golfer, on every platform) and draws from the
## shared MHPalette lists, so crowds get colour variety without any texture.

const HAIR_SHORT: int = 0
const HAIR_LONG: int = 1
const HAT_CAP: int = 2
const HAT_SUN: int = 3
const STYLE_COUNT: int = 4

const SHOE_COLORS: Array = [
	Color(0.96, 0.96, 0.94),
	Color(0.20, 0.20, 0.22),
	Color(0.55, 0.40, 0.28),
	Color(0.85, 0.85, 0.80),
]

var skin: Color = Color(0.94, 0.76, 0.60)
var hair: Color = Color(0.25, 0.16, 0.10)
var hair_style: int = HAIR_SHORT
var shirt: Color = Color(0.20, 0.45, 0.80)
var trousers: Color = Color(0.90, 0.86, 0.74)
var shoes: Color = Color(0.96, 0.96, 0.94)
var hat: Color = Color(0.96, 0.96, 0.94)
## Uniform scale of the whole figure (1.0 is about 1.83 m tall).
var height: float = 1.0
## Torso width multiplier (1.0 average).
var build: float = 1.0


static func from_seed(seed_value: int) -> MHGolferLook:
	var rng: MHArtRng = MHArtRng.new(seed_value * 7727 + 31337)
	var look: MHGolferLook = MHGolferLook.new()
	look.skin = MHPalette.pick(MHPalette.SKIN_TONES, rng.range_int(MHPalette.SKIN_TONES.size()))
	look.hair = MHPalette.pick(MHPalette.HAIR_COLORS, rng.range_int(MHPalette.HAIR_COLORS.size()))
	look.hair_style = rng.range_int(STYLE_COUNT)
	var shirt_index: int = rng.range_int(MHPalette.OUTFIT_COLORS.size())
	look.shirt = MHPalette.pick(MHPalette.OUTFIT_COLORS, shirt_index)
	look.trousers = MHPalette.pick(MHPalette.TROUSER_COLORS, rng.range_int(MHPalette.TROUSER_COLORS.size()))
	look.shoes = MHPalette.pick(SHOE_COLORS, rng.range_int(SHOE_COLORS.size()))
	# Hat colour is never the shirt colour, so a cap reads against the body.
	look.hat = MHPalette.pick(MHPalette.OUTFIT_COLORS, shirt_index + 1 + rng.range_int(MHPalette.OUTFIT_COLORS.size() - 1))
	look.height = 0.92 + rng.range_f(0.0, 0.16)
	look.build = 0.9 + rng.range_f(0.0, 0.25)
	return look


## Small integer fingerprint (colours quantised to 1/255) for mesh caches and tests.
func key() -> int:
	var h: int = 2166136261
	var cols: Array = [skin, hair, shirt, trousers, shoes, hat]
	for c: Variant in cols:
		var col: Color = c
		h = MHMeshBuilder._mix(h, int(roundf(col.r * 255.0)))
		h = MHMeshBuilder._mix(h, int(roundf(col.g * 255.0)))
		h = MHMeshBuilder._mix(h, int(roundf(col.b * 255.0)))
	h = MHMeshBuilder._mix(h, hair_style)
	h = MHMeshBuilder._mix(h, int(roundf(height * 1000.0)))
	h = MHMeshBuilder._mix(h, int(roundf(build * 1000.0)))
	return h

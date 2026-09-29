class_name MHSplatMap
extends RefCounted
## Paint layers, one texel per height sample, 11 surface types in the exact order of
## docs/spec/data/course.schema.json surface_layers (DEC-060):
## rough, fairway, first_cut, green, fringe, tee, bunker_sand, water, path, waste, dirt.
## Storage: LAYER_COUNT (11) bytes per texel, interleaved: byte index = texel * 11 + layer, where
## texel = y * samples_x + x. Weights are bytes 0..255 (need not sum to 255; the shader normalises).
## Rendering packs 3 RGBA8 splat textures: layer L goes to texture L / 4, channel L % 4
## (texture 0 = rough, fairway, first_cut, green; texture 1 = fringe, tee, bunker_sand, water;
## texture 2 = path, waste, dirt, unused channel A which stays 0).
## Painting is integer only. Edits made through paint_disc with an open MHStroke are undoable.

const LAYER_COUNT: int = 11
const TEXTURE_COUNT: int = 3
const LAYER_NAMES: Array = [
	"rough", "fairway", "first_cut", "green", "fringe", "tee",
	"bunker_sand", "water", "path", "waste", "dirt",
]

enum Layer {
	ROUGH = 0, FAIRWAY = 1, FIRST_CUT = 2, GREEN = 3, FRINGE = 4, TEE = 5,
	BUNKER_SAND = 6, WATER = 7, PATH = 8, WASTE = 9, DIRT = 10,
}

var samples_x: int = 0
var samples_y: int = 0
var bytes: PackedByteArray = PackedByteArray()
## Scratch flags, one per texel, used by MHStroke to record each texel once per stroke.
## Always all zero between strokes.
var stroke_mark: PackedByteArray = PackedByteArray()


func _init(p_samples_x: int = 513, p_samples_y: int = 513) -> void:
	samples_x = p_samples_x
	samples_y = p_samples_y
	bytes.resize(samples_x * samples_y * LAYER_COUNT)
	fill_layer(Layer.ROUGH)


## Schema name for a layer index, or "" if out of range.
static func layer_name(layer: int) -> String:
	if layer < 0 or layer >= LAYER_COUNT:
		return ""
	return LAYER_NAMES[layer]


## Layer index for a schema name, or -1.
static func layer_from_name(layer_name_str: String) -> int:
	for i in range(LAYER_COUNT):
		if LAYER_NAMES[i] == layer_name_str:
			return i
	return -1


## Maps a save format v1 layer (0 fairway, 1 rough, 2 sand, 3 green) to the current layer index.
static func legacy_layer_to_layer(old_layer: int) -> int:
	if old_layer == 0:
		return Layer.FAIRWAY
	if old_layer == 1:
		return Layer.ROUGH
	if old_layer == 2:
		return Layer.BUNKER_SAND
	if old_layer == 3:
		return Layer.GREEN
	return -1


## Builds a map from v1 RGBA bytes (4 per texel: R fairway, G rough, B sand, A green).
static func from_legacy_rgba(p_samples_x: int, p_samples_y: int, rgba: PackedByteArray) -> MHSplatMap:
	var m := MHSplatMap.new(p_samples_x, p_samples_y)
	var n: int = p_samples_x * p_samples_y
	var out := PackedByteArray()
	out.resize(n * LAYER_COUNT)
	for i in range(n):
		out[i * LAYER_COUNT + Layer.FAIRWAY] = rgba[i * 4]
		out[i * LAYER_COUNT + Layer.ROUGH] = rgba[i * 4 + 1]
		out[i * LAYER_COUNT + Layer.BUNKER_SAND] = rgba[i * 4 + 2]
		out[i * LAYER_COUNT + Layer.GREEN] = rgba[i * 4 + 3]
	m.bytes = out
	return m


func texel_count() -> int:
	return samples_x * samples_y


func fill_layer(layer: int) -> void:
	bytes.fill(0)
	if layer < 0 or layer >= LAYER_COUNT:
		return
	for i in range(samples_x * samples_y):
		bytes[i * LAYER_COUNT + layer] = 255


func get_weight(x: int, y: int, layer: int) -> int:
	return bytes[(y * samples_x + x) * LAYER_COUNT + layer]


func ensure_stroke_marks() -> void:
	if stroke_mark.size() != samples_x * samples_y:
		stroke_mark = PackedByteArray()
		stroke_mark.resize(samples_x * samples_y)


## FNV-1a 32 over all splat bytes in storage order.
func hash_fnv1a() -> int:
	var h: int = MHHeightGrid.FNV_OFFSET
	for i in range(bytes.size()):
		h = ((h ^ bytes[i]) * MHHeightGrid.FNV_PRIME) & 0xFFFFFFFF
	return h


## Value for texture `plane` (0..2), channel `channel` (0..3) at a texel; 0 for the unused channel.
func get_packed(texel: int, plane: int, channel: int) -> int:
	var layer: int = plane * 4 + channel
	if layer >= LAYER_COUNT:
		return 0
	return bytes[texel * LAYER_COUNT + layer]


## Paints a disc toward a one-hot target. strength_per_mille 0..1000. Returns the touched rect.
## If stroke is not null, every changed texel is recorded (first-touch old value) before writing.
@warning_ignore("integer_division")
func paint_disc(cx: int, cy: int, radius: int, layer: int, strength_per_mille: int,
		stroke: MHStroke = null) -> Rect2i:
	if layer < 0 or layer >= LAYER_COUNT:
		return Rect2i()
	var r: int = maxi(radius, 1)
	var x0: int = maxi(cx - r, 0)
	var x1: int = mini(cx + r, samples_x - 1)
	var y0: int = maxi(cy - r, 0)
	var y1: int = mini(cy + r, samples_y - 1)
	if x0 > x1 or y0 > y1:
		return Rect2i()
	var table: PackedInt32Array = MHBrush.falloff_table()
	var r2: int = r * r
	var nv := PackedInt32Array()
	nv.resize(LAYER_COUNT)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d2: int = (x - cx) * (x - cx) + (y - cy) * (y - cy)
			if d2 > r2:
				continue
			var w: int = table[((r2 - d2) * 1024) / r2]
			if w == 0:
				continue
			var texel: int = y * samples_x + x
			var o: int = texel * LAYER_COUNT
			var changed: bool = false
			for c in range(LAYER_COUNT):
				var cur: int = bytes[o + c]
				var target: int = 255 if c == layer else 0
				var delta: int = MHBrush.idiv((target - cur) * w * strength_per_mille, 1024000)
				var v: int = clampi(cur + delta, 0, 255)
				nv[c] = v
				if v != cur:
					changed = true
			if not changed:
				continue
			if stroke != null:
				stroke.touch_splat(self, texel)
			for c in range(LAYER_COUNT):
				bytes[o + c] = nv[c]
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)

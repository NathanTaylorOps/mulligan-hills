class_name MHSplatMap
extends RefCounted
## RGBA8 paint layers, one texel per height sample. Channel meaning:
## R fairway, G rough, B sand, A green. Weights are bytes 0..255 (not required to sum to 255;
## the shader normalises). Painting is integer only. Phase 0: splat edits are NOT in the undo stack.

enum Layer { FAIRWAY = 0, ROUGH = 1, SAND = 2, GREEN = 3 }

var samples_x: int = 0
var samples_y: int = 0
var bytes: PackedByteArray = PackedByteArray()


func _init(p_samples_x: int = 513, p_samples_y: int = 513) -> void:
	samples_x = p_samples_x
	samples_y = p_samples_y
	bytes.resize(samples_x * samples_y * 4)
	fill_layer(Layer.ROUGH)


func fill_layer(layer: int) -> void:
	for i in range(samples_x * samples_y):
		for c in range(4):
			bytes[i * 4 + c] = 255 if c == layer else 0


func get_weight(x: int, y: int, layer: int) -> int:
	return bytes[(y * samples_x + x) * 4 + layer]


## Paints a disc toward a one-hot target. strength_per_mille 0..1000. Returns the touched rect.
@warning_ignore("integer_division")
func paint_disc(cx: int, cy: int, radius: int, layer: int, strength_per_mille: int) -> Rect2i:
	var r: int = maxi(radius, 1)
	var x0: int = maxi(cx - r, 0)
	var x1: int = mini(cx + r, samples_x - 1)
	var y0: int = maxi(cy - r, 0)
	var y1: int = mini(cy + r, samples_y - 1)
	if x0 > x1 or y0 > y1:
		return Rect2i()
	var table: PackedInt32Array = MHBrush.falloff_table()
	var r2: int = r * r
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d2: int = (x - cx) * (x - cx) + (y - cy) * (y - cy)
			if d2 > r2:
				continue
			var w: int = table[((r2 - d2) * 1024) / r2]
			if w == 0:
				continue
			var o: int = (y * samples_x + x) * 4
			for c in range(4):
				var cur: int = bytes[o + c]
				var target: int = 255 if c == layer else 0
				var delta: int = MHBrush.idiv((target - cur) * w * strength_per_mille, 1024000)
				bytes[o + c] = clampi(cur + delta, 0, 255)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)

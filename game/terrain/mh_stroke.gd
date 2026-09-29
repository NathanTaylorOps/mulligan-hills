class_name MHStroke
extends RefCounted
## Diff of one brush stroke: per changed cell, the value before the stroke and after it.
## touch() records the pre-stroke value on first touch of a cell (using grid.stroke_mark).

var indices: PackedInt32Array = PackedInt32Array()
var old_h: PackedInt32Array = PackedInt32Array()
var new_h: PackedInt32Array = PackedInt32Array()
## Splat diff: per changed texel the LAYER_COUNT bytes before and after (texel-major).
var s_indices: PackedInt32Array = PackedInt32Array()
var s_old: PackedByteArray = PackedByteArray()
var s_new: PackedByteArray = PackedByteArray()
var flatten_level_mm: int = 0
var has_level: bool = false
var dab_count: int = 0
var is_open: bool = true
var min_x: int = 1 << 30
var min_y: int = 1 << 30
var max_x: int = -1
var max_y: int = -1


@warning_ignore("integer_division")
func touch(grid: MHHeightGrid, idx: int) -> void:
	if grid.stroke_mark[idx] != 0:
		return
	grid.stroke_mark[idx] = 1
	indices.append(idx)
	old_h.append(grid.heights[idx])
	var x: int = idx % grid.samples_x
	var y: int = idx / grid.samples_x
	min_x = mini(min_x, x)
	min_y = mini(min_y, y)
	max_x = maxi(max_x, x)
	max_y = maxi(max_y, y)


## Records the pre-stroke splat bytes of a texel on first touch (uses splat.stroke_mark).
@warning_ignore("integer_division")
func touch_splat(splat: MHSplatMap, texel: int) -> void:
	if splat.stroke_mark[texel] != 0:
		return
	splat.stroke_mark[texel] = 1
	s_indices.append(texel)
	var o: int = texel * MHSplatMap.LAYER_COUNT
	for c in range(MHSplatMap.LAYER_COUNT):
		s_old.append(splat.bytes[o + c])
	var x: int = texel % splat.samples_x
	var y: int = texel / splat.samples_x
	min_x = mini(min_x, x)
	min_y = mini(min_y, y)
	max_x = maxi(max_x, x)
	max_y = maxi(max_y, y)


## Closes the stroke: drops cells whose value ended up unchanged, captures new values, clears marks.
## splat may be null only if the stroke recorded no splat texels.
func finalize(grid: MHHeightGrid, splat: MHSplatMap = null) -> void:
	_finalize_splat(splat)
	var ki := PackedInt32Array()
	var ko := PackedInt32Array()
	var kn := PackedInt32Array()
	for k in range(indices.size()):
		var i: int = indices[k]
		grid.stroke_mark[i] = 0
		var cur: int = grid.heights[i]
		if cur != old_h[k]:
			ki.append(i)
			ko.append(old_h[k])
			kn.append(cur)
	indices = ki
	old_h = ko
	new_h = kn
	is_open = false


func _finalize_splat(splat: MHSplatMap) -> void:
	if splat == null:
		s_indices = PackedInt32Array()
		s_old = PackedByteArray()
		s_new = PackedByteArray()
		return
	var lc: int = MHSplatMap.LAYER_COUNT
	var ki := PackedInt32Array()
	var ko := PackedByteArray()
	var kn := PackedByteArray()
	for k in range(s_indices.size()):
		var t: int = s_indices[k]
		splat.stroke_mark[t] = 0
		var same: bool = true
		for c in range(lc):
			if splat.bytes[t * lc + c] != s_old[k * lc + c]:
				same = false
				break
		if not same:
			ki.append(t)
			for c in range(lc):
				ko.append(s_old[k * lc + c])
				kn.append(splat.bytes[t * lc + c])
	s_indices = ki
	s_old = ko
	s_new = kn


## Restores every touched cell to its pre-stroke value and clears marks. Leaves no residue.
func rollback(grid: MHHeightGrid, splat: MHSplatMap = null) -> void:
	if splat != null:
		var lc: int = MHSplatMap.LAYER_COUNT
		for k in range(s_indices.size()):
			var t: int = s_indices[k]
			for c in range(lc):
				splat.bytes[t * lc + c] = s_old[k * lc + c]
			splat.stroke_mark[t] = 0
	s_indices = PackedInt32Array()
	s_old = PackedByteArray()
	s_new = PackedByteArray()
	for k in range(indices.size()):
		grid.heights[indices[k]] = old_h[k]
		grid.stroke_mark[indices[k]] = 0
	indices = PackedInt32Array()
	old_h = PackedInt32Array()
	new_h = PackedInt32Array()
	is_open = false


func apply_old(grid: MHHeightGrid, splat: MHSplatMap = null) -> void:
	for k in range(indices.size()):
		grid.heights[indices[k]] = old_h[k]
	_write_splat(splat, s_old)


func apply_new(grid: MHHeightGrid, splat: MHSplatMap = null) -> void:
	for k in range(indices.size()):
		grid.heights[indices[k]] = new_h[k]
	_write_splat(splat, s_new)


func _write_splat(splat: MHSplatMap, src: PackedByteArray) -> void:
	if splat == null:
		return
	var lc: int = MHSplatMap.LAYER_COUNT
	for k in range(s_indices.size()):
		var t: int = s_indices[k]
		for c in range(lc):
			splat.bytes[t * lc + c] = src[k * lc + c]


## Number of changed height cells plus changed splat texels.
func changed_count() -> int:
	return indices.size() + s_indices.size()


func height_changed_count() -> int:
	return indices.size()


func splat_changed_count() -> int:
	return s_indices.size()


## Approximate memory of the diff arrays (heights: 12 bytes per cell; splat: 4 + 2 * LAYER_COUNT per texel).
func byte_size() -> int:
	return indices.size() * 12 + s_indices.size() * (4 + 2 * MHSplatMap.LAYER_COUNT)


func bounds() -> Rect2i:
	if max_x < 0:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

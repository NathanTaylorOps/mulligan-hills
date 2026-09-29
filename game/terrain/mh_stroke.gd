class_name MHStroke
extends RefCounted
## Diff of one brush stroke: per changed cell, the value before the stroke and after it.
## touch() records the pre-stroke value on first touch of a cell (using grid.stroke_mark).

var indices: PackedInt32Array = PackedInt32Array()
var old_h: PackedInt32Array = PackedInt32Array()
var new_h: PackedInt32Array = PackedInt32Array()
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


## Closes the stroke: drops cells whose value ended up unchanged, captures new values, clears marks.
func finalize(grid: MHHeightGrid) -> void:
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


## Restores every touched cell to its pre-stroke value and clears marks. Leaves no residue.
func rollback(grid: MHHeightGrid) -> void:
	for k in range(indices.size()):
		grid.heights[indices[k]] = old_h[k]
		grid.stroke_mark[indices[k]] = 0
	indices = PackedInt32Array()
	old_h = PackedInt32Array()
	new_h = PackedInt32Array()
	is_open = false


func apply_old(grid: MHHeightGrid) -> void:
	for k in range(indices.size()):
		grid.heights[indices[k]] = old_h[k]


func apply_new(grid: MHHeightGrid) -> void:
	for k in range(indices.size()):
		grid.heights[indices[k]] = new_h[k]


func changed_count() -> int:
	return indices.size()


## Approximate memory of the diff arrays (4 bytes per int, three arrays).
func byte_size() -> int:
	return indices.size() * 12


func bounds() -> Rect2i:
	if max_x < 0:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

class_name MHHeightGrid
extends RefCounted
## Authoritative integer heightmap. Heights are int16 millimetres stored in a
## PackedInt32Array (4 bytes per sample for fast GDScript access; values are
## always kept inside [-32768, 32767]). The grid has (cells + 1) samples per axis,
## so 512x512 cells at 1 m means 513x513 samples. No floats anywhere in this class.

const MIN_H_MM: int = -32768
const MAX_H_MM: int = 32767
const FNV_OFFSET: int = 2166136261
const FNV_PRIME: int = 16777619

var cells_x: int = 0
var cells_y: int = 0
var samples_x: int = 0
var samples_y: int = 0
var cell_size_mm: int = 1000
var heights: PackedInt32Array = PackedInt32Array()
## Scratch flags used by MHStroke to record each cell once per stroke. Always all zero
## between strokes. Lives here so no packed array is ever aliased between objects.
var stroke_mark: PackedByteArray = PackedByteArray()


func _init(p_cells_x: int = 512, p_cells_y: int = 512, p_cell_size_mm: int = 1000) -> void:
	cells_x = maxi(p_cells_x, 1)
	cells_y = maxi(p_cells_y, 1)
	cell_size_mm = maxi(p_cell_size_mm, 1)
	samples_x = cells_x + 1
	samples_y = cells_y + 1
	heights.resize(samples_x * samples_y)


func sample_count() -> int:
	return samples_x * samples_y


func idx(x: int, y: int) -> int:
	return y * samples_x + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < samples_x and y < samples_y


func get_h(x: int, y: int) -> int:
	return heights[y * samples_x + x]


func get_h_clamped(x: int, y: int) -> int:
	return heights[clampi(y, 0, samples_y - 1) * samples_x + clampi(x, 0, samples_x - 1)]


## Sets one sample (clamped to int16). Authoritative edits should go through MHBrush
## and a stroke so they are undoable; this is for setup and tests.
func set_h(x: int, y: int, value_mm: int) -> void:
	heights[y * samples_x + x] = clampi(value_mm, MIN_H_MM, MAX_H_MM)


func ensure_stroke_marks() -> void:
	if stroke_mark.size() != heights.size():
		stroke_mark = PackedByteArray()
		stroke_mark.resize(heights.size())


func fill(value_mm: int) -> void:
	var v: int = clampi(value_mm, MIN_H_MM, MAX_H_MM)
	for i in range(heights.size()):
		heights[i] = v


## Deterministic integer noise. Must stay identical to tools/reference/terrain/brush_ref.py.
func fill_lcg_noise(seed_value: int, amplitude_mm: int) -> void:
	var state: int = seed_value & 0x7FFFFFFF
	var span: int = 2 * amplitude_mm + 1
	for i in range(heights.size()):
		state = (state * 1103515245 + 12345) & 0x7FFFFFFF
		heights[i] = clampi(((state >> 8) % span) - amplitude_mm, MIN_H_MM, MAX_H_MM)


## FNV-1a 32 over each height as unsigned (h + 32768), low byte then high byte.
func hash_fnv1a() -> int:
	var h: int = FNV_OFFSET
	for i in range(heights.size()):
		var u: int = heights[i] + 32768
		h = ((h ^ (u & 255)) * FNV_PRIME) & 0xFFFFFFFF
		h = ((h ^ (u >> 8)) * FNV_PRIME) & 0xFFFFFFFF
	return h


func duplicate_grid() -> MHHeightGrid:
	var g := MHHeightGrid.new(cells_x, cells_y, cell_size_mm)
	g.heights = heights.duplicate()
	return g


func equals(other: MHHeightGrid) -> bool:
	return other != null and cells_x == other.cells_x and cells_y == other.cells_y \
		and cell_size_mm == other.cell_size_mm and heights == other.heights

class_name MHTerrainEditor
extends RefCounted
## Public editing API for the gesture workstream. Headless (no scene needed).
## Call order: begin_stroke() -> apply_brush_at(x, y) many times -> end_stroke() or cancel_stroke().
## Cell coordinates are integer height-sample coordinates (0..cells). The gesture layer converts
## a touch to a cell (MHPicking.pick) and passes the integer; only integers are authoritative.
## Rendering: connect cells_dirty or poll `dirty`, and call MHTerrainChunks.flush(dirty) once per frame.

signal stroke_began()
signal stroke_ended(changed_cells: int)
signal stroke_cancelled()
signal history_applied(is_undo: bool)
signal cells_dirty(rect: Rect2i)

const FLATTEN_AUTO: int = -2147483648

var grid: MHHeightGrid
var splat: MHSplatMap
var undo_stack: MHUndoStack
var dirty: MHDirtyTracker

var brush_mode: int = MHBrush.Mode.RAISE
var brush_radius: int = 8
## RAISE/LOWER: mm at brush centre per dab. SMOOTH/FLATTEN: per mille (0..1000).
var brush_strength: int = 100
## FLATTEN_AUTO = level is the height under the first dab of the stroke.
var flatten_level_mm: int = FLATTEN_AUTO

var _stroke: MHStroke = null


func _init(p_grid: MHHeightGrid, p_splat: MHSplatMap = null, p_chunk_size: int = 32) -> void:
	grid = p_grid
	splat = p_splat if p_splat != null else MHSplatMap.new(grid.samples_x, grid.samples_y)
	undo_stack = MHUndoStack.new()
	dirty = MHDirtyTracker.new(grid.samples_x, grid.samples_y, p_chunk_size)


func set_brush(mode: int, radius_cells: int, strength: int) -> void:
	brush_mode = mode
	brush_radius = maxi(radius_cells, 1)
	brush_strength = strength


func is_stroke_open() -> bool:
	return _stroke != null


func begin_stroke() -> bool:
	if _stroke != null:
		return false
	_stroke = undo_stack.begin(grid)
	if _stroke == null:
		return false
	stroke_began.emit()
	return true


func apply_brush_at(cell_x: int, cell_y: int) -> void:
	if _stroke == null:
		push_warning("MHTerrainEditor.apply_brush_at called with no open stroke; ignored")
		return
	var level: int = 0
	if brush_mode == MHBrush.Mode.FLATTEN:
		if not _stroke.has_level:
			if flatten_level_mm == FLATTEN_AUTO:
				_stroke.flatten_level_mm = grid.get_h_clamped(cell_x, cell_y)
			else:
				_stroke.flatten_level_mm = flatten_level_mm
			_stroke.has_level = true
		level = _stroke.flatten_level_mm
	var rect: Rect2i = MHBrush.apply_dab(grid, brush_mode, cell_x, cell_y, brush_radius,
			brush_strength, level, _stroke)
	_stroke.dab_count += 1
	_emit_dirty(rect)


## Convenience for fast drags: dabs along an integer line from the previous point to (x1, y1),
## every max(1, radius/2) cells, excluding the start point (already dabbed by the previous call).
@warning_ignore("integer_division")
func apply_brush_segment(x0: int, y0: int, x1: int, y1: int) -> void:
	var step: int = maxi(1, brush_radius / 2)
	var dist: int = maxi(absi(x1 - x0), absi(y1 - y0))
	var n: int = maxi(1, (dist + step - 1) / step)
	for k in range(1, n + 1):
		apply_brush_at(x0 + MHBrush.idiv((x1 - x0) * k, n), y0 + MHBrush.idiv((y1 - y0) * k, n))


## Returns the number of cells the stroke changed (0 = discarded, nothing to undo).
func end_stroke() -> int:
	if _stroke == null:
		return 0
	_stroke = null
	var s: MHStroke = undo_stack.commit(grid)
	var n: int = 0 if s == null else s.changed_count()
	stroke_ended.emit(n)
	return n


func cancel_stroke() -> void:
	if _stroke == null:
		return
	_stroke = null
	var r: Rect2i = undo_stack.cancel(grid)
	_emit_dirty(r)
	stroke_cancelled.emit()


func undo() -> bool:
	if _stroke != null:
		return false
	var s: MHStroke = undo_stack.undo(grid)
	if s == null:
		return false
	_emit_dirty(s.bounds())
	history_applied.emit(true)
	return true


func redo() -> bool:
	if _stroke != null:
		return false
	var s: MHStroke = undo_stack.redo(grid)
	if s == null:
		return false
	_emit_dirty(s.bounds())
	history_applied.emit(false)
	return true


## Not undoable in Phase 0.
func paint_splat_at(cell_x: int, cell_y: int, radius: int, layer: int, strength_per_mille: int) -> void:
	_emit_dirty(splat.paint_disc(cell_x, cell_y, radius, layer, strength_per_mille))


func mark_all_dirty() -> void:
	dirty.mark_all()


func _emit_dirty(rect: Rect2i) -> void:
	if rect.has_area():
		dirty.mark_rect(rect.position.x, rect.position.y, rect.end.x - 1, rect.end.y - 1)
		cells_dirty.emit(rect)

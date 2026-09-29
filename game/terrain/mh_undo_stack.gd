class_name MHUndoStack
extends RefCounted
## Undo/redo of finished strokes plus the lifecycle of the single open stroke.
## begin -> (dabs write via MHBrush with the open stroke) -> commit or cancel.
## cancel() rolls the grid back exactly and touches neither undo nor redo lists.
## An empty stroke (nothing changed) is discarded on commit and does not clear redo.

var max_strokes: int = 128
var max_bytes: int = 16 * 1024 * 1024

var _undo: Array[MHStroke] = []
var _redo: Array[MHStroke] = []
var _open: MHStroke = null
var _undo_bytes: int = 0


func has_open_stroke() -> bool:
	return _open != null


func open_stroke() -> MHStroke:
	return _open


func undo_count() -> int:
	return _undo.size()


func redo_count() -> int:
	return _redo.size()


func undo_bytes() -> int:
	return _undo_bytes


func begin(grid: MHHeightGrid) -> MHStroke:
	if _open != null:
		return null
	grid.ensure_stroke_marks()
	_open = MHStroke.new()
	return _open


## Returns the committed stroke, or null if it changed nothing (or none was open).
func commit(grid: MHHeightGrid) -> MHStroke:
	if _open == null:
		return null
	var s: MHStroke = _open
	_open = null
	s.finalize(grid)
	if s.changed_count() == 0:
		return null
	_redo.clear()
	_undo.append(s)
	_undo_bytes += s.byte_size()
	_trim()
	return s


## Rolls back the open stroke. Returns the rolled-back rect (for dirty marking).
func cancel(grid: MHHeightGrid) -> Rect2i:
	if _open == null:
		return Rect2i()
	var s: MHStroke = _open
	_open = null
	var r: Rect2i = s.bounds()
	s.rollback(grid)
	return r


func undo(grid: MHHeightGrid) -> MHStroke:
	if _open != null or _undo.is_empty():
		return null
	var s: MHStroke = _undo.pop_back()
	_undo_bytes -= s.byte_size()
	s.apply_old(grid)
	_redo.append(s)
	return s


func redo(grid: MHHeightGrid) -> MHStroke:
	if _open != null or _redo.is_empty():
		return null
	var s: MHStroke = _redo.pop_back()
	s.apply_new(grid)
	_undo.append(s)
	_undo_bytes += s.byte_size()
	_trim()
	return s


func clear() -> void:
	_undo.clear()
	_redo.clear()
	_undo_bytes = 0


func _trim() -> void:
	while _undo.size() > max_strokes or (_undo_bytes > max_bytes and _undo.size() > 1):
		var old: MHStroke = _undo.pop_front()
		_undo_bytes -= old.byte_size()

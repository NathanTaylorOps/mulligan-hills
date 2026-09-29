class_name MHGate0TerrainSink
extends MHStrokeSink
## Adapter from the gesture layer (MHStrokeBridge) to MHTerrainEditor, with counters for the HUD.
## Consecutive dabs inside one stroke are joined by apply_brush_segment so fast drags leave no gaps.
## Chunk upload is NOT done here: the scene calls MHGate0TerrainApi.flush once per frame.

var editor: MHTerrainEditor
var strokes_begun: int = 0
var strokes_committed: int = 0
var strokes_cancelled: int = 0
var dabs: int = 0
var undos: int = 0
var redos: int = 0

var _has_last: bool = false
var _last_x: int = 0
var _last_y: int = 0


func _init(p_editor: MHTerrainEditor) -> void:
	editor = p_editor


func begin_stroke() -> void:
	_has_last = false
	if editor.begin_stroke():
		strokes_begun += 1


func apply_brush_at(cell_x: int, cell_y: int) -> void:
	if not editor.is_stroke_open():
		return
	if _has_last:
		editor.apply_brush_segment(_last_x, _last_y, cell_x, cell_y)
	else:
		editor.apply_brush_at(cell_x, cell_y)
	_has_last = true
	_last_x = cell_x
	_last_y = cell_y
	dabs += 1


func end_stroke() -> void:
	_has_last = false
	if not editor.is_stroke_open():
		return
	var changed: int = editor.end_stroke()
	if changed > 0:
		strokes_committed += 1


func cancel_stroke() -> void:
	_has_last = false
	if not editor.is_stroke_open():
		return
	editor.cancel_stroke()
	strokes_cancelled += 1


func undo() -> bool:
	var ok: bool = editor.undo()
	if ok:
		undos += 1
	return ok


func redo() -> bool:
	var ok: bool = editor.redo()
	if ok:
		redos += 1
	return ok


func counters_text() -> String:
	return "strokes ok/cancelled: %d/%d   undo stack: %d   redo stack: %d   dabs: %d" % [
		strokes_committed, strokes_cancelled, editor.undo_stack.undo_count(), editor.undo_stack.redo_count(), dabs]

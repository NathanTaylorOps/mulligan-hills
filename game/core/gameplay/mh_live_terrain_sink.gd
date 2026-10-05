class_name MHLiveTerrainSink
extends MHStrokeSink
## Gesture adapter. Fast dabs form one continuous undoable stroke; presentation uploads once per frame.
var editor: MHTerrainEditor
var _last: Vector2i = MHPicking.MISS

func _init(p_editor: MHTerrainEditor) -> void:
	editor = p_editor

func begin_stroke() -> void:
	_last = MHPicking.MISS
	editor.begin_stroke()

func apply_brush_at(x: int, y: int) -> void:
	if not editor.is_stroke_open():
		return
	if _last == MHPicking.MISS:
		editor.apply_brush_at(x, y)
	else:
		editor.apply_brush_segment(_last.x, _last.y, x, y)
	_last = Vector2i(x, y)

func end_stroke() -> void:
	_last = MHPicking.MISS
	editor.end_stroke()

func cancel_stroke() -> void:
	_last = MHPicking.MISS
	editor.cancel_stroke()

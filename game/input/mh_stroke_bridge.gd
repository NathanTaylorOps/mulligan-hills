class_name MHStrokeBridge
extends RefCounted
## Connects gesture stroke signals to an MHStrokeSink. screen_to_cell is a
## Callable(screen_pos: Vector2) -> Vector2i that returns NO_CELL when the
## ray misses the terrain. KEEP A REFERENCE to the bridge or the connections
## may be lost when it is freed.

const NO_CELL: Vector2i = Vector2i(-2147483648, -2147483648)

var sink: MHStrokeSink
var screen_to_cell: Callable


func _init(p_sink: MHStrokeSink, p_screen_to_cell: Callable, machine: MHGestureStateMachine) -> void:
	sink = p_sink
	screen_to_cell = p_screen_to_cell
	machine.stroke_started.connect(_on_started)
	machine.stroke_moved.connect(_on_moved)
	machine.stroke_ended.connect(_on_ended)
	machine.stroke_cancelled.connect(_on_cancelled)


func _apply(pos: Vector2) -> void:
	var cell: Vector2i = screen_to_cell.call(pos)
	if cell == NO_CELL:
		return
	sink.apply_brush_at(cell.x, cell.y)


func _on_started(pos: Vector2) -> void:
	sink.begin_stroke()
	_apply(pos)


func _on_moved(pos: Vector2) -> void:
	_apply(pos)


func _on_ended() -> void:
	sink.end_stroke()


func _on_cancelled() -> void:
	sink.cancel_stroke()

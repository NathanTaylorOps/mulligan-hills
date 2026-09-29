class_name MHForwardingStrokeSink
extends MHStrokeSink
## Forwards to any object exposing the four terrain methods, using dynamic
## calls so this file does not depend on the terrain workstream's class names.

var _target: Object


func _init(target: Object) -> void:
	_target = target


func begin_stroke() -> void:
	_target.call("begin_stroke")


func apply_brush_at(cell_x: int, cell_y: int) -> void:
	_target.call("apply_brush_at", cell_x, cell_y)


func end_stroke() -> void:
	_target.call("end_stroke")


func cancel_stroke() -> void:
	_target.call("cancel_stroke")

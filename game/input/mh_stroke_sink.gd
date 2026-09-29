class_name MHStrokeSink
extends RefCounted
## Adapter interface between input and the terrain workstream.
## The terrain API is begin_stroke(), apply_brush_at(cell_x, cell_y),
## end_stroke(), cancel_stroke(). cancel_stroke() MUST roll back everything
## painted since begin_stroke(). Base methods are no-ops; override them.

func begin_stroke() -> void:
	pass


func apply_brush_at(_cell_x: int, _cell_y: int) -> void:
	pass


func end_stroke() -> void:
	pass


func cancel_stroke() -> void:
	pass

class_name MHMockStrokeSink
extends MHStrokeSink
## Records calls so tests can assert what the terrain would have received.

var calls: Array[String] = []


func begin_stroke() -> void:
	calls.append("begin")


func apply_brush_at(cell_x: int, cell_y: int) -> void:
	calls.append("apply(%d,%d)" % [cell_x, cell_y])


func end_stroke() -> void:
	calls.append("end")


func cancel_stroke() -> void:
	calls.append("cancel")

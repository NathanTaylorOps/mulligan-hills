class_name MHBuildingPlacementInput
extends Node
## Captures pointer/touch only while MHLiveConstruction is in building placement mode.

var live: MHLiveConstruction

func _unhandled_input(event: InputEvent) -> void:
	if live == null or live._placement_id == "" or live.shell == null or live.shell.modal_id() != "":
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		live.rotate_building_preview()
		var mouse: Vector2 = live.get_viewport().get_mouse_position()
		_preview(mouse)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_preview(event.position)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_preview(event.position)
		live.confirm_building_preview()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch and event.pressed:
		_preview(event.position)
		live.confirm_building_preview()
		get_viewport().set_input_as_handled()


func _preview(screen_pos: Vector2) -> void:
	var cell: Vector2i = live._pick(screen_pos)
	if cell.x < 0 or cell.y < 0:
		return
	var mm: int = live.editor.grid.cell_size_mm
	live._placement_preview(Vector2(float(cell.x * mm) / 1000.0, float(cell.y * mm) / 1000.0))

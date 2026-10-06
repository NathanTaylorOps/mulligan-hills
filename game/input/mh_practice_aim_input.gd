class_name MHPracticeAimInput
extends Node
## Added after the UI layer: reverse-depth input order records all contacts, including UI-owned ones,
## before MHTouchBridge consumes them. Only world contacts are consumed here.
var panel: MHOneHolePanel
var taps: MHAimTap = MHAimTap.new()

func _input(event: InputEvent) -> void:
	if panel == null or not panel.is_visible_in_tree() or panel.live.shell.modal_id() != "" \
		or panel.live.shell.current_screen_id() != MHScreenIds.HUD:
		taps.clear()
		return
	var pos: Vector2
	var id: int
	var pressed: bool
	var released: bool = false
	var cancelled: bool = false
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		pos = t.position
		id = t.index
		pressed = t.pressed
		released = not pressed
		cancelled = t.canceled
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if taps.drag(d.index, d.position):
			get_viewport().set_input_as_handled()
		return
	elif event is InputEventMouseButton:
		var m: InputEventMouseButton = event
		if m.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = m.position
		id = -1
		pressed = m.pressed
		released = not pressed
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if taps.drag(-1, motion.position):
			get_viewport().set_input_as_handled()
		return
	else:
		return
	var blocked: bool = panel.blocks_world_tap(pos)
	if pressed:
		if taps.down(id, pos, blocked):
			get_viewport().set_input_as_handled()
	elif released:
		var result: Dictionary = taps.up(id, pos, blocked, cancelled)
		if bool(result["consume"]):
			get_viewport().set_input_as_handled()
		if bool(result["aim"]):
			if panel._preview_draft:
				panel.craft_from_screen(pos)
			else:
				panel.aim_from_screen(pos)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		taps.clear()

class_name MHPracticeAimInput
extends Node
## Input owner for the exact one-hole preview/practice view.
##
## Draft editing:
## - desktop: left click/drag paints, right-drag rotates, middle-drag pans, wheel zooms;
## - touch: one finger paints and a second finger cancels the open stroke and controls the camera,
##   using the same MHGestureStateMachine policy as the main terrain editor.
##
## Finalized practice keeps tap-to-aim separate from Play shot. UI-owned contacts are never treated as world input.

var panel: MHOneHolePanel
var taps: MHAimTap = MHAimTap.new()

var _craft_machine: MHGestureStateMachine = null
var _blocked_touches: Dictionary = {}
var _mouse_craft: bool = false
var _mouse_rotate: bool = false
var _mouse_pan: bool = false


func _ready() -> void:
	_ensure_craft_machine()


func _process(_delta: float) -> void:
	if _craft_machine == null:
		return
	_craft_machine.tracker.screen_size = get_viewport().get_visible_rect().size
	_craft_machine.tick(Time.get_ticks_msec())


func _ensure_craft_machine() -> void:
	if _craft_machine != null or panel == null or panel.live == null or panel.live.controller == null:
		return
	_craft_machine = MHGestureStateMachine.new()
	_craft_machine.stroke_started.connect(_craft_started)
	_craft_machine.stroke_moved.connect(_craft_moved)
	_craft_machine.stroke_ended.connect(_craft_ended)
	_craft_machine.stroke_cancelled.connect(_craft_cancelled)
	panel.live.controller.bind_gestures(_craft_machine)


func _active() -> bool:
	return panel != null and panel.is_visible_in_tree() and panel.live != null \
		and panel.live.shell.modal_id() == "" and panel.live.shell.current_screen_id() == MHScreenIds.HUD


func cancel_all() -> void:
	if _mouse_craft and panel != null:
		panel.craft_stroke_cancel()
	_mouse_craft = false
	_mouse_rotate = false
	_mouse_pan = false
	_blocked_touches.clear()
	taps.clear()
	if _craft_machine != null:
		_craft_machine.cancel_all()
	if panel != null:
		if panel._craft_stroke_open or panel._pending_marker.x >= 0:
			panel.craft_stroke_cancel()
		panel.clear_brush_preview()


func _input(event: InputEvent) -> void:
	if not _active():
		cancel_all()
		return
	_ensure_craft_machine()
	if event is InputEventKey and _handle_shortcut(event as InputEventKey):
		get_viewport().set_input_as_handled()
		return
	if panel._preview_draft:
		_input_craft(event)
	else:
		_input_practice(event)


func _handle_shortcut(key: InputEventKey) -> bool:
	if not key.pressed or key.echo:
		return false
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return false
	if key.keycode == KEY_ESCAPE:
		if panel._pending_marker.x >= 0 or panel._craft_stroke_open:
			cancel_all()
		elif panel._details_open:
			panel._toggle_details()
		elif not panel.collapsed:
			panel.set_collapsed(true)
		else:
			panel.close_preview()
		return true
	if not panel._preview_draft or not key.is_command_or_control_pressed():
		return false
	if key.keycode == KEY_Z:
		if key.shift_pressed:
			panel._craft_redo()
		else:
			panel._craft_undo()
		return true
	if key.keycode == KEY_Y:
		panel._craft_redo()
		return true
	return false


func _input_craft(event: InputEvent) -> void:
	var now: int = Time.get_ticks_msec()
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			if panel.blocks_world_tap(t.position):
				_blocked_touches[t.index] = true
				return
		elif _blocked_touches.has(t.index):
			_blocked_touches.erase(t.index)
			return
		if _craft_machine != null:
			_craft_machine.handle_event(t, now)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if _blocked_touches.has(d.index):
			return
		if panel.blocks_world_tap(d.position):
			# A stroke/camera gesture that crosses into UI must stop owning the
			# contact. Cancel an in-progress craft stroke so no hidden paint lands
			# underneath the panel, then keep this finger blocked until release.
			if _craft_machine != null:
				_craft_machine.cancel_all()
			_blocked_touches[d.index] = true
			return
		if _craft_machine != null:
			_craft_machine.handle_event(d, now)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		_craft_mouse_button(event)
		return
	if event is InputEventMouseMotion:
		_craft_mouse_motion(event)


func _craft_mouse_button(m: InputEventMouseButton) -> void:
	var blocked: bool = panel.blocks_world_tap(m.position)
	if m.button_index == MOUSE_BUTTON_LEFT:
		if m.pressed:
			if blocked:
				return
			_mouse_craft = panel.craft_stroke_begin_from_screen(m.position)
			if _mouse_craft:
				get_viewport().set_input_as_handled()
		elif _mouse_craft:
			_mouse_craft = false
			panel.craft_stroke_end()
			get_viewport().set_input_as_handled()
		return
	if m.button_index == MOUSE_BUTTON_RIGHT:
		if m.pressed:
			if blocked:
				return
			cancel_all()
			_mouse_rotate = true
		else:
			_mouse_rotate = false
		get_viewport().set_input_as_handled()
		return
	if m.button_index == MOUSE_BUTTON_MIDDLE:
		if m.pressed:
			if blocked:
				return
			cancel_all()
			_mouse_pan = true
		else:
			_mouse_pan = false
		get_viewport().set_input_as_handled()
		return
	if m.pressed and not blocked and m.button_index == MOUSE_BUTTON_WHEEL_UP:
		panel.live.controller.desktop_zoom(1)
		get_viewport().set_input_as_handled()
	elif m.pressed and not blocked and m.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		panel.live.controller.desktop_zoom(-1)
		get_viewport().set_input_as_handled()


func _craft_mouse_motion(m: InputEventMouseMotion) -> void:
	if not _mouse_rotate and not _mouse_pan:
		panel.preview_brush_from_screen(m.position)
	else:
		panel.clear_brush_preview()
	if _mouse_craft:
		if panel.blocks_world_tap(m.position):
			panel.craft_stroke_cancel()
			_mouse_craft = false
		else:
			panel.craft_stroke_move_from_screen(m.position)
		get_viewport().set_input_as_handled()
	elif _mouse_rotate:
		panel.live.controller.desktop_rotate(m.relative)
		get_viewport().set_input_as_handled()
	elif _mouse_pan:
		panel.live.controller.desktop_pan(m.relative)
		get_viewport().set_input_as_handled()


func _input_practice(event: InputEvent) -> void:
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
		var drag_blocked: bool = panel.blocks_world_tap(d.position)
		if drag_blocked:
			if _craft_machine != null:
				_craft_machine.cancel_all()
			if taps.drag(d.index, d.position):
				get_viewport().set_input_as_handled()
			return
		if _craft_machine != null:
			_craft_machine.handle_event(d, Time.get_ticks_msec())
		if taps.drag(d.index, d.position):
			get_viewport().set_input_as_handled()
		return
	elif event is InputEventMouseButton:
		var m: InputEventMouseButton = event
		var blocked_mouse: bool = panel.blocks_world_tap(m.position)
		if m.button_index == MOUSE_BUTTON_RIGHT:
			if m.pressed and blocked_mouse:
				return
			_mouse_rotate = m.pressed
			get_viewport().set_input_as_handled()
			return
		if m.button_index == MOUSE_BUTTON_MIDDLE:
			if m.pressed and blocked_mouse:
				return
			_mouse_pan = m.pressed
			get_viewport().set_input_as_handled()
			return
		if m.pressed and not blocked_mouse and m.button_index == MOUSE_BUTTON_WHEEL_UP:
			panel.live.controller.desktop_zoom(1)
			get_viewport().set_input_as_handled()
			return
		if m.pressed and not blocked_mouse and m.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			panel.live.controller.desktop_zoom(-1)
			get_viewport().set_input_as_handled()
			return
		if m.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = m.position
		id = -1
		pressed = m.pressed
		released = not pressed
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if _mouse_rotate:
			panel.live.controller.desktop_rotate(motion.relative)
			get_viewport().set_input_as_handled()
			return
		if _mouse_pan:
			panel.live.controller.desktop_pan(motion.relative)
			get_viewport().set_input_as_handled()
			return
		if taps.drag(-1, motion.position):
			get_viewport().set_input_as_handled()
		return
	else:
		return
	var blocked: bool = panel.blocks_world_tap(pos)
	if event is InputEventScreenTouch and _craft_machine != null:
		# The same two-finger gesture policy remains available after finalization.
		# One-finger tap ownership is still decided by MHAimTap, so camera gestures
		# cannot accidentally commit or move an aim.
		if blocked:
			if released:
				_craft_machine.cancel_all()
		else:
			_craft_machine.handle_event(event, Time.get_ticks_msec())
	if pressed:
		if taps.down(id, pos, blocked):
			get_viewport().set_input_as_handled()
	elif released:
		var result: Dictionary = taps.up(id, pos, blocked, cancelled)
		if bool(result["consume"]):
			get_viewport().set_input_as_handled()
		if bool(result["aim"]):
			panel.aim_from_screen(pos)


func _craft_started(pos: Vector2) -> void:
	if panel != null and panel._preview_draft:
		panel.craft_stroke_begin_from_screen(pos)


func _craft_moved(pos: Vector2) -> void:
	if panel != null and panel._preview_draft:
		panel.craft_stroke_move_from_screen(pos)


func _craft_ended() -> void:
	if panel != null and panel._preview_draft:
		panel.craft_stroke_end()


func _craft_cancelled() -> void:
	if panel != null:
		panel.craft_stroke_cancel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_all()

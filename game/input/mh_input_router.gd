class_name MHInputRouter
extends Node
## Feeds real input to the gesture state machine and camera controller.
## Touch: ScreenTouch/ScreenDrag go to the state machine (emulate_mouse_from_touch
## must be OFF, and emulate_touch_from_mouse must be OFF too).
## Desktop dev mapping: left-drag paint, right-drag rotate (x = yaw, y = tilt),
## wheel zoom, middle-drag pan.
## UI regions (compass, overlay corner) are hit-tested here, not through Control
## click handling, because Controls may not react to raw touch events when
## mouse emulation is off. A touch that starts in a region never paints.

signal ui_tapped(region: StringName)

enum MouseMode { NONE, PAINT, ROTATE, PAN }

## Scene may suppress world gestures while an opaque menu/modal is open.
var accept_world_input: bool = true
## Optional live predicate: rechecked per input so newly opened modals suppress painting immediately.
var world_input_allowed: Callable = Callable()

var machine: MHGestureStateMachine
var controller: MHCameraController
var bridge: MHStrokeBridge

var _overlay: MHDebugOverlay
var _regions: Dictionary = {}
var _ui_touches: Dictionary = {}
var _ui_mouse_region: StringName = &""
var _mouse_mode: int = MouseMode.NONE


func setup(p_controller: MHCameraController, compass: MHCompassButton, overlay: MHDebugOverlay, sink: MHStrokeSink, screen_to_cell: Callable, gesture_config: MHGestureConfig = null) -> void:
	controller = p_controller
	_overlay = overlay
	machine = MHGestureStateMachine.new(gesture_config)
	controller.bind_gestures(machine)
	bridge = MHStrokeBridge.new(sink, screen_to_cell, machine)
	register_ui_region(&"compass", Callable(compass, "get_global_rect"))
	register_ui_region(&"overlay_toggle", Callable(overlay, "get_toggle_rect"))
	overlay.bind(machine, controller)
	controller.camera_changed.connect(func() -> void: compass.set_yaw(controller.rig.yaw))
	ui_tapped.connect(_on_ui_tapped)


## rect_getter: Callable() -> Rect2 in viewport coordinates.
func register_ui_region(region: StringName, rect_getter: Callable) -> void:
	_regions[region] = rect_getter


func _ready() -> void:
	if ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true):
		push_warning("MHInputRouter: emulate_mouse_from_touch is ON. Turn it OFF or touches double-fire.")
	if ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false):
		push_warning("MHInputRouter: emulate_touch_from_mouse is ON. Turn it OFF or mouse input double-fires.")


func _process(_delta: float) -> void:
	if machine == null:
		return
	machine.tracker.screen_size = get_viewport().get_visible_rect().size
	machine.tick(Time.get_ticks_msec())


func _notification(what: int) -> void:
	if machine == null:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_world_input()


## Clear all transient pointer state when leaving the world or losing focus.
func cancel_world_input() -> void:
	_mouse_mode = MouseMode.NONE
	_ui_mouse_region = &""
	_ui_touches.clear()
	if machine != null:
		machine.cancel_all()


func _hit(pos: Vector2) -> StringName:
	for region in _regions:
		var getter: Callable = _regions[region]
		var rect: Rect2 = getter.call()
		if rect.has_point(pos):
			return region
	return &""


func _on_ui_tapped(region: StringName) -> void:
	if region == &"compass":
		controller.snap_north()
	elif region == &"overlay_toggle":
		_overlay.toggle()


func _input(event: InputEvent) -> void:
	if machine == null:
		return
	if not accept_world_input:
		cancel_world_input()
		return
	if world_input_allowed.is_valid() and not bool(world_input_allowed.call()):
		cancel_world_input()
		return
	var now: int = Time.get_ticks_msec()
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			var hit: StringName = _hit(t.position)
			if hit != &"":
				_ui_touches[t.index] = hit
				get_viewport().set_input_as_handled()
				return
		elif _ui_touches.has(t.index):
			var started_in: StringName = _ui_touches[t.index]
			_ui_touches.erase(t.index)
			if not t.canceled and _hit(t.position) == started_in:
				ui_tapped.emit(started_in)
			return
		machine.handle_event(t, now)
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if _ui_touches.has(d.index):
			return
		machine.handle_event(d, now)
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)


func _on_mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			var hit: StringName = _hit(mb.position)
			if hit != &"":
				_ui_mouse_region = hit
				get_viewport().set_input_as_handled()
				return
			_mouse_mode = MouseMode.PAINT
			machine.desktop_stroke_begin(mb.position)
		else:
			if _ui_mouse_region != &"":
				var region: StringName = _ui_mouse_region
				_ui_mouse_region = &""
				if _hit(mb.position) == region:
					ui_tapped.emit(region)
				get_viewport().set_input_as_handled()
				return
			if _mouse_mode == MouseMode.PAINT:
				_mouse_mode = MouseMode.NONE
				machine.desktop_stroke_end()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if mb.pressed:
			_mouse_mode = MouseMode.ROTATE
		elif _mouse_mode == MouseMode.ROTATE:
			_mouse_mode = MouseMode.NONE
	elif mb.button_index == MOUSE_BUTTON_MIDDLE:
		if mb.pressed:
			_mouse_mode = MouseMode.PAN
		elif _mouse_mode == MouseMode.PAN:
			_mouse_mode = MouseMode.NONE
	elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		controller.desktop_zoom(1)
	elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		controller.desktop_zoom(-1)


func _on_mouse_motion(mm: InputEventMouseMotion) -> void:
	if _mouse_mode == MouseMode.PAINT:
		machine.desktop_stroke_move(mm.position)
	elif _mouse_mode == MouseMode.ROTATE:
		controller.desktop_rotate(mm.relative)
	elif _mouse_mode == MouseMode.PAN:
		controller.desktop_pan(mm.relative)


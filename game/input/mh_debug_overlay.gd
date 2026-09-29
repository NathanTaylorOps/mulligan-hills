class_name MHDebugOverlay
extends Control
## Debug text overlay. Toggle by tapping the top-left corner square (always
## active, drawn faintly when hidden). Shows finger count, gesture state,
## camera values and stroke counters.

var expanded: bool = false
var font_size: int = 26

var _machine: MHGestureStateMachine
var _controller: MHCameraController
var _started: int = 0
var _ended: int = 0
var _cancelled: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func get_toggle_rect() -> Rect2:
	return Rect2(global_position, Vector2(96.0, 96.0))


func toggle() -> void:
	expanded = not expanded
	queue_redraw()


func bind(machine: MHGestureStateMachine, controller: MHCameraController) -> void:
	_machine = machine
	_controller = controller
	machine.stroke_started.connect(_on_started)
	machine.stroke_ended.connect(_on_ended)
	machine.stroke_cancelled.connect(_on_cancelled)


func _on_started(_p: Vector2) -> void:
	_started += 1


func _on_ended() -> void:
	_ended += 1


func _on_cancelled() -> void:
	_cancelled += 1


func _process(_delta: float) -> void:
	if expanded:
		queue_redraw()


func _draw() -> void:
	var corner_alpha: float = 0.5 if expanded else 0.15
	draw_rect(Rect2(Vector2.ZERO, Vector2(96.0, 96.0)), Color(1, 1, 1, corner_alpha), false, 2.0)
	if not expanded or _machine == null or _controller == null or _controller.rig == null:
		return
	var rig: MHOrbitRig = _controller.rig
	var lines: Array[String] = [
		"fingers: %d" % _machine.tracker.count(),
		"state: %s" % MHGestureStateMachine.state_name(_machine.state),
		"yaw: %.1f deg  pitch: %.1f deg" % [rad_to_deg(rig.yaw), rig.pitch_deg],
		"distance: %.1f" % rig.distance,
		"target: %.1f, %.1f" % [rig.target.x, rig.target.z],
		"strokes started/ended/cancelled: %d/%d/%d" % [_started, _ended, _cancelled],
	]
	var line_h: float = float(font_size) + 8.0
	draw_rect(Rect2(Vector2(0, 100), Vector2(size.x * 0.8, line_h * lines.size() + 12.0)), Color(0, 0, 0, 0.6))
	var f: Font = ThemeDB.fallback_font
	for i in lines.size():
		draw_string(f, Vector2(12.0, 100.0 + line_h * (i + 1)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

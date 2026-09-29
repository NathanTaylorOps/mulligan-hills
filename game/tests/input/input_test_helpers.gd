class_name MHInputTestHelpers
extends RefCounted
## Synthetic event factories and a signal recorder for gesture tests.

static func touch(index: int, pos: Vector2, pressed: bool, canceled: bool = false) -> InputEventScreenTouch:
	var e: InputEventScreenTouch = InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	e.canceled = canceled
	return e


static func drag(index: int, pos: Vector2, relative: Vector2 = Vector2.ZERO) -> InputEventScreenDrag:
	var e: InputEventScreenDrag = InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = relative
	return e


class Recorder extends RefCounted:
	var log: Array[String] = []
	var started_positions: Array[Vector2] = []
	var moved_positions: Array[Vector2] = []
	var twist_sum: float = 0.0
	var camera_events: int = 0

	func _init(machine: MHGestureStateMachine) -> void:
		machine.stroke_started.connect(_on_started)
		machine.stroke_moved.connect(_on_moved)
		machine.stroke_ended.connect(_on_ended)
		machine.stroke_cancelled.connect(_on_cancelled)
		machine.camera_gesture.connect(_on_camera)

	func count(name: String) -> int:
		var n: int = 0
		for s in log:
			if s == name:
				n += 1
		return n

	func _on_started(p: Vector2) -> void:
		log.append("started")
		started_positions.append(p)

	func _on_moved(p: Vector2) -> void:
		log.append("moved")
		moved_positions.append(p)

	func _on_ended() -> void:
		log.append("ended")

	func _on_cancelled() -> void:
		log.append("cancelled")

	func _on_camera(_pan: Vector2, _ratio: float, twist: float) -> void:
		camera_events += 1
		twist_sum += twist

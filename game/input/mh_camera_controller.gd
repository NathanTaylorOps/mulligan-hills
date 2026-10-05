class_name MHCameraController
extends Node3D
## Camera3D orbit rig node. Keep this node at the identity transform.
## Owns an MHOrbitRig and applies it to a child Camera3D (created if missing).

signal camera_changed()

@export var config: MHCameraConfig

var rig: MHOrbitRig
var camera: Camera3D


func _ready() -> void:
	if config == null:
		config = MHCameraConfig.new()
	rig = MHOrbitRig.new(config)
	for c in get_children():
		if c is Camera3D:
			camera = c
			break
	if camera == null:
		camera = Camera3D.new()
		add_child(camera)
	camera.current = true
	_apply_transform()


func bind_gestures(machine: MHGestureStateMachine) -> void:
	machine.camera_gesture.connect(_on_camera_gesture)
	machine.camera_gesture_ended.connect(_on_camera_gesture_ended)


func snap_north() -> void:
	rig.snap_north()


# Desktop dev mapping helpers (called by MHInputRouter).
func desktop_rotate(relative: Vector2) -> void:
	rig.apply_twist(relative.x * config.mouse_rotate_rad_per_px, 0.0)
	rig.tilt_by_deg(relative.y * config.mouse_tilt_deg_per_px)
	rig.end_gesture()
	_apply_and_emit()


func desktop_pan(relative: Vector2) -> void:
	rig.apply_pan_pixels(relative, 0.0)
	rig.end_gesture()
	_apply_and_emit()


## direction +1 = wheel up = zoom in.
func desktop_zoom(direction: int) -> void:
	var step: float = 1.0 + config.wheel_zoom_step
	rig.apply_zoom_ratio(step if direction > 0 else 1.0 / step)
	_apply_and_emit()


func _process(delta: float) -> void:
	if rig.update(delta):
		_apply_and_emit()


func _on_camera_gesture(pan_px: Vector2, zoom_ratio: float, twist_rad: float) -> void:
	rig.apply_touch_gesture(pan_px, zoom_ratio, twist_rad, get_process_delta_time())
	_apply_and_emit()


func _on_camera_gesture_ended() -> void:
	rig.end_gesture()


func _apply_transform() -> void:
	camera.look_at_from_position(rig.get_camera_position(), rig.target, Vector3.UP)


func _apply_and_emit() -> void:
	_apply_transform()
	camera_changed.emit()



## Recenter without altering golf/simulation state. Yaw is preserved; pitch follows the existing zoom policy.
func focus_target(point: Vector3, new_distance: float = -1.0) -> void:
	rig.focus_target(point, new_distance)
	_apply_and_emit()

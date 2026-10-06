class_name MHIsoCameraController
extends Node3D
## Orthographic isometric camera (DEC-085) driven by MHIsoRig. Keep this node at the identity transform.
## Same small surface as MHCameraController so scenes can swap: rig.target, camera, desktop_pan, desktop_zoom,
## desktop_rotate, focus_target, snap_north, camera_changed.

signal camera_changed()

var rig: MHIsoRig = MHIsoRig.new()
var camera: Camera3D


func _ready() -> void:
	for c: Node in get_children():
		if c is Camera3D:
			camera = c as Camera3D
			break
	if camera == null:
		camera = Camera3D.new()
		add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 1.0
	camera.far = MHIsoRig.EYE_DISTANCE_M * 3.0
	camera.current = true
	_apply()


func _process(delta: float) -> void:
	if rig.update(delta):
		_apply()
		camera_changed.emit()


func apply_now() -> void:
	_apply()
	camera_changed.emit()


func rotate_step(direction: int) -> void:
	rig.rotate_step(direction)


## Desktop and touch drag in pixels.
func desktop_pan(relative: Vector2) -> void:
	rig.pan_pixels(relative, _viewport_height())
	apply_now()


## direction +1 = wheel up = zoom in.
func desktop_zoom(direction: int) -> void:
	rig.zoom_step(direction)


## Kept for scenes written for the orbit camera: a horizontal drag steps the view.
func desktop_rotate(relative: Vector2) -> void:
	if absf(relative.x) > 0.5:
		rig.rotate_step(1 if relative.x > 0.0 else -1)


func snap_north() -> void:
	rig.snap_view(0)
	apply_now()


func focus_target(point: Vector3, _unused_distance: float = -1.0) -> void:
	rig.focus_target(point)
	apply_now()


func _viewport_height() -> float:
	if is_inside_tree() and get_viewport() != null:
		return maxf(1.0, get_viewport().get_visible_rect().size.y)
	return 720.0


func _apply() -> void:
	if camera == null:
		return
	camera.size = rig.size_m
	camera.look_at_from_position(rig.get_camera_position(), rig.target, Vector3.UP)

class_name MHCameraRig
extends Node3D
## Auto-orbiting camera around a target point.

var orbit_enabled: bool = true
var radius: float = 110.0
var height: float = 42.0
var degrees_per_second: float = 8.0
var target: Vector3 = Vector3(0.0, 4.0, 0.0)
var angle_deg: float = 0.0
var camera: Camera3D


func build() -> void:
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.near = 0.5
	camera.far = 700.0
	add_child(camera)
	_apply()


func _process(delta: float) -> void:
	if orbit_enabled:
		angle_deg = fposmod(angle_deg + degrees_per_second * delta, 360.0)
		_apply()


func _apply() -> void:
	var a: float = deg_to_rad(angle_deg)
	camera.position = target + Vector3(cos(a) * radius, height, sin(a) * radius)
	camera.look_at(target, Vector3.UP)


## Point on the ground a fixed fraction of the way from target toward the camera; used as dither brush.
func brush_position() -> Vector3:
	var a: float = deg_to_rad(angle_deg)
	return Vector3(cos(a) * radius * 0.55, 0.0, sin(a) * radius * 0.55)

extends Node3D
## Phase 0 gesture proof scene. No terrain needed. Paints 1 m dabs on a flat
## ground plane; a cancelled stroke removes its dabs (visible rollback).
## North is marked by a tall RED post at -Z, other directions by grey posts.

class SandboxSink extends MHStrokeSink:
	var _root: Node3D
	var _current: Array[Node3D] = []

	func _init(root: Node3D) -> void:
		_root = root

	func begin_stroke() -> void:
		_current.clear()

	func apply_brush_at(cell_x: int, cell_y: int) -> void:
		var m: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.9, 0.1, 0.9)
		m.mesh = box
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.85, 0.2)
		m.material_override = mat
		m.position = Vector3(cell_x + 0.5, 0.05, cell_y + 0.5)
		_root.add_child(m)
		_current.append(m)

	func end_stroke() -> void:
		_current.clear()

	func cancel_stroke() -> void:
		for m in _current:
			m.queue_free()
		_current.clear()

var _controller: MHCameraController
var _paint_root: Node3D


func _ready() -> void:
	_build_world()
	_controller = MHCameraController.new()
	_controller.config = MHCameraConfig.new()
	add_child(_controller)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var overlay: MHDebugOverlay = MHDebugOverlay.new()
	layer.add_child(overlay)
	var compass: MHCompassButton = MHCompassButton.new()
	layer.add_child(compass)
	var router: MHInputRouter = MHInputRouter.new()
	add_child(router)
	router.setup(_controller, compass, overlay, SandboxSink.new(_paint_root), Callable(self, "_screen_to_cell"))


func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var cam: Camera3D = _controller.camera
	var origin: Vector3 = cam.project_ray_origin(screen_pos)
	var dir: Vector3 = cam.project_ray_normal(screen_pos)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)
	return MHCellSentinel.from_ground_hit(hit)


func _build_world() -> void:
	_paint_root = Node3D.new()
	add_child(_paint_root)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	ground.mesh = plane
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_color = Color(0.25, 0.6, 0.25)
	ground.material_override = gm
	add_child(ground)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	add_child(sun)
	_add_post(Vector3(0, 0, -30), Color(0.9, 0.1, 0.1), 12.0)
	_add_post(Vector3(30, 0, 0), Color(0.6, 0.6, 0.6), 6.0)
	_add_post(Vector3(-30, 0, 0), Color(0.6, 0.6, 0.6), 6.0)
	_add_post(Vector3(0, 0, 30), Color(0.6, 0.6, 0.6), 6.0)


func _add_post(pos: Vector3, color: Color, height: float) -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1.5, height, 1.5)
	m.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	m.position = pos + Vector3(0, height * 0.5, 0)
	add_child(m)

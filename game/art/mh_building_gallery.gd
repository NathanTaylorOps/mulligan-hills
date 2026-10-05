class_name MHBuildingGallery
extends Node3D
## Dev gallery for the procedural buildings (DEC-062). Shows one building at a time as a row of its five
## tiers, left to right, on a flat ground. Buttons: previous / next building, spec a / b (tier 3 and up),
## rotate the view 45 degrees. The label lists triangle counts per tier. Day lighting from MHSkySetup,
## one shared vertex-colour material, no shadows. NOT YET RUN.

const GAP: float = 6.0

var _index: int = 0
var _spec: String = "a"
var _yaw_deg: float = 0.0
var _mat: StandardMaterial3D
var _stage: Node3D
var _camera: Camera3D
var _label: Label
var _spec_button: Button
var _instances: Array = []


func _ready() -> void:
	_mat = MHArtMaterials.vertex_color()
	MHSkySetup.apply(self, false)
	_stage = Node3D.new()
	add_child(_stage)
	_camera = Camera3D.new()
	_camera.far = 400.0
	add_child(_camera)
	_camera.make_current()
	_build_ui()
	rebuild()


## Number of building meshes currently shown (5 once built).
func shown_count() -> int:
	return _instances.size()


func current_id() -> String:
	return str(MHBuildingMeshes.IDS[_index])


func current_spec() -> String:
	return _spec


func select(index: int) -> void:
	var n: int = MHBuildingMeshes.IDS.size()
	_index = ((index % n) + n) % n
	rebuild()


func set_spec(spec: String) -> void:
	_spec = "b" if spec == "b" else "a"
	rebuild()


func rotate_view() -> void:
	_yaw_deg = fmod(_yaw_deg + 45.0, 360.0)
	_place_camera()


func rebuild() -> void:
	for child in _stage.get_children():
		_stage.remove_child(child)
		child.queue_free()
	_instances.clear()
	var id: String = current_id()
	var cursor: float = 0.0
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s  (spec %s from tier 3)" % [id.replace("_", " ").capitalize(), _spec])
	var max_depth: float = 10.0
	for tier in range(1, MHBuildingMeshes.TIER_COUNT + 1):
		var bb: AABB = MHBuildingMeshes.bounds(id, tier, _spec)
		var mesh: ArrayMesh = MHBuildingMeshes.build(id, tier, _spec)
		var mi: MeshInstance3D = MHArtMaterials.make_instance(mesh, _mat, false)
		var centre_x: float = bb.position.x + bb.size.x * 0.5
		var centre_z: float = bb.position.z + bb.size.z * 0.5
		mi.position = Vector3(cursor + bb.size.x * 0.5 - centre_x, 0.0, -centre_z)
		_stage.add_child(mi)
		_instances.append(mi)
		cursor += bb.size.x + GAP
		max_depth = maxf(max_depth, bb.size.z)
		lines.append("Tier %d: %d triangles, %.1f x %.1f x %.1f m" % [tier,
			MHBuildingMeshes.tri_count(id, tier, _spec), bb.size.x, bb.size.y, bb.size.z])
	var total: float = cursor - GAP
	var ground: MHMeshBuilder = MHMeshBuilder.new()
	MHBuildingParts.flat(ground, Vector3(total * 0.5, -0.02, 0.0), total + 30.0, max_depth + 30.0, MHPalette.GRASS)
	var gi: MeshInstance3D = MHArtMaterials.make_instance(ground.to_mesh(), _mat, false)
	_stage.add_child(gi)
	_stage.position = Vector3(-total * 0.5, 0.0, 0.0)
	_label.text = "\n".join(lines)
	_spec_button.text = "Spec " + _spec.to_upper()
	_place_camera(total)


func _place_camera(total_width: float = -1.0) -> void:
	var total: float = total_width
	if total < 0.0:
		total = _stage_width()
	var dist: float = maxf(total * 0.85, 30.0)
	var yaw: float = deg_to_rad(_yaw_deg)
	var offset: Vector3 = Vector3(sin(yaw) * 0.55, 0.55, cos(yaw) * 0.85).normalized() * dist
	var target: Vector3 = Vector3(0.0, 3.0, 0.0)
	_camera.look_at_from_position(target + offset, target, Vector3.UP)


func _stage_width() -> float:
	return maxf(-_stage.position.x * 2.0, 30.0)


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	layer.add_child(box)
	var bar: HBoxContainer = HBoxContainer.new()
	box.add_child(bar)
	bar.add_child(_make_button("<", _on_prev))
	bar.add_child(_make_button(">", _on_next))
	_spec_button = _make_button("Spec A", _on_spec)
	bar.add_child(_spec_button)
	bar.add_child(_make_button("Rotate", _on_rotate))
	_label = Label.new()
	box.add_child(_label)


func _make_button(text: String, handler: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(96.0, 56.0)
	btn.pressed.connect(handler)
	return btn


func _on_prev() -> void:
	select(_index - 1)


func _on_next() -> void:
	select(_index + 1)


func _on_spec() -> void:
	set_spec("b" if _spec == "a" else "a")


func _on_rotate() -> void:
	rotate_view()

class_name MHGolfers
extends Node3D
## 40 golfer stand-ins: capsules with a simple bob. Visible count is capped per tier.

const TOTAL: int = 40

var visible_cap: int = TOTAL
var _mm: MultiMesh
var _node: MultiMeshInstance3D
var _homes: PackedVector3Array = PackedVector3Array()
var _phase: PackedFloat32Array = PackedFloat32Array()
var _t: float = 0.0


func build() -> void:
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.8
	cap.radial_segments = 8
	cap.rings = 2
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = cap
	_mm.instance_count = TOTAL
	var rng: MHForestRng = MHForestRng.new(777)
	for i in range(TOTAL):
		# Homes along the fairway (world z about -90 .. -70, x -150 .. 150), integer-derived.
		var x: float = float(rng.range_int(300000)) * 0.001 - 150.0
		var z: float = float(rng.range_int(30000)) * 0.001 - 105.0
		_homes.append(Vector3(x, 0.0, z))
		_phase.append(float(rng.range_int(6283)) * 0.001)
		var shade: float = 0.5 + float(rng.range_int(500)) * 0.001
		_mm.set_instance_color(i, Color(shade, 0.35 + 0.4 * (1.0 - shade), 0.9 - 0.4 * shade))
	_node = MultiMeshInstance3D.new()
	_node.multimesh = _mm
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	_node.material_override = mat
	add_child(_node)
	_update_transforms()


func apply_tier(cfg: Dictionary) -> void:
	visible_cap = clampi(int(cfg["max_golfers"]), 0, TOTAL)
	_mm.visible_instance_count = visible_cap
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if str(cfg["shadow_mode"]) != MHQuality.SHADOW_OFF else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_t += delta
	_update_transforms()


func _update_transforms() -> void:
	for i in range(visible_cap):
		var ph: float = _phase[i]
		var bob: float = absf(sin(_t * 4.0 + ph)) * 0.12
		var drift: Vector3 = Vector3(cos(_t * 0.3 + ph) * 3.0, 0.0, sin(_t * 0.3 + ph) * 3.0)
		var p: Vector3 = _homes[i] + drift + Vector3(0.0, 0.9 + bob, 0.0)
		_mm.set_instance_transform(i, Transform3D(Basis(), p))

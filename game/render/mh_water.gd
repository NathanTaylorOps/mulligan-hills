class_name MHWater
extends MeshInstance3D
## Flat water plane using water.gdshader. Centred on the pond exclusion rectangle.

const WATER_SHADER: String = "res://render/shaders/water.gdshader"

var _mat: ShaderMaterial


func build() -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(100.0, 80.0)
	plane.subdivide_width = 0
	plane.subdivide_depth = 0
	mesh = plane
	_mat = ShaderMaterial.new()
	_mat.shader = load(WATER_SHADER) as Shader
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position = Vector3(0.0, 0.12, 0.0)


func apply_tier(cfg: Dictionary) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("wave_amount", 1.0 if bool(cfg["water_waves"]) else 0.0)

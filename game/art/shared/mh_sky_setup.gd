class_name MHSkySetup
extends RefCounted
## Stylised day sky, one directional light, flat ambient and an optional soft "blob" shadow helper.
## Deliberately cheap: no glow, SSAO, fog or reflections, so it is safe on the Compatibility renderer.
## Ambient is a flat colour (not sky-derived) so lighting cost is constant.

const SUN_PITCH_DEG: float = -52.0
const SUN_YAW_DEG: float = -35.0


static func make_environment() -> Environment:
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = MHPalette.SKY_TOP
	sky_mat.sky_horizon_color = MHPalette.SKY_HORIZON
	sky_mat.ground_horizon_color = MHPalette.SKY_HORIZON
	sky_mat.ground_bottom_color = MHPalette.SKY_GROUND
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = MHPalette.AMBIENT
	env.ambient_light_energy = 0.75
	return env


static func make_sun(shadows: bool) -> DirectionalLight3D:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_color = MHPalette.SUN
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(SUN_PITCH_DEG, SUN_YAW_DEG, 0.0)
	sun.shadow_enabled = shadows
	sun.shadow_bias = 0.05
	return sun


## Adds a WorldEnvironment and a sun to `root`. Returns {"environment": WorldEnvironment, "sun": DirectionalLight3D}.
static func apply(root: Node, shadows: bool) -> Dictionary:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = make_environment()
	var sun: DirectionalLight3D = make_sun(shadows)
	root.add_child(we)
	root.add_child(sun)
	return {"environment": we, "sun": sun}


## Soft round shadow blob lying on the ground (facing up). Centre alpha `alpha`, edge alpha 0.
## 3 * sides triangles: centre fan plus one outer band.
static func blob_shadow_mesh(radius: float, sides: int = 10, alpha: float = 0.32) -> ArrayMesh:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	var c_core: Color = Color(0.05, 0.10, 0.03, alpha)
	var c_mid: Color = Color(0.05, 0.10, 0.03, alpha * 0.55)
	var c_edge: Color = Color(0.05, 0.10, 0.03, 0.0)
	var down: Vector3 = Vector3(0.0, -1.0, 0.0)
	var centre: Vector3 = Vector3.ZERO
	for i in range(sides):
		var m0: Vector3 = MHMeshBuilder.ring_point(radius * 0.55, 0.0, sides, i)
		var m1: Vector3 = MHMeshBuilder.ring_point(radius * 0.55, 0.0, sides, i + 1)
		var e0: Vector3 = MHMeshBuilder.ring_point(radius, 0.0, sides, i)
		var e1: Vector3 = MHMeshBuilder.ring_point(radius, 0.0, sides, i + 1)
		b.tri(centre, m0, m1, c_core, c_mid, c_mid, down)
		b.tri(m0, e0, e1, c_mid, c_edge, c_edge, down)
		b.tri(m0, e1, m1, c_mid, c_edge, c_mid, down)
	return b.to_mesh()


## Adds one blob shadow under `parent` at `pos` (ground level; lifted 2 cm to avoid z-fighting).
static func add_blob_shadow(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MHArtMaterials.make_instance(blob_shadow_mesh(radius), mat, false)
	mi.position = pos + Vector3(0.0, 0.02, 0.0)
	parent.add_child(mi)
	return mi

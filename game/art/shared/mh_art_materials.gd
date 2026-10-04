class_name MHArtMaterials
extends RefCounted
## Material factory for procedural art. One flat-shaded, vertex-coloured, rough, non-specular
## material covers everything, so all art shares one look and can share one material instance
## (fewer state changes on a budget phone). Callers should create one and reuse it.


## Standard art material. Vertex colour is albedo. `two_sided` turns off back-face culling (only for
## thin foliage that was not built two-sided). Colours are treated as sRGB (palette values).
static func vertex_color(two_sided: bool = false) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.metallic_specular = 0.0
	if two_sided:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## Unlit variant, for blob shadows and UI-like 3D pieces. Vertex alpha is honoured.
static func unshaded_alpha() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return mat


## Builds a MeshInstance3D with the mesh and a material. `shadow` controls real shadow casting.
static func make_instance(mesh: Mesh, mat: Material, shadow: bool = true) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	if shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	else:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Builds a MultiMeshInstance3D from a mesh and transforms (LOD is the caller's choice of mesh plus
## visibility range). Optional per-instance colours multiply the vertex colours only if the material
## uses them, so they are off unless `colors` is passed.
static func make_multimesh(mesh: Mesh, mat: Material, transforms: Array,
		colors: PackedColorArray = PackedColorArray()) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors.size() == transforms.size() and colors.size() > 0
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i] as Transform3D)
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	return node

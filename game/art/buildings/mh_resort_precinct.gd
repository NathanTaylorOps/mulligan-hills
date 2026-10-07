class_name MHResortPrecinct
extends RefCounted
## Presentation-only composition around a placed resort building.
## It never changes building footprint, collision, economy or simulation state.
## Callers choose a visual quality tier; Low keeps only the building and arrival pad.

static func populate(parent: Node3D, building_id: String, tier: int, spec: String,
		quality: MHVisualQuality.Tier, position: Vector3 = Vector3.ZERO, yaw: float = 0.0) -> Array:
	var made: Array = []
	if parent == null or not MHBuildingMeshes.is_valid_id(building_id):
		return made
	var settings: Dictionary = MHVisualQuality.settings(quality)
	var root: Node3D = Node3D.new()
	root.name = "Precinct_" + building_id
	root.position = position
	root.rotation.y = yaw
	parent.add_child(root)
	made.append(root)

	var art_mat: StandardMaterial3D = MHArtMaterials.vertex_color()
	var building: MeshInstance3D = MHArtMaterials.make_instance(
		MHBuildingMeshes.build(building_id, tier, spec), art_mat, bool(settings.get("shadows", true)))
	building.name = "Building"
	root.add_child(building)

	var bb: AABB = MHBuildingMeshes.bounds(building_id, tier, spec)
	var half_w: float = maxf(4.0, bb.size.x * 0.5)
	var front_z: float = bb.position.z + bb.size.z + 1.4
	_add_arrival(root, half_w, front_z, art_mat, made)
	var density: float = float(settings.get("decor_density", 0.65))
	if density < 0.45:
		return made

	var lod: int = 0 if density >= 0.8 else 1
	# Symmetric foundation planting keeps the entrance readable from the isometric camera.
	for side in [-1.0, 1.0]:
		_add_nature(root, "bush", Vector3(side * (half_w + 0.8), 0.02, front_z - 0.5), lod,
			absi(roundi(side * 17.0)) + tier, art_mat, made)
		_add_nature(root, "flower_patch", Vector3(side * maxf(2.0, half_w * 0.55), 0.02, front_z + 1.3), lod,
			absi(roundi(side * 31.0)) + tier, art_mat, made)
	_add_prop(root, "bench", Vector3(-half_w * 0.48, 0.02, front_z + 2.8), lod, 0, 0.0, art_mat, made)
	_add_prop(root, "bin", Vector3(-half_w * 0.48 - 1.4, 0.02, front_z + 2.8), lod, 0, 0.0, art_mat, made)
	_add_prop(root, "sign", Vector3(half_w + 1.5, 0.02, front_z + 1.8), lod, 0, -0.18, art_mat, made)

	if density >= 0.8:
		# High/Ultra spend their detail on composition: framing trees and boulder/flower beds,
		# not on cluttering the playing surface.
		_add_nature(root, "oak", Vector3(-half_w - 3.2, 0.02, front_z - 1.8), 0, tier + 2, art_mat, made)
		_add_nature(root, "pine", Vector3(half_w + 3.6, 0.02, front_z - 2.4), 0, tier + 5, art_mat, made)
		_add_nature(root, "rock_cluster", Vector3(half_w + 2.0, 0.02, front_z + 3.0), 0, tier + 7, art_mat, made)
		_add_prop(root, "bench", Vector3(half_w * 0.40, 0.02, front_z + 2.8), 0, 1, PI, art_mat, made)
	return made


static func _add_arrival(root: Node3D, half_w: float, front_z: float,
		material: StandardMaterial3D, made: Array) -> void:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	# Broad stone arrival court, narrower walk and two raised planting-bed edges.
	MHBuildingParts.flat(b, Vector3(0.0, 0.015, front_z + 2.0), half_w * 1.55, 3.4, MHPalette.PATH_STONE)
	MHBuildingParts.flat(b, Vector3(0.0, 0.018, front_z + 4.1), 2.4, 2.0, MHPalette.PATH_EDGE)
	for side in [-1.0, 1.0]:
		MHBuildingParts.slab(b, Vector3(side * (half_w * 0.72), 0.02, front_z + 1.0),
			Vector3(maxf(1.8, half_w * 0.42), 0.20, 1.25), MHPalette.STONE_LIGHT, MHPalette.STONE_DARK)
	var mi: MeshInstance3D = MHArtMaterials.make_instance(b.to_mesh(), material, false)
	mi.name = "ArrivalLandscape"
	root.add_child(mi)
	made.append(mi)


static func _add_nature(root: Node3D, kind: String, pos: Vector3, lod: int, variant: int,
		material: StandardMaterial3D, made: Array) -> void:
	var mi: MeshInstance3D = MHArtMaterials.make_instance(
		MHNatureMeshes.build(kind, lod, variant % MHNatureMeshes.VARIANTS), material, lod == 0)
	mi.position = pos
	mi.rotation.y = float((variant * 73) % 628) / 100.0
	root.add_child(mi)
	made.append(mi)


static func _add_prop(root: Node3D, kind: String, pos: Vector3, lod: int, variant: int, yaw: float,
		material: StandardMaterial3D, made: Array) -> void:
	var prop_lod: int = mini(lod, MHPropMeshes.LOD_COUNT - 1)
	var mi: MeshInstance3D = MHArtMaterials.make_instance(MHPropMeshes.build(kind, prop_lod, variant), material, lod == 0)
	mi.position = pos
	mi.rotation.y = yaw
	root.add_child(mi)
	made.append(mi)

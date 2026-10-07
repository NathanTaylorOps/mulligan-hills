class_name MHBuildingMeshes
extends RefCounted
## Procedural meshes for the 10 buildings x 5 tiers in game/data/buildings.json (DEC-008, DEC-062).
## One ArrayMesh with ONE surface per (building, tier, spec), flat shaded, vertex coloured, opaque, so the
## whole set can use one MHArtMaterials.vertex_color() material. Units are metres, origin on the ground at
## the middle of the main block, +Y up, front (door side) is +Z.
##
## Tiers are cumulative: tier N contains tier N-1 and adds to it, so triangle counts strictly grow and
## the bounding box never shrinks (tests/art/test_building_meshes.gd checks both).
## `spec` is the tier-3 specialisation ("a" or "b", buildings.json tier3_specs). It changes the colour
## scheme and which side the extra wing sits on, never the triangle count. It is ignored below tier 3.
## Same (id, tier, spec) always gives the same vertices, colours and hash. No randomness anywhere.

const IDS: Array = ["clubhouse", "pro_shop", "driving_range", "restaurant", "pool_spa", "cart_barn",
	"maintenance", "lodging", "homes", "landmark"]
const TIER_COUNT: int = 5
const SPECS: Array = ["a", "b"]

## Hard triangle ceiling per progression tier. Hero architecture may spend more detail as the resort matures, while the complete building set remains inside the whole-course mobile budget.
const TIER_BUDGETS: Array = [520, 850, 1300, 1900, 2600]


static func is_valid_id(id: String) -> bool:
	return IDS.has(id)


## Hard triangle ceiling for a tier (clamped to 1..5).
static func budget(tier: int) -> int:
	return int(TIER_BUDGETS[clampi(tier, 1, TIER_COUNT) - 1])


static func spec_index(spec: String) -> int:
	return 1 if spec == "b" else 0


## Builds the mesh. Unknown ids give an empty mesh. Tier is clamped to 1..5.
static func build(id: String, tier: int, spec: String = "a") -> ArrayMesh:
	return build_builder(id, tier, spec).to_mesh()


## Same geometry as `build`, returned as the builder (cheap counting and hashing without a Mesh).
static func build_builder(id: String, tier: int, spec: String = "a") -> MHMeshBuilder:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	var t: int = clampi(tier, 1, TIER_COUNT)
	var sp: int = 0
	if t >= 3:
		sp = spec_index(spec)
	var th: MHBuildingTheme = MHBuildingTheme.make(id, sp)
	match id:
		"clubhouse":
			MHBuildingsGolf.clubhouse(b, t, sp, th)
		"pro_shop":
			MHBuildingsGolf.pro_shop(b, t, sp, th)
		"driving_range":
			MHBuildingsGolf.driving_range(b, t, sp, th)
		"restaurant":
			MHBuildingsGolf.restaurant(b, t, sp, th)
		"pool_spa":
			MHBuildingsGolf.pool_spa(b, t, sp, th)
		"cart_barn":
			MHBuildingsSite.cart_barn(b, t, sp, th)
		"maintenance":
			MHBuildingsSite.maintenance(b, t, sp, th)
		"lodging":
			MHBuildingsSite.lodging(b, t, sp, th)
		"homes":
			MHBuildingsSite.homes(b, t, sp, th)
		"landmark":
			MHBuildingsSite.landmark(b, t, sp, th)
		_:
			pass
	return b


## Triangle count without building a Mesh.
static func tri_count(id: String, tier: int, spec: String = "a") -> int:
	return build_builder(id, tier, spec).tri_count()


## Geometry hash (see MHMeshBuilder.geometry_hash).
static func geometry_hash(id: String, tier: int, spec: String = "a") -> int:
	return build_builder(id, tier, spec).geometry_hash()


## Axis-aligned bounds of the vertices (from the builder, so no Mesh is needed). Empty builder gives a zero box.
static func bounds(id: String, tier: int, spec: String = "a") -> AABB:
	var b: MHMeshBuilder = build_builder(id, tier, spec)
	if b.verts.size() == 0:
		return AABB()
	var lo: Vector3 = b.verts[0]
	var hi: Vector3 = b.verts[0]
	for p in b.verts:
		lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	return AABB(lo, hi - lo)

class_name MHCellSentinel
extends RefCounted
## Translates "no cell under this touch" between the two conventions in the project.
## MHPicking.pick returns MHPicking.MISS (Vector2i(-1, -1)) on a miss, but MHStrokeBridge treats only
## MHStrokeBridge.NO_CELL (INT_MIN, INT_MIN) as "skip this dab". Passing MISS straight through would
## dab cell (-1, -1). Every screen_to_cell Callable handed to MHInputRouter.setup or MHStrokeBridge
## must return one of these helpers' results.


## MISS becomes NO_CELL. Any other cell (including negative ones) is returned unchanged.
static func from_pick(cell: Vector2i) -> Vector2i:
	if cell == MHPicking.MISS:
		return MHStrokeBridge.NO_CELL
	return cell


static func is_no_cell(cell: Vector2i) -> bool:
	return cell == MHStrokeBridge.NO_CELL


## For a flat ground plane: `hit` is the Variant returned by Plane.intersects_ray (null on a miss).
static func from_ground_hit(hit: Variant) -> Vector2i:
	if hit == null or typeof(hit) != TYPE_VECTOR3:
		return MHStrokeBridge.NO_CELL
	var p: Vector3 = hit
	return Vector2i(floori(p.x), floori(p.z))


## Ray-marched pick against a height grid, already translated to NO_CELL on a miss.
static func pick_terrain(grid: MHHeightGrid, origin: Vector3, dir: Vector3, max_dist_m: float = 2000.0) -> Vector2i:
	return from_pick(MHPicking.pick(grid, origin, dir, max_dist_m))


## Holds a grid and a camera so `Callable(picker, "screen_to_cell")` can be passed to
## MHInputRouter.setup. KEEP A REFERENCE to the picker for as long as the router lives.
class TerrainPicker extends RefCounted:
	var grid: MHHeightGrid
	var camera_getter: Callable
	var max_dist_m: float = 2000.0

	## camera_getter: Callable() -> Camera3D (a getter, because the camera is created in _ready).
	func _init(p_grid: MHHeightGrid, p_camera_getter: Callable) -> void:
		grid = p_grid
		camera_getter = p_camera_getter

	func screen_to_cell(screen_pos: Vector2) -> Vector2i:
		var cam: Camera3D = camera_getter.call()
		if cam == null:
			return MHStrokeBridge.NO_CELL
		return MHCellSentinel.pick_terrain(grid, cam.project_ray_origin(screen_pos), cam.project_ray_normal(screen_pos), max_dist_m)

class_name MHCartSurfacePolicy
extends RefCounted
## Shared cart rules derived from the player's painted terrain.
## AI carts obey green restrictions. Free-drive mode may leave paths, but green remains protected.

const PATH_MIN_WEIGHT: int = 96
const GREEN_BLOCK_WEIGHT: int = 64
const WATER_SINK_WEIGHT: int = 96

static func dominant_weight(splat: MHSplatMap, world: Vector3, grid: MHHeightGrid, layer: int) -> int:
	if splat == null or grid == null or grid.cell_size_mm <= 0:
		return 0
	var x: int = clampi(roundi(world.x * 1000.0) / grid.cell_size_mm, 0, splat.samples_x - 1)
	var y: int = clampi(roundi(world.z * 1000.0) / grid.cell_size_mm, 0, splat.samples_y - 1)
	return splat.get_weight(x, y, layer)

static func is_path(splat: MHSplatMap, world: Vector3, grid: MHHeightGrid) -> bool:
	return dominant_weight(splat, world, grid, MHSplatMap.Layer.PATH) >= PATH_MIN_WEIGHT

static func is_green(splat: MHSplatMap, world: Vector3, grid: MHHeightGrid) -> bool:
	return dominant_weight(splat, world, grid, MHSplatMap.Layer.GREEN) >= GREEN_BLOCK_WEIGHT

static func is_water(splat: MHSplatMap, world: Vector3, grid: MHHeightGrid) -> bool:
	return dominant_weight(splat, world, grid, MHSplatMap.Layer.WATER) >= WATER_SINK_WEIGHT

static func ai_can_drive(splat: MHSplatMap, world: Vector3, grid: MHHeightGrid) -> bool:
	return not is_green(splat, world, grid) and not is_water(splat, world, grid)

static func free_drive_surface(splat: MHSplatMap, world: Vector3, grid: MHHeightGrid) -> String:
	if is_water(splat, world, grid):
		return "water"
	if is_green(splat, world, grid):
		return "green"
	if is_path(splat, world, grid):
		return "path"
	return "off_path"

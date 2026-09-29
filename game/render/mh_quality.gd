class_name MHQuality
extends RefCounted
## Quality tier configuration (Low, Medium, High) plus validation and helpers.
## Config values are plain Dictionaries so they are easy to log to bench.json.

const TIER_LOW: String = "low"
const TIER_MEDIUM: String = "medium"
const TIER_HIGH: String = "high"
const TIERS: Array = ["low", "medium", "high"]

const SHADOW_OFF: String = "off"
const SHADOW_LOW: String = "low"
const SHADOW_HIGH: String = "high"

const REQUIRED_KEYS: Array = [
	"name", "shadow_mode", "shadow_atlas_size", "shadow_max_distance", "shadow_splits",
	"blob_shadows", "lod0_end", "lod1_end", "max_golfers", "render_scale_min",
	"render_scale_max", "msaa", "water_waves", "foliage_dither", "target_fps",
]


static func get_tier(tier_name: String) -> Dictionary:
	match tier_name:
		"low":
			return {
				"name": "low", "shadow_mode": "off", "shadow_atlas_size": 1024,
				"shadow_max_distance": 60.0, "shadow_splits": 1, "blob_shadows": true,
				"lod0_end": 0.0, "lod1_end": 120.0, "max_golfers": 20,
				"render_scale_min": 0.6, "render_scale_max": 0.75, "msaa": 0,
				"water_waves": false, "foliage_dither": false, "target_fps": 30,
			}
		"high":
			return {
				"name": "high", "shadow_mode": "high", "shadow_atlas_size": 2048,
				"shadow_max_distance": 160.0, "shadow_splits": 2, "blob_shadows": false,
				"lod0_end": 90.0, "lod1_end": 220.0, "max_golfers": 40,
				"render_scale_min": 0.75, "render_scale_max": 1.0, "msaa": 2,
				"water_waves": true, "foliage_dither": true, "target_fps": 30,
			}
		_:
			return {
				"name": "medium", "shadow_mode": "low", "shadow_atlas_size": 1024,
				"shadow_max_distance": 90.0, "shadow_splits": 1, "blob_shadows": true,
				"lod0_end": 60.0, "lod1_end": 160.0, "max_golfers": 30,
				"render_scale_min": 0.7, "render_scale_max": 0.9, "msaa": 0,
				"water_waves": true, "foliage_dither": true, "target_fps": 30,
			}


static func normalize_name(raw: String) -> String:
	var n: String = raw.strip_edges().to_lower()
	if TIERS.has(n):
		return n
	return TIER_MEDIUM


## Returns an Array of error strings. Empty means valid.
static func validate(cfg: Dictionary) -> Array:
	var errors: Array = []
	for k in REQUIRED_KEYS:
		if not cfg.has(k):
			errors.append("missing key: %s" % k)
	if not errors.is_empty():
		return errors
	if not TIERS.has(str(cfg["name"])):
		errors.append("name not a known tier")
	var sm: String = str(cfg["shadow_mode"])
	if sm != SHADOW_OFF and sm != SHADOW_LOW and sm != SHADOW_HIGH:
		errors.append("shadow_mode invalid")
	var atlas: int = int(cfg["shadow_atlas_size"])
	if atlas < 256 or atlas > 4096 or (atlas & (atlas - 1)) != 0:
		errors.append("shadow_atlas_size must be a power of two in 256..4096")
	if float(cfg["shadow_max_distance"]) <= 0.0:
		errors.append("shadow_max_distance must be > 0")
	var splits: int = int(cfg["shadow_splits"])
	if splits < 1 or splits > 4:
		errors.append("shadow_splits must be 1..4")
	if sm == SHADOW_LOW and splits != 1:
		errors.append("low shadow tier must be a single cascade")
	var l0: float = float(cfg["lod0_end"])
	var l1: float = float(cfg["lod1_end"])
	if l0 < 0.0:
		errors.append("lod0_end must be >= 0")
	if l1 <= l0:
		errors.append("lod1_end must be > lod0_end")
	var g: int = int(cfg["max_golfers"])
	if g < 0 or g > 40:
		errors.append("max_golfers must be 0..40")
	var smin: float = float(cfg["render_scale_min"])
	var smax: float = float(cfg["render_scale_max"])
	if smin < 0.25 or smax > 1.0 or smin > smax:
		errors.append("render scale must satisfy 0.25 <= min <= max <= 1.0")
	var msaa: int = int(cfg["msaa"])
	if msaa != 0 and msaa != 2 and msaa != 4 and msaa != 8:
		errors.append("msaa must be 0, 2, 4 or 8")
	if int(cfg["target_fps"]) < 1:
		errors.append("target_fps must be >= 1")
	return errors


static func msaa_enum(msaa: int) -> int:
	match msaa:
		2:
			return Viewport.MSAA_2X
		4:
			return Viewport.MSAA_4X
		8:
			return Viewport.MSAA_8X
		_:
			return Viewport.MSAA_DISABLED


## Applies light and global shadow settings for a tier. `light` may be null.
static func apply_shadows(cfg: Dictionary, light: DirectionalLight3D) -> void:
	var mode: String = str(cfg["shadow_mode"])
	if mode != SHADOW_OFF:
		RenderingServer.directional_shadow_atlas_set_size(int(cfg["shadow_atlas_size"]), true)
	if light == null:
		return
	light.shadow_enabled = mode != SHADOW_OFF
	if mode == SHADOW_OFF:
		return
	light.directional_shadow_max_distance = float(cfg["shadow_max_distance"])
	if int(cfg["shadow_splits"]) <= 1:
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	else:
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	light.shadow_bias = 0.08
	light.shadow_normal_bias = 1.0

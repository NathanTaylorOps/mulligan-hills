class_name MHEditorTools
extends RefCounted
## Pure description of the hole editor toolbar: terrain tools and paint surfaces.
## Brush modes map to MHBrush.Mode (game/terrain/mh_brush.gd, authoritative). PAINT uses the splat layer
## chosen in the surface picker (MHSplatMap.Layer, 11 layers in course.schema.json order).

const RAISE: StringName = &"raise"
const LOWER: StringName = &"lower"
const SMOOTH: StringName = &"smooth"
const LEVEL: StringName = &"level"
const PAINT: StringName = &"paint"

const RADIUS_MIN: int = 2
const RADIUS_MAX: int = 24
const RADIUS_DEFAULT: int = 8


static func tool_ids() -> Array:
	return [RAISE, LOWER, SMOOTH, LEVEL, PAINT]


static func is_tool(id: StringName) -> bool:
	return tool_ids().has(id)


## Tool id to MHBrush.Mode int. Unknown ids fall back to RAISE.
static func brush_mode(tool_id: StringName) -> int:
	match tool_id:
		LOWER:
			return MHBrush.Mode.LOWER
		SMOOTH:
			return MHBrush.Mode.SMOOTH
		LEVEL:
			return MHBrush.Mode.FLATTEN
		PAINT:
			return MHBrush.Mode.PAINT
	return MHBrush.Mode.RAISE


static func label_key(tool_id: StringName) -> String:
	return "editor.tool." + String(tool_id)


## Surface names in splat layer order (rough, fairway, first_cut, green, ...).
static func surface_names() -> Array:
	return MHSplatMap.LAYER_NAMES.duplicate()


static func surface_layer(surface_name: String) -> int:
	return MHSplatMap.LAYER_NAMES.find(surface_name)


static func surface_label_key(surface_name: String) -> String:
	return "surface." + surface_name


static func clamp_radius(r: int) -> int:
	return clampi(r, RADIUS_MIN, RADIUS_MAX)

class_name MHMowingDesign
extends RefCounted
## Presentation-only mowing design. Patterns never affect lies, physics or ratings.

enum Pattern { STRIPES, DIAGONAL, CROSS_CUT, CHEVRON, ZIG_ZAG, DIAMOND }

const NAMES: Array[String] = ["Stripes", "Diagonal", "Cross-cut", "Chevron", "Zig-zag", "Diamond"]
const MIN_WIDTH_YD: int = 2
const MAX_WIDTH_YD: int = 12

var fairway_pattern: Pattern = Pattern.STRIPES
var green_pattern: Pattern = Pattern.CROSS_CUT
var fairway_width_yd: int = 4
var green_width_yd: int = 2
var direction_deg: int = 0
var intensity: float = 0.065

func pattern_name(pattern: Pattern) -> String:
	return NAMES[clampi(int(pattern), 0, NAMES.size() - 1)]

func set_surface_pattern(surface: int, pattern: Pattern) -> void:
	if surface == MHCraftHole.Surface.GREEN:
		green_pattern = pattern
	else:
		fairway_pattern = pattern

func pattern_for(surface: int) -> Pattern:
	return green_pattern if surface == MHCraftHole.Surface.GREEN else fairway_pattern

func width_for(surface: int) -> int:
	return green_width_yd if surface == MHCraftHole.Surface.GREEN else fairway_width_yd

func highlighted(surface: int, x_yd: float, y_yd: float, along_angle: float) -> bool:
	var pattern: Pattern = pattern_for(surface)
	var width: float = float(maxi(MIN_WIDTH_YD, width_for(surface)))
	var angle: float = along_angle + deg_to_rad(float(direction_deg))
	var ca: float = cos(angle)
	var sa: float = sin(angle)
	var across: float = -x_yd * sa + y_yd * ca
	var along: float = x_yd * ca + y_yd * sa
	match pattern:
		Pattern.STRIPES:
			return _band(across, width)
		Pattern.DIAGONAL:
			return _band(across + along * 0.72, width)
		Pattern.CROSS_CUT:
			return _band(across, width) != _band(along, width)
		Pattern.CHEVRON:
			return _band(absf(across) + along * 0.72, width)
		Pattern.ZIG_ZAG:
			var period: float = width * 4.0
			var phase: float = fposmod(along, period) / period
			var wave: float = (phase * 2.0 if phase < 0.5 else (2.0 - phase * 2.0)) * width * 2.0
			return _band(across + wave, width)
		Pattern.DIAMOND:
			return _band(across + along, width) != _band(across - along, width)
	return false

func to_dict() -> Dictionary:
	return {"v": 1,
		"fairway_pattern": clampi(int(fairway_pattern), 0, Pattern.size() - 1),
		"green_pattern": clampi(int(green_pattern), 0, Pattern.size() - 1),
		"fairway_width_yd": clampi(fairway_width_yd, MIN_WIDTH_YD, MAX_WIDTH_YD),
		"green_width_yd": clampi(green_width_yd, MIN_WIDTH_YD, MAX_WIDTH_YD),
		"direction_deg": posmod(direction_deg, 180),
		"intensity_pm": clampi(roundi(intensity * 1000.0), 20, 140)}


static func is_save_dict_valid(raw: Variant) -> bool:
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = raw as Dictionary
	var keys: Array = ["v", "fairway_pattern", "green_pattern", "fairway_width_yd",
		"green_width_yd", "direction_deg", "intensity_pm"]
	if d.size() != keys.size():
		return false
	for key: String in keys:
		if not d.has(key) or not MHRValidate.is_int_value(d[key]):
			return false
	return int(d["v"]) == 1 		and int(d["fairway_pattern"]) >= 0 and int(d["fairway_pattern"]) < Pattern.size() 		and int(d["green_pattern"]) >= 0 and int(d["green_pattern"]) < Pattern.size() 		and int(d["fairway_width_yd"]) >= MIN_WIDTH_YD and int(d["fairway_width_yd"]) <= MAX_WIDTH_YD 		and int(d["green_width_yd"]) >= MIN_WIDTH_YD and int(d["green_width_yd"]) <= MAX_WIDTH_YD 		and int(d["direction_deg"]) >= 0 and int(d["direction_deg"]) < 180 		and int(d["intensity_pm"]) >= 20 and int(d["intensity_pm"]) <= 140


static func from_dict(raw: Variant) -> MHMowingDesign:
	var out: MHMowingDesign = MHMowingDesign.new()
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var d: Dictionary = raw as Dictionary
	out.fairway_pattern = clampi(int(d.get("fairway_pattern", Pattern.STRIPES)), 0, Pattern.size() - 1) as Pattern
	out.green_pattern = clampi(int(d.get("green_pattern", Pattern.CROSS_CUT)), 0, Pattern.size() - 1) as Pattern
	out.fairway_width_yd = clampi(int(d.get("fairway_width_yd", 4)), MIN_WIDTH_YD, MAX_WIDTH_YD)
	out.green_width_yd = clampi(int(d.get("green_width_yd", 2)), MIN_WIDTH_YD, MAX_WIDTH_YD)
	out.direction_deg = posmod(int(d.get("direction_deg", 0)), 180)
	if typeof(d.get("intensity_pm", null)) == TYPE_INT:
		out.intensity = clampf(float(int(d["intensity_pm"])) / 1000.0, 0.02, 0.14)
	else:
		# Reader compatibility for draft saves made before intensity became integer-backed.
		out.intensity = clampf(float(d.get("intensity", 0.065)), 0.02, 0.14)
	return out

static func _band(value: float, width: float) -> bool:
	return posmod(floori(value / width), 2) == 0

class_name MHUISettings
extends RefCounted
## Player-facing UI settings. Frame cap keeps its own file (MHFrameCapSetting); everything else lives in
## user://mh_ui_settings.cfg. Pure normalisers are static so they can be tested without files.

signal changed(key: String)

const PATH: String = "user://mh_ui_settings.cfg"
const SECTION: String = "ui"
const UNITS_METRIC: String = "metric"
const UNITS_IMPERIAL: String = "imperial"

var units: String = UNITS_METRIC
var analytics_opt_in: bool = false
var consent_shown: bool = false
var text_scale_pct: int = 100
var left_handed: bool = false
## The course grid is the default in-world view; the player can hide it temporarily.
var grid_visible: bool = true
var colorblind: int = 0
var tutorial_done: bool = false
var frame_cap: String = "auto"


static func normalize_units(raw: String) -> String:
	if raw.strip_edges().to_lower() == UNITS_IMPERIAL:
		return UNITS_IMPERIAL
	return UNITS_METRIC


## Placeholder rule: US locales default to imperial (yards and feet), everything else metric.
static func default_units_for_locale(locale: String) -> String:
	var l: String = locale.strip_edges().to_lower().replace("-", "_")
	if l == "en_us" or l.begins_with("en_us"):
		return UNITS_IMPERIAL
	return UNITS_METRIC


static func normalize_colorblind(v: int) -> int:
	return clampi(v, 0, 3)


func is_metric() -> bool:
	return units == UNITS_METRIC


func set_units(raw: String) -> void:
	units = normalize_units(raw)
	changed.emit("units")


func set_analytics_opt_in(v: bool) -> void:
	analytics_opt_in = v
	changed.emit("analytics_opt_in")


func set_consent_shown(v: bool) -> void:
	consent_shown = v
	changed.emit("consent_shown")


func set_text_scale(pct: int) -> void:
	text_scale_pct = MHTheme.clamp_text_scale(pct)
	changed.emit("text_scale_pct")


func set_left_handed(v: bool) -> void:
	left_handed = v
	changed.emit("left_handed")


func set_grid_visible(v: bool) -> void:
	grid_visible = v
	changed.emit("grid_visible")


func set_colorblind(v: int) -> void:
	colorblind = normalize_colorblind(v)
	changed.emit("colorblind")


func set_tutorial_done(v: bool) -> void:
	tutorial_done = v
	changed.emit("tutorial_done")


func set_frame_cap(raw: String) -> void:
	frame_cap = MHFrameGovernor.normalize_setting(raw)
	changed.emit("frame_cap")


func to_dict() -> Dictionary:
	return {
		"units": units,
		"analytics_opt_in": analytics_opt_in,
		"consent_shown": consent_shown,
		"text_scale_pct": text_scale_pct,
		"left_handed": left_handed,
		"grid_visible": grid_visible,
		"colorblind": colorblind,
		"tutorial_done": tutorial_done,
		"frame_cap": frame_cap,
	}


## Applies a dictionary with sanitising; unknown or missing keys keep the current value. No signals.
func apply_dict(d: Dictionary) -> void:
	units = normalize_units(str(d.get("units", units)))
	analytics_opt_in = bool(d.get("analytics_opt_in", analytics_opt_in))
	consent_shown = bool(d.get("consent_shown", consent_shown))
	text_scale_pct = MHTheme.clamp_text_scale(int(d.get("text_scale_pct", text_scale_pct)))
	left_handed = bool(d.get("left_handed", left_handed))
	grid_visible = bool(d.get("grid_visible", grid_visible))
	colorblind = normalize_colorblind(int(d.get("colorblind", colorblind)))
	tutorial_done = bool(d.get("tutorial_done", tutorial_done))
	frame_cap = MHFrameGovernor.normalize_setting(str(d.get("frame_cap", frame_cap)))


## Loads from disk. A missing or unreadable file keeps defaults (locale-based units on first run).
func load_from(path: String = PATH) -> void:
	var cf: ConfigFile = ConfigFile.new()
	if cf.load(path) != OK:
		units = default_units_for_locale(OS.get_locale())
		frame_cap = MHFrameCapSetting.load_value()
		return
	var d: Dictionary = {}
	for key: String in to_dict().keys():
		if cf.has_section_key(SECTION, key):
			d[key] = cf.get_value(SECTION, key)
	apply_dict(d)
	frame_cap = MHFrameCapSetting.load_value()


func save_to(path: String = PATH) -> bool:
	var cf: ConfigFile = ConfigFile.new()
	var d: Dictionary = to_dict()
	for key: String in d.keys():
		if key != "frame_cap":
			cf.set_value(SECTION, key, d[key])
	var ok: bool = cf.save(path) == OK
	MHFrameCapSetting.save_value(frame_cap)
	return ok

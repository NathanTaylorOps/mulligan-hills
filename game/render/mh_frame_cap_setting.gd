class_name MHFrameCapSetting
extends RefCounted
## Player-facing frame cap setting (30 / 60 / auto), persisted in a small ConfigFile.
## UI code (not owned by the render workstream) calls `options()` for labels and `save_value` on change.

const PATH: String = "user://mh_render_settings.cfg"
const SECTION: String = "render"
const KEY: String = "frame_cap"


static func options() -> Array:
	return [
		{"id": "30", "label": "30 fps (saves battery)"},
		{"id": "60", "label": "60 fps (smoother)"},
		{"id": "auto", "label": "Auto (by device)"},
	]


## Returns "30", "60" or "auto". Missing or unreadable file gives "auto".
static func load_value() -> String:
	var cf: ConfigFile = ConfigFile.new()
	var err: int = cf.load(PATH)
	if err != OK:
		return MHFrameGovernor.SETTING_AUTO
	return MHFrameGovernor.normalize_setting(str(cf.get_value(SECTION, KEY, "auto")))


static func save_value(raw: String) -> bool:
	var cf: ConfigFile = ConfigFile.new()
	cf.load(PATH)
	cf.set_value(SECTION, KEY, MHFrameGovernor.normalize_setting(raw))
	return cf.save(PATH) == OK


## Next setting in the cycle 30 -> 60 -> auto -> 30 (for a simple cycle button).
static func next(current: String) -> String:
	var i: int = MHFrameGovernor.SETTINGS.find(MHFrameGovernor.normalize_setting(current))
	return str(MHFrameGovernor.SETTINGS[(i + 1) % MHFrameGovernor.SETTINGS.size()])

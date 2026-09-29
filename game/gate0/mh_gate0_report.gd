class_name MHGate0Report
extends RefCounted
## Builds the evidence dictionaries and text blocks the Gate 0 scenes show and save.
## Evidence fields follow docs/phase0/GATE0.md: item, commit_sha, godot_version, device, renderer,
## date_utc, result, plus the measurements of the item.

const BUILD_INFO_PATH: String = "res://build_info.json"


## Reads res://build_info.json (written by tools/ci/gen_build_info.sh). Missing file gives "dev".
static func commit_sha() -> String:
	if not FileAccess.file_exists(BUILD_INFO_PATH):
		return "dev"
	var f: FileAccess = FileAccess.open(BUILD_INFO_PATH, FileAccess.READ)
	if f == null:
		return "dev"
	return sha_from_build_info_text(f.get_as_text())


static func sha_from_build_info_text(text: String) -> String:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return "dev"
	var d: Dictionary = parsed
	var sha: String = str(d.get("sha", ""))
	return sha if sha != "" else "dev"


static func device_info() -> Dictionary:
	var d: Dictionary = {
		"model": OS.get_model_name(),
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"cpu_count": OS.get_processor_count(),
	}
	return d


static func renderer_name() -> String:
	return str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"))


static func date_utc() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


## Pure. `result` is "pass" or "fail" (lowercase, per GATE0.md). Measurements go in `fields`.
static func evidence(item: String, result: String, fields: Dictionary, sha: String, godot_version: String,
		device: Dictionary, renderer: String, date: String) -> Dictionary:
	var e: Dictionary = {
		"item": item,
		"commit_sha": sha,
		"godot_version": godot_version,
		"device": device,
		"renderer": renderer,
		"date_utc": date,
		"result": result,
	}
	for k: Variant in fields.keys():
		e[k] = fields[k]
	return e


static func evidence_now(item: String, result: String, fields: Dictionary) -> Dictionary:
	return evidence(item, result, fields, commit_sha(), str(Engine.get_version_info().get("string", "unknown")),
		device_info(), renderer_name(), date_utc())


static func to_json(d: Dictionary) -> String:
	return JSON.stringify(d, "  ", true)


## Standard header lines shown at the top of every result panel.
static func header_lines(title: String) -> String:
	var dev: Dictionary = device_info()
	return "%s\nbuild: %s   godot: %s   renderer: %s\ndevice: %s (%s %s)\ngpu: %s\n" % [
		title, commit_sha(), str(Engine.get_version_info().get("string", "?")), renderer_name(),
		dev["model"], dev["os"], dev["os_version"], dev["gpu"]]


static func pass_fail(ok: bool) -> String:
	return "PASS" if ok else "FAIL"

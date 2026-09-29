class_name MHBuildInfo
extends RefCounted
## Reads res://build_info.json, written by tools/ci/gen_build_info.sh. The file is
## optional (git-ignored, absent in the editor and in unit tests): everything falls
## back to "dev".

const PATH: String = "res://build_info.json"


static func fallback() -> Dictionary:
	return {"sha": "dev", "run_number": "dev", "run_id": "dev", "built_at": "dev", "workflow": "dev", "renderer": "dev"}


## Parse JSON text into the info dictionary; missing or bad keys become "dev".
static func parse(text: String) -> Dictionary:
	var info: Dictionary = fallback()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return info
	var d: Dictionary = parsed
	for key: String in info.keys():
		if d.has(key) and str(d[key]) != "":
			info[key] = str(d[key])
	return info


static func load(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return fallback()
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return fallback()
	return parse(f.get_as_text())


static func label_text(info: Dictionary = {}) -> String:
	var d: Dictionary = info if not info.is_empty() else MHBuildInfo.load()
	if str(d.get("sha", "dev")) == "dev" and str(d.get("run_number", "dev")) == "dev":
		return "Build: dev"
	return "Build #%s  %s  %s\n%s  %s" % [d.get("run_number", "?"), d.get("sha", "?"), d.get("renderer", "?"), d.get("workflow", "?"), d.get("built_at", "?")]

extends SceneTree
## CI-only project script loader. One headless Godot process loads every first-party .gd resource so scripts that
## ordinary --import never touches still have to compile. Third-party addons are tested through their consumers.

const SELF_PATH: String = "res://tests/ci/check_project_scripts.gd"

var _paths: Array[String] = []
var _failures: Array[String] = []


func _initialize() -> void:
	_collect("res://")
	_paths.sort()
	for path: String in _paths:
		if path == SELF_PATH or path.begins_with("res://addons/"):
			continue
		var resource: Resource = ResourceLoader.load(path)
		if resource == null:
			_failures.append(path)
	if not _failures.is_empty():
		for path: String in _failures:
			printerr("SCRIPT_CHECK FAIL: " + path)
		quit(1)
		return
	print("SCRIPT_CHECK PASS: %d first-party GDScript files loaded" % _paths.size())
	quit(0)


func _collect(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		_failures.append(dir_path)
		return
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name == "":
			break
		if name == "." or name == "..":
			continue
		var path: String = dir_path.path_join(name)
		if dir.current_is_dir():
			if name == ".godot":
				continue
			_collect(path)
		elif name.ends_with(".gd"):
			_paths.append(path)
	dir.list_dir_end()

extends GdUnitTestSuite
## CI grep check from docs/spec/interfaces/ui_shell.md: no literal user-visible text in screens, widgets or
## modals. Visible text must go through MHStrings. NOT YET RUN (reads res://ui source files).

const DIRS: Array = ["res://ui/screens", "res://ui/modals", "res://ui/widgets"]


func _scripts(dir_path: String) -> Array:
	var out: Array = []
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path + "/" + f)
	return out


func test_no_literal_text_in_ui_code() -> void:
	var bad: RegEx = RegEx.create_from_string("(\\.text\\s*=\\s*\"[^\"])|(MHUIKit\\.label\\(\"[^\"])|(MHUIKit\\.button\\([a-z_.]+,\\s*\"[^\"])")
	var checked: int = 0
	for dir_path: Variant in DIRS:
		for path: Variant in _scripts(str(dir_path)):
			var src: String = FileAccess.get_file_as_string(str(path))
			checked += 1
			var lines: PackedStringArray = src.split("\n")
			for i: int in range(lines.size()):
				var line: String = lines[i]
				if line.strip_edges().begins_with("#"):
					continue
				assert_bool(bad.search(line) == null).override_failure_message("literal text at %s:%d" % [str(path), i + 1]).is_true()
	assert_int(checked).is_greater(0)

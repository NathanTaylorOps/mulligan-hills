class_name MHTestEdit
extends RefCounted
## Test helper: set a value deep inside nested Dictionaries and Arrays, e.g.
## MHTestEdit.put(raw, ["levels", 0, "entry", "min_holes"], 5). Keys are Dictionary keys, ints are Array indexes.


static func put(root: Variant, path: Array, value: Variant) -> void:
	var node: Variant = root
	for i: int in range(path.size() - 1):
		node = node[path[i]]
	node[path[path.size() - 1]] = value

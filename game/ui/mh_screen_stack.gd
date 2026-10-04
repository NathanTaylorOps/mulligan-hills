class_name MHScreenStack
extends RefCounted
## Pure screen id stack behind MHUIShell. The bottom entry (root) can never be popped.

const MAX_DEPTH: int = 8

var _ids: PackedStringArray = PackedStringArray()


func depth() -> int:
	return _ids.size()


func top() -> String:
	if _ids.is_empty():
		return ""
	return _ids[_ids.size() - 1]


func at(index: int) -> String:
	if index < 0 or index >= _ids.size():
		return ""
	return _ids[index]


func ids() -> PackedStringArray:
	return _ids.duplicate()


func contains(id: String) -> bool:
	return _ids.has(id)


func can_pop() -> bool:
	return _ids.size() > 1


## False (and no change) for an empty id, the same id already on top, or a full stack.
func push(id: String) -> bool:
	if id == "" or id == top() or _ids.size() >= MAX_DEPTH:
		return false
	_ids.append(id)
	return true


## Removes and returns the top id. Returns "" and does nothing when only the root remains.
func pop() -> String:
	if not can_pop():
		return ""
	var id: String = _ids[_ids.size() - 1]
	_ids.remove_at(_ids.size() - 1)
	return id


## Swaps the top id. False for an empty id or an empty stack.
func replace_top(id: String) -> bool:
	if id == "" or _ids.is_empty():
		return false
	_ids[_ids.size() - 1] = id
	return true


## Clears everything and makes `id` the only entry.
func reset(id: String) -> void:
	_ids = PackedStringArray()
	if id != "":
		_ids.append(id)


## Pops until `id` is on top. Returns how many were popped, or 0 if id is not in the stack (no change).
func pop_to(id: String) -> int:
	if not _ids.has(id):
		return 0
	var n: int = 0
	while top() != id and can_pop():
		pop()
		n += 1
	return n

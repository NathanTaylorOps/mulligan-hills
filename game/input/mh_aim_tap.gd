class_name MHAimTap
extends RefCounted
## Pure pointer ownership: a world tap selects an aim only; never commits a shot.
const SLOP: float = 18.0
var _contacts: Dictionary = {}
var _multiple: bool = false

func down(id: int, pos: Vector2, blocked: bool) -> bool:
	_contacts[id] = {"start": pos, "world": not blocked, "moved": false}
	if _contacts.size() > 1:
		_multiple = true
	return not blocked

func drag(id: int, pos: Vector2) -> bool:
	if not _contacts.has(id):
		return false
	var row: Dictionary = _contacts[id]
	if pos.distance_to(row["start"] as Vector2) > SLOP:
		row["moved"] = true
	return bool(row["world"])

func up(id: int, pos: Vector2, blocked: bool, cancelled: bool = false) -> Dictionary:
	if not _contacts.has(id):
		return {"consume": false, "aim": false}
	var row: Dictionary = _contacts[id]
	_contacts.erase(id)
	var aimed: bool = bool(row["world"]) and not bool(row["moved"]) and not _multiple \
		and not blocked and not cancelled and pos.distance_to(row["start"] as Vector2) <= SLOP
	if _contacts.is_empty():
		_multiple = false
	return {"consume": bool(row["world"]), "aim": aimed}

func clear() -> void:
	_contacts.clear()
	_multiple = false

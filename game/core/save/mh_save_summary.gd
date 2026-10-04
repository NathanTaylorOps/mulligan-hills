class_name MHSaveSummary
extends RefCounted
## The few facts about a save that UIs and cloud sync compare: slot list rows and cloud conflict prompts.
## Built from a sealed save document, or from a Dictionary sent by the cloud service.

var slot: int = 0
var revision: int = 0
var checksum: String = ""
var install_id: String = ""
var saved_at_unix: int = 0
var day: int = 0
## Cash in the economy module's smallest whole unit (cents). Displayed by the UI, never converted here.
var cash: int = 0
var holes: int = 0
## Whole seconds played. 0 when the save has no progress.playtime_s (field pending a schema addition).
var playtime_s: int = 0


static func from_doc(d: Dictionary) -> MHSaveSummary:
	var s := MHSaveSummary.new()
	s.slot = _geti(d, "slot")
	s.revision = _geti(d, "revision")
	s.saved_at_unix = _geti(d, "saved_at_unix")
	s.install_id = String(d.get("install_id", ""))
	var cs: Variant = d.get("checksum", null)
	if typeof(cs) == TYPE_DICTIONARY:
		s.checksum = String((cs as Dictionary).get("value", ""))
	var world: Variant = d.get("world", null)
	if typeof(world) == TYPE_DICTIONARY:
		s.day = _geti(world, "day")
	var club: Variant = d.get("club", null)
	if typeof(club) == TYPE_DICTIONARY:
		s.cash = _geti(club, "cash")
	var course: Variant = d.get("course", null)
	if typeof(course) == TYPE_DICTIONARY:
		var holes_v: Variant = (course as Dictionary).get("holes", null)
		if typeof(holes_v) == TYPE_ARRAY:
			s.holes = (holes_v as Array).size()
	var pr: Variant = d.get("progress", null)
	if typeof(pr) == TYPE_DICTIONARY:
		s.playtime_s = _geti(pr, "playtime_s")
	return s


static func from_dict(d: Dictionary) -> MHSaveSummary:
	var s := MHSaveSummary.new()
	s.slot = _geti(d, "slot")
	s.revision = _geti(d, "revision")
	s.checksum = String(d.get("checksum", ""))
	s.install_id = String(d.get("install_id", ""))
	s.saved_at_unix = _geti(d, "saved_at_unix")
	s.day = _geti(d, "day")
	s.cash = _geti(d, "cash")
	s.holes = _geti(d, "holes")
	s.playtime_s = _geti(d, "playtime_s")
	return s


func to_dict() -> Dictionary:
	return {
		"slot": slot, "revision": revision, "checksum": checksum, "install_id": install_id,
		"saved_at_unix": saved_at_unix, "day": day, "cash": cash, "holes": holes, "playtime_s": playtime_s,
	}


static func _geti(d: Dictionary, key: String) -> int:
	var v: Variant = d.get(key, 0)
	if typeof(v) == TYPE_INT:
		return int(v)
	if typeof(v) == TYPE_FLOAT:
		var f: float = v
		if f == floor(f) and absf(f) <= 9007199254740991.0:
			return int(f)
	return 0

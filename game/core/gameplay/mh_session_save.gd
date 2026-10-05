class_name MHSessionSave
extends RefCounted
## Exact accounting bridge to official slots, including lossless primitive finalized holes.
## Legacy dm polygons require their own adapter; they must never be guessed or silently erased.
@warning_ignore_start("integer_division")

static func capture(session: MHGameSession, source: Dictionary) -> MHSaveResult:
	var nr: MHSaveResult = MHSaveGame.normalize(source)
	if not nr.is_ok():
		return nr
	var doc: Dictionary = nr.value
	if not MHSaveGame.validate(doc).is_empty() or not _live_shape(doc):
		return _bad("source document is malformed")
	if typeof(doc.get("course", null)) != TYPE_DICTIONARY:
		return _bad("course document missing")
	var course: Dictionary = doc["course"]
	var layouts: MHSaveResult = MHCourseLayout.decode(course)
	if not layouts.is_ok():
		return layouts
	if layouts.value != session.hole_definitions():
		return _bad("course geometry and live session disagree")
	doc["min_reader_version"] = 3 if int(course.get("schema_version", 1)) == 2 else 2
	doc["world"] = {"day": session.clock.day(), "minute_of_day": session.clock.minute_of_day(),
		"season": str((doc.get("world", {}) as Dictionary).get("season", "spring"))}
	var club: Dictionary = doc["club"]
	club["cash"] = session.economy.cash / 100
	club["green_fee"] = session.economy.fee / 100
	club["lifetime_earned"] = session.economy.total_revenue / 100
	club["members"] = session.economy.members()
	club["reputation"] = session.economy.reputation
	club["prestige"] = session.bridge.club_points()
	doc["club"] = club
	var tiers: Dictionary = session.tiers()
	var buildings: Array = []
	for id: Variant in session.economy.params.building_ids:
		buildings.append({"id": str(id), "tier": int(tiers[str(id)])})
	doc["buildings"] = buildings
	var ids: Array = []
	for id: int in session.land.owned_ids():
		ids.append(id)
	doc["land"] = {"owned_parcel_ids": ids}
	for parcel: Variant in (course["world"] as Dictionary)["parcels"]:
		var p: Dictionary = parcel
		p["owned"] = session.land.is_owned(int(p["parcel_id"]))
	doc["sim"]["rating_epoch"] = session.rating_epoch
	doc["ratings"] = {"rating_version": MHRatingEngine.RATING_VERSION, "computed_day": session.clock.day(),
		"course_score": int(session.course_result().get("course_x10", 0)) / 10, "holes": _rating_rows(session)}
	var progress: Dictionary = doc["progress"]
	progress.merge(session.bridge.to_save_progress(), true)
	doc["progress"] = progress
	doc["runtime"] = {"v": 1, "clock": session.clock.to_dict(), "economy": session.economy.to_dict(),
		"save_secret": session.save_secret, "recent_scores": session.recent_scores.duplicate(),
		"ledger_hash": MHSaveGame.canonical_json(session.ledger.to_dict()).sha256_text(),
		"terrain_bytes_hash": str((source.get("runtime", {}) as Dictionary).get("terrain_bytes_hash", "0".repeat(64)))}
	if session.practice != null:
		doc["runtime"]["practice"] = session.practice.to_dict()
		doc["min_reader_version"] = 3
	MHSaveGame.seal(doc)
	var normalized: MHSaveResult = MHSaveGame.normalize(doc)
	if not normalized.is_ok():
		return normalized
	var errs: Array = MHSaveGame.validate(normalized.value as Dictionary)
	if not errs.is_empty():
		return _bad(str(errs[0]))
	var checked: MHSaveResult = restore(normalized.value as Dictionary, session.ledger)
	if not checked.is_ok():
		return checked
	return MHSaveResult.success(normalized.value)


## Returns a NEW fully restored session, never partly mutates a running one. Ledger remains separate.
static func restore(source: Dictionary, ledger: MHTokenLedger) -> MHSaveResult:
	var nr: MHSaveResult = MHSaveGame.normalize(source)
	if not nr.is_ok():
		return nr
	var doc: Dictionary = nr.value
	var errors: Array = MHSaveGame.validate(doc)
	if not errors.is_empty():
		return _bad(str(errors[0]))
	if not _live_shape(doc):
		return _bad("checkpoint shape invalid")
	if not MHSaveGame.checksum_ok(doc):
		return _bad("checkpoint checksum mismatch")
	if not doc.has("runtime"):
		return _bad("this slot has no live accounting checkpoint; it was not modified")
	var layouts: MHSaveResult = MHCourseLayout.decode(doc["course"] as Dictionary)
	if not layouts.is_ok():
		return layouts
	var s: MHGameSession = MHGameSession.create()
	if s == null:
		return _bad("game data failed to load")
	var rt: Dictionary = doc["runtime"]
	if ledger == null or ledger.paid != 0 or str(rt["ledger_hash"]) != MHSaveGame.canonical_json(ledger.to_dict()).sha256_text():
		return _bad("ledger and checkpoint generations disagree")
	if not s.clock.from_dict(rt["clock"] as Dictionary) or not s.economy.from_dict(rt["economy"] as Dictionary):
		return _bad("clock or economy checkpoint invalid")
	var ids: PackedInt32Array = PackedInt32Array()
	for id: Variant in (doc["land"] as Dictionary)["owned_parcel_ids"]:
		ids.append(int(id))
	if s.land.load_owned(ids) != "":
		return _bad("land ownership invalid")
	if int(doc["world"]["day"]) != s.clock.day() or int(doc["world"].get("minute_of_day", 0)) != s.clock.minute_of_day():
		return _bad("saved world and clock disagree")
	for parcel: Variant in doc["course"]["world"]["parcels"]:
		var p: Dictionary = parcel
		if bool(p["owned"]) != s.land.is_owned(int(p["parcel_id"])):
			return _bad("course parcel ownership disagrees")
	if s.economy.day != s.clock.day() or s.economy.hour != s.clock.minute_of_day() / 60:
		return _bad("clock and accounting disagree")
	s.save_secret = int(rt["save_secret"])
	s.rating_epoch = int(doc["sim"]["rating_epoch"])
	if not s.restore_course(layouts.value as Array):
		return _bad("saved course cannot be officially rated")
	if s.economy.holes != s.hole_scores().size() or s.economy.rating != int(s.course_result().get("course_x10", 0)) / 10 or s.economy.parcels != s.land.owned_count():
		return _bad("accounting and course disagree")
	var club: Dictionary = doc["club"]
	if int(club["cash"]) != s.economy.cash / 100 or int(club["green_fee"]) != s.economy.fee / 100 \
		or int(club["lifetime_earned"]) != s.economy.total_revenue / 100 \
		or int(club["members"]) != s.economy.members() or int(club["reputation"]) != s.economy.reputation:
		return _bad("club and accounting disagree")
	var saved_tiers: Dictionary = {}
	for row: Variant in doc["buildings"]:
		var b: Dictionary = row
		if saved_tiers.has(str(b["id"])):
			return _bad("duplicate building")
		saved_tiers[str(b["id"])] = int(b["tier"])
	if saved_tiers != s.tiers():
		return _bad("building tiers disagree")
	if not s.bridge.load_save_progress(doc["progress"] as Dictionary):
		return _bad("progress checkpoint invalid")
	# Until real staffing exists, do not manufacture an aggregate from a legacy model.
	if typeof(club.get("staff", null)) != TYPE_DICTIONARY:
		return _bad("staff checkpoint missing")
	for v: Variant in (club["staff"] as Dictionary).values():
		if int(v) != 0:
			return _bad("live staffing is not implemented")
	s.ledger = ledger
	s.save_secret = int(rt["save_secret"])
	s.rating_epoch = int(doc["sim"]["rating_epoch"])
	s.recent_scores = (rt["recent_scores"] as Array).duplicate()
	if rt.has("practice"):
		if not MHRValidate.is_int_value(rt["practice"].get("slot_id", null)):
			return _bad("practice hole identity invalid")
		var found: bool = false
		for layout: Variant in layouts.value:
			if int(layout["slot_id"]) == int(rt["practice"].get("slot_id", -1)):
				s.practice = MHPracticeRound.restore(layout as Dictionary, rt["practice"] as Dictionary)
				found = s.practice != null
				break
		if not found:
			return _bad("practice round and saved geometry disagree")
	s.unix_now = int(doc["saved_at_unix"])
	return MHSaveResult.success(s)


static func _bad(message: String) -> MHSaveResult:
	return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, message)


## Development checkpoint ledger is a separate immutable generation, addressed by its equality hash.
## Old generations are retained so failed/torn writes cannot lose the matching ledger for a recovered slot.
static func load_ledger(doc: Dictionary, directory: String) -> MHSaveResult:
	var errors: Array = MHSaveGame.validate(doc)
	if not errors.is_empty() or not doc.has("runtime"):
		return _bad("valid live checkpoint required")
	var hash_value: String = str(doc["runtime"]["ledger_hash"])
	var ledger: MHTokenLedger = MHTokenLedger.new()
	var loaded: MHSaveResult = ledger.load_from(directory + "/" + hash_value + ".json")
	if not loaded.is_ok():
		return loaded
	if MHSaveGame.canonical_json(ledger.to_dict()).sha256_text() != hash_value:
		return _bad("ledger content does not match checkpoint")
	return MHSaveResult.success(ledger)


static func _live_shape(doc: Dictionary) -> bool:
	for key: String in ["course", "club", "world", "sim", "progress"]:
		if typeof(doc.get(key, null)) != TYPE_DICTIONARY:
			return false
	var c: Dictionary = doc["course"]
	if typeof(c.get("world", null)) != TYPE_DICTIONARY or typeof(c.get("holes", null)) != TYPE_ARRAY:
		return false
	if typeof(c["world"].get("parcels", null)) != TYPE_ARRAY:
		return false
	for row: Variant in c["world"]["parcels"]:
		if typeof(row) != TYPE_DICTIONARY:
			return false
		var p: Dictionary = row
		if typeof(p.get("parcel_id", null)) != TYPE_INT or typeof(p.get("owned", null)) != TYPE_BOOL:
			return false
	for key: String in ["cash", "green_fee", "lifetime_earned", "members", "reputation"]:
		if typeof(doc["club"].get(key, null)) != TYPE_INT:
			return false
	return typeof(doc["world"].get("day", null)) == TYPE_INT and typeof(doc["sim"].get("rating_epoch", null)) == TYPE_INT


static func _rating_rows(s: MHGameSession) -> Array:
	var out: Array = []
	var defs: Array = s.hole_definitions()
	var results: Array = s.hole_results()
	for i: int in range(results.size()):
		var r: Dictionary = results[i]
		out.append({"hole_no": int((defs[i] as Dictionary)["slot_id"]) + 1, "score": int(r["score"]),
			"axes": {"accuracy": int(r["A"]) / 10, "imagination": int(r["I"]) / 10,
				"length": int(r["Len"]) / 10, "beauty": int(r["B"]) / 10, "fairness": int(r["F"]) / 10}})
	return out

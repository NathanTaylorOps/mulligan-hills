class_name MHEventDeck
extends RefCounted
## Random event and decision cards. Loads event_cards.json (schema docs/spec/data/event_cards.schema.json),
## picks cards with weighted deterministic draws from an MHRng, and returns effects as data.
## The deck NEVER applies effects: the caller (economy/club state) applies them.
##
## Context dictionary passed to draws (all optional, defaults in brackets):
##   "day" int [0], "tier" int [0], "season" String ["spring"], "members" int [0], "avg_hole_score" int [0],
##   "tags" Array of String [[]] (course state tags, e.g. "has_restaurant", "recent_rain"), "flags" Array of String [[]].
## Draw algorithm (must stay stable, tests pin golden sequences):
##   1. Eligible cards are collected in FILE ORDER.
##   2. total = sum of weights; r = rng.bounded(total); the first card whose running weight sum exceeds r wins.
##   3. roll_daily first consumes exactly one rng.bounded(1000) and only draws if that roll is below permille.
##   4. When nothing is eligible, draw consumes no rng values and returns an empty Dictionary.
## Cooldown: a card is blocked while (day - last_fired_day) < cooldown_days. "once" cards fire at most once.

const DEFAULT_PATH: String = "res://data/event_cards.json"
const SAVE_VERSION: int = 1
const EFFECT_OPS: Array = [
	"add_cash", "add_reputation", "add_members", "add_prestige", "set_flag", "clear_flag", "weather_next_day",
	"golfer_flow_pct",
]

var load_error: String = ""

var _cards: Array = []
var _ids: PackedStringArray = PackedStringArray()
var _last_day: PackedInt32Array = PackedInt32Array()
var _fired: PackedInt32Array = PackedInt32Array()


static func make_context(day: int, tier: int, season: String, members: int, avg_hole_score: int, tags: Array, flags: Array) -> Dictionary:
	return {
		"day": day,
		"tier": tier,
		"season": season,
		"members": members,
		"avg_hole_score": avg_hole_score,
		"tags": tags,
		"flags": flags,
	}


func card_count() -> int:
	return _cards.size()


func card_at(index: int) -> Dictionary:
	if index < 0 or index >= _cards.size():
		return {}
	return _cards[index] as Dictionary


func index_of(card_id: String) -> int:
	return _ids.find(card_id)


func get_card(card_id: String) -> Dictionary:
	return card_at(index_of(card_id))


func load_from_file(path: String = DEFAULT_PATH) -> bool:
	if not FileAccess.file_exists(path):
		load_error = "file not found: " + path
		return false
	var text: String = FileAccess.get_file_as_string(path)
	return load_from_text(text)


func load_from_text(text: String) -> bool:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		load_error = "not a JSON object"
		return false
	return load_from_dict(parsed as Dictionary)


## Structural validation only (the full schema check runs in Python/CI). Resets fired state.
func load_from_dict(d: Dictionary) -> bool:
	load_error = ""
	if str(d.get("schema", "")) != "mh.event_cards":
		load_error = "wrong schema"
		return false
	if int(d.get("schema_version", 0)) != 1:
		load_error = "unsupported schema_version"
		return false
	var cards_v: Variant = d.get("cards", null)
	if typeof(cards_v) != TYPE_ARRAY or (cards_v as Array).is_empty():
		load_error = "cards missing or empty"
		return false
	var new_cards: Array = []
	var new_ids: PackedStringArray = PackedStringArray()
	for c in (cards_v as Array):
		if typeof(c) != TYPE_DICTIONARY:
			load_error = "card is not an object"
			return false
		var card: Dictionary = c as Dictionary
		var cid: String = str(card.get("id", ""))
		if cid.is_empty() or new_ids.has(cid):
			load_error = "missing or duplicate card id: " + cid
			return false
		var w: int = int(card.get("weight", 0))
		if w < 1 or w > 1000:
			load_error = "bad weight on " + cid
			return false
		var ch_v: Variant = card.get("choices", null)
		if typeof(ch_v) != TYPE_ARRAY or (ch_v as Array).size() < 2 or (ch_v as Array).size() > 3:
			load_error = "bad choices on " + cid
			return false
		var bad: String = _check_choices(cid, ch_v as Array)
		if not bad.is_empty():
			load_error = bad
			return false
		new_ids.append(cid)
		new_cards.append(card)
	_cards = new_cards
	_ids = new_ids
	_last_day = PackedInt32Array()
	_fired = PackedInt32Array()
	for i in range(_cards.size()):
		_last_day.append(-1)
		_fired.append(0)
	return true


## Returns "" when every choice and effect of a card is well formed, otherwise a message.
func _check_choices(cid: String, choices: Array) -> String:
	var seen: PackedStringArray = PackedStringArray()
	for c in choices:
		if typeof(c) != TYPE_DICTIONARY:
			return "choice is not an object on " + cid
		var ch: Dictionary = c as Dictionary
		var chid: String = str(ch.get("id", ""))
		if chid.is_empty() or seen.has(chid):
			return "missing or duplicate choice id on " + cid
		seen.append(chid)
		var ef_v: Variant = ch.get("effects", null)
		if typeof(ef_v) != TYPE_ARRAY:
			return "effects missing on " + cid + "/" + chid
		for e in (ef_v as Array):
			if typeof(e) != TYPE_DICTIONARY:
				return "effect is not an object on " + cid + "/" + chid
			var ed: Dictionary = e as Dictionary
			if not EFFECT_OPS.has(str(ed.get("op", ""))) or not ed.has("amount"):
				return "bad effect on " + cid + "/" + chid
			var op: String = str(ed["op"])
			if (op == "set_flag" or op == "clear_flag") and str(ed.get("flag", "")).is_empty():
				return "flag missing on " + cid + "/" + chid
			if op == "golfer_flow_pct" and int(ed.get("days", 0)) < 1:
				return "days missing on " + cid + "/" + chid
	return ""


func _has_all(have: Variant, need: Variant) -> bool:
	if typeof(need) != TYPE_ARRAY:
		return true
	for n in (need as Array):
		if not _contains(have, str(n)):
			return false
	return true


func _has_none(have: Variant, banned: Variant) -> bool:
	if typeof(banned) != TYPE_ARRAY:
		return true
	for n in (banned as Array):
		if _contains(have, str(n)):
			return false
	return true


func _contains(have: Variant, s: String) -> bool:
	if typeof(have) != TYPE_ARRAY:
		return false
	for h in (have as Array):
		if str(h) == s:
			return true
	return false


func is_eligible(index: int, ctx: Dictionary) -> bool:
	if index < 0 or index >= _cards.size():
		return false
	var card: Dictionary = _cards[index] as Dictionary
	var day: int = int(ctx.get("day", 0))
	if bool(card.get("once", false)) and _fired[index] > 0:
		return false
	var last: int = _last_day[index]
	if last >= 0 and day - last < int(card.get("cooldown_days", 0)):
		return false
	if day < int(card.get("min_day", 0)):
		return false
	if card.has("min_avg_hole_score") and int(ctx.get("avg_hole_score", 0)) < int(card["min_avg_hole_score"]):
		return false
	if card.has("min_members") and int(ctx.get("members", 0)) < int(card["min_members"]):
		return false
	var tier: int = int(ctx.get("tier", 0))
	if card.has("min_tier") and tier < int(card["min_tier"]):
		return false
	if card.has("max_tier") and tier > int(card["max_tier"]):
		return false
	if card.has("seasons"):
		if not _contains(card["seasons"], str(ctx.get("season", "spring"))):
			return false
	var tags: Variant = ctx.get("tags", [])
	if not _has_all(tags, card.get("requires_tags", null)):
		return false
	if not _has_none(tags, card.get("forbids_tags", null)):
		return false
	var flags: Variant = ctx.get("flags", [])
	if not _has_all(flags, card.get("requires_flags", null)):
		return false
	if not _has_none(flags, card.get("forbids_flags", null)):
		return false
	return true


## Indices of eligible cards in file order.
func eligible_indices(ctx: Dictionary) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i in range(_cards.size()):
		if is_eligible(i, ctx):
			out.append(i)
	return out


## Weighted draw. Marks the card as fired on ctx["day"]. Returns the card, or {} when nothing is eligible.
func draw(rng: MHRng, ctx: Dictionary) -> Dictionary:
	var elig: PackedInt32Array = eligible_indices(ctx)
	if elig.is_empty():
		return {}
	var total: int = 0
	for i in elig:
		total += int((_cards[i] as Dictionary).get("weight", 1))
	var r: int = rng.bounded(total)
	var run: int = 0
	var chosen: int = elig[elig.size() - 1]
	for i in elig:
		run += int((_cards[i] as Dictionary).get("weight", 1))
		if r < run:
			chosen = i
			break
	_last_day[chosen] = int(ctx.get("day", 0))
	_fired[chosen] += 1
	return _cards[chosen] as Dictionary


## Daily roll: one rng.bounded(1000) decides whether an event happens (permille from remote config
## events.random_event_per_day_permille), then draw(). Returns {} for no event.
func roll_daily(rng: MHRng, ctx: Dictionary, permille: int) -> Dictionary:
	var roll: int = rng.bounded(1000)
	if roll >= clampi(permille, 0, 1000):
		return {}
	return draw(rng, ctx)


func choice_available(card_id: String, choice_id: String, cash: int, reputation: int) -> bool:
	var ch: Dictionary = _find_choice(get_card(card_id), choice_id)
	if ch.is_empty():
		return false
	if ch.has("requires"):
		var req: Dictionary = ch["requires"] as Dictionary
		if cash < int(req.get("min_cash", 0)):
			return false
		if reputation < int(req.get("min_reputation", 0)):
			return false
	return true


## Effects of a choice as Array of Dictionary {"op": String, "amount": int, optional "flag": String, "days": int}.
## add_cash amounts are scaled by cash_scale_pct (remote config events.event_cash_scale_pct, default 100),
## truncating toward zero. Unknown card or choice returns an empty Array.
func resolve_choice(card_id: String, choice_id: String, cash_scale_pct: int = 100) -> Array:
	var out: Array = []
	var ch: Dictionary = _find_choice(get_card(card_id), choice_id)
	if ch.is_empty():
		return out
	for e in (ch["effects"] as Array):
		var src: Dictionary = e as Dictionary
		var eff: Dictionary = {"op": str(src["op"]), "amount": int(src["amount"])}
		if src.has("flag"):
			eff["flag"] = str(src["flag"])
		if src.has("days"):
			eff["days"] = int(src["days"])
		if str(eff["op"]) == "add_cash":
			@warning_ignore("integer_division")
			var scaled: int = (int(eff["amount"]) * cash_scale_pct) / 100
			eff["amount"] = scaled
		out.append(eff)
	return out


func _find_choice(card: Dictionary, choice_id: String) -> Dictionary:
	if card.is_empty():
		return {}
	for c in (card["choices"] as Array):
		var cd: Dictionary = c as Dictionary
		if str(cd.get("id", "")) == choice_id:
			return cd
	return {}


func fired_count(card_id: String) -> int:
	var i: int = index_of(card_id)
	if i < 0:
		return 0
	return _fired[i]


func last_fired_day(card_id: String) -> int:
	var i: int = index_of(card_id)
	if i < 0:
		return -1
	return _last_day[i]


## Save state: only cards that have fired, in file order (stable output).
func to_dict() -> Dictionary:
	var fired: Array = []
	for i in range(_cards.size()):
		if _fired[i] > 0:
			fired.append({"id": _ids[i], "day": _last_day[i], "count": _fired[i]})
	return {"v": SAVE_VERSION, "fired": fired}


## Same fired state in the shape of save.schema.json progress.card_history: [{"card_id", "last_day"}], file order.
## The fire count is not stored there; from_card_history restores a count of 1, which is all "once" cards need.
func to_card_history() -> Array:
	var out: Array = []
	for i in range(_cards.size()):
		if _fired[i] > 0:
			out.append({"card_id": _ids[i], "last_day": _last_day[i]})
	return out


func from_card_history(history: Array) -> bool:
	for i in range(_cards.size()):
		_last_day[i] = -1
		_fired[i] = 0
	for e in history:
		if typeof(e) != TYPE_DICTIONARY:
			return false
		var ed: Dictionary = e as Dictionary
		var idx: int = index_of(str(ed.get("card_id", "")))
		if idx < 0:
			continue
		_last_day[idx] = int(ed.get("last_day", 0))
		_fired[idx] = 1
	return true


## Restores fired state onto the currently loaded cards. Unknown ids are ignored. Returns false if malformed.
func from_dict(d: Dictionary) -> bool:
	var fv: Variant = d.get("fired", null)
	if typeof(fv) != TYPE_ARRAY:
		return false
	for i in range(_cards.size()):
		_last_day[i] = -1
		_fired[i] = 0
	for e in (fv as Array):
		if typeof(e) != TYPE_DICTIONARY:
			return false
		var ed: Dictionary = e as Dictionary
		var idx: int = index_of(str(ed.get("id", "")))
		if idx < 0:
			continue
		_last_day[idx] = int(ed.get("day", -1))
		_fired[idx] = int(ed.get("count", 1))
	return true

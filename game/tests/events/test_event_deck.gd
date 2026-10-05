extends GdUnitTestSuite
## MHEventDeck and the shipped card data. Golden draw sequences come from a Python mirror of the draw algorithm
## and of MHRng (tools/reference/determinism/mh_rng.py). NOT YET RUN in Godot.

const DATA_PATH: String = "res://data/event_cards.json"
const DOCS_COPY: String = "../docs/spec/data/event_cards.json"
const SUMMER_TAGS: Array = ["has_restaurant", "has_pro_shop", "busy", "has_bunkers"]


func _deck() -> MHEventDeck:
	var d := MHEventDeck.new()
	assert_bool(d.load_from_file(DATA_PATH)).is_true()
	return d


func _ctx(day: int) -> Dictionary:
	return MHEventDeck.make_context(day, 2, "summer", 30, 40, SUMMER_TAGS, [])


func _tiny(cards: Array) -> MHEventDeck:
	var d := MHEventDeck.new()
	assert_bool(d.load_from_dict({"schema": "mh.event_cards", "schema_version": 1, "cards": cards})).is_true()
	return d


func _card(id: String, weight: int, extra: Dictionary = {}) -> Dictionary:
	var c: Dictionary = {
		"id": id, "category": "member", "weight": weight, "min_day": 0, "cooldown_days": 0, "once": false,
		"title_key": "card." + id + ".title", "body_key": "card." + id + ".body",
		"choices": [
			{"id": "a", "label_key": "card.x.a", "outcome_key": "card.x.a_out", "effects": [{"op": "add_cash", "amount": -100}]},
			{"id": "b", "label_key": "card.x.b", "outcome_key": "card.x.b_out", "effects": []},
		],
	}
	for k in extra.keys():
		c[k] = extra[k]
	return c


# ---------------------------------------------------------------- shipped data

func test_shipped_deck_loads_with_at_least_sixty_cards() -> void:
	var d: MHEventDeck = _deck()
	assert_str(d.load_error).is_equal("")
	assert_int(d.card_count()).is_greater_equal(60)
	assert_int(d.card_count()).is_equal(65)


func test_every_card_is_well_formed() -> void:
	var d: MHEventDeck = _deck()
	var seen: Dictionary = {}
	for i in range(d.card_count()):
		var c: Dictionary = d.card_at(i)
		var id: String = String(c["id"])
		assert_bool(seen.has(id)).is_false()
		seen[id] = true
		assert_int(int(c["weight"])).is_between(1, 1000)
		var choices: Array = c["choices"]
		assert_int(choices.size()).is_between(2, 3)
		assert_bool(String(c["title_key"]).begins_with("card." + id + ".")).is_true()
		for ch in choices:
			var cd: Dictionary = ch
			assert_bool(["a", "b", "c"].has(String(cd["id"]))).is_true()
			var effects: Array = cd["effects"]
			assert_int(effects.size()).is_less_equal(4)
			for e in effects:
				var ed: Dictionary = e
				assert_bool(MHEventDeck.EFFECT_OPS.has(String(ed["op"]))).is_true()
				var amount: int = int(ed["amount"])
				assert_bool(amount >= -100000000 and amount <= 100000000).is_true()


func test_optional_spending_choices_are_gated_by_cash() -> void:
	var d: MHEventDeck = _deck()
	# storm_warning a costs 500; a broke club cannot pick it, a club with 500 can
	assert_bool(d.choice_available("storm_warning", "a", 499, 0)).is_false()
	assert_bool(d.choice_available("storm_warning", "a", 500, 0)).is_true()
	assert_bool(d.choice_available("storm_warning", "b", 0, 0)).is_true()
	assert_bool(d.choice_available("storm_warning", "z", 9999, 0)).is_false()
	assert_bool(d.choice_available("no_such_card", "a", 9999, 0)).is_false()


func test_game_copy_matches_docs_copy() -> void:
	var game_text: String = FileAccess.get_file_as_string(DATA_PATH)
	assert_bool(game_text.length() > 1000).is_true()
	var docs_path: String = ProjectSettings.globalize_path("res://").path_join(DOCS_COPY).simplify_path()
	if not FileAccess.file_exists(docs_path):
		# exported or packaged run without the docs folder: nothing to compare
		return
	assert_str(FileAccess.get_file_as_string(docs_path).sha256_text()).is_equal(game_text.sha256_text())


func test_strings_exist_for_every_key() -> void:
	var text: String = FileAccess.get_file_as_string("res://core/events/event_cards_strings_en.json")
	var parsed: Variant = JSON.parse_string(text)
	assert_bool(typeof(parsed) == TYPE_DICTIONARY).is_true()
	var strings: Dictionary = (parsed as Dictionary)["strings"]
	var d: MHEventDeck = _deck()
	for i in range(d.card_count()):
		var c: Dictionary = d.card_at(i)
		assert_bool(strings.has(String(c["title_key"]))).is_true()
		assert_bool(strings.has(String(c["body_key"]))).is_true()
		for ch in (c["choices"] as Array):
			assert_bool(strings.has(String((ch as Dictionary)["label_key"]))).is_true()
			assert_bool(strings.has(String((ch as Dictionary)["outcome_key"]))).is_true()


# ---------------------------------------------------------------- deterministic draws

func test_eligibility_count_for_a_fixed_context() -> void:
	var d: MHEventDeck = _deck()
	assert_int(d.eligible_indices(_ctx(40)).size()).is_equal(50)
	assert_int(d.eligible_indices(MHEventDeck.make_context(0, 0, "spring", 0, 0, [], [])).size()).is_equal(0)
	var day3: PackedInt32Array = d.eligible_indices(MHEventDeck.make_context(3, 0, "spring", 0, 0, [], []))
	var ids: Array = []
	for i in day3:
		ids.append(String(d.card_at(i)["id"]))
	assert_array(ids).contains_exactly(["cool_breeze", "member_birthday", "lost_ball_bin"])


func test_golden_draw_sequence() -> void:
	var d: MHEventDeck = _deck()
	var rng := MHRng.new(20260929, 7)
	var got: Array = []
	for k in range(10):
		var card: Dictionary = d.draw(rng, _ctx(40 + k))
		got.append(String(card["id"]))
	assert_array(got).contains_exactly([
		"heatwave", "tax_refund", "locker_room_upgrade", "hole_in_one", "charity_scramble",
		"mower_breakdown", "member_birthday", "staff_training_day", "photo_contest", "gopher_dance",
	])


func test_golden_daily_roll_sequence() -> void:
	var d: MHEventDeck = _deck()
	var rng := MHRng.new(555, 3)
	var got: Array = []
	for k in range(12):
		var card: Dictionary = d.roll_daily(rng, _ctx(40 + k * 3), 300)
		got.append("" if card.is_empty() else String(card["id"]))
	assert_array(got).contains_exactly([
		"", "", "staff_training_day", "lightning_scare", "", "", "", "pipe_burst", "", "", "", "kids_clinic",
	])


func test_same_seed_same_sequence_and_different_seed_differs() -> void:
	var a: MHEventDeck = _deck()
	var b: MHEventDeck = _deck()
	var ra := MHRng.new(42, 1)
	var rb := MHRng.new(42, 1)
	var rc := MHRng.new(43, 1)
	var c: MHEventDeck = _deck()
	var same: bool = true
	var differs: bool = false
	for k in range(15):
		var ca: String = String(a.draw(ra, _ctx(40 + k))["id"])
		var cb: String = String(b.draw(rb, _ctx(40 + k))["id"])
		var cc: String = String(c.draw(rc, _ctx(40 + k))["id"])
		if ca != cb:
			same = false
		if ca != cc:
			differs = true
	assert_bool(same).is_true()
	assert_bool(differs).is_true()


func test_draw_with_nothing_eligible_consumes_no_rng() -> void:
	var d: MHEventDeck = _deck()
	var rng := MHRng.new(9, 9)
	var probe := MHRng.new(9, 9)
	var ctx: Dictionary = MHEventDeck.make_context(0, 0, "spring", 0, 0, [], [])
	assert_bool(d.draw(rng, ctx).is_empty()).is_true()
	assert_int(rng.next_u32()).is_equal(probe.next_u32())


func test_weights_decide_the_pick() -> void:
	# weights 1, 1, 998: the third card is picked unless the first draw lands in the first two buckets
	var d: MHEventDeck = _tiny([_card("one", 1), _card("two", 1), _card("big", 998)])
	var rng := MHRng.new(1, 1)
	var counts: Dictionary = {"one": 0, "two": 0, "big": 0}
	for k in range(200):
		var c: Dictionary = d.draw(rng, MHEventDeck.make_context(k, 0, "spring", 0, 0, [], []))
		counts[String(c["id"])] = int(counts[String(c["id"])]) + 1
	assert_int(int(counts["big"])).is_greater(180)


func test_cooldown_blocks_repeats() -> void:
	var d: MHEventDeck = _tiny([_card("solo", 10, {"cooldown_days": 5})])
	var rng := MHRng.new(1, 1)
	assert_bool(d.draw(rng, MHEventDeck.make_context(10, 0, "spring", 0, 0, [], [])).is_empty()).is_false()
	for day in range(11, 15):
		assert_bool(d.draw(rng, MHEventDeck.make_context(day, 0, "spring", 0, 0, [], [])).is_empty()).is_true()
	assert_bool(d.draw(rng, MHEventDeck.make_context(15, 0, "spring", 0, 0, [], [])).is_empty()).is_false()
	assert_int(d.fired_count("solo")).is_equal(2)
	assert_int(d.last_fired_day("solo")).is_equal(15)


func test_once_cards_fire_once() -> void:
	var d: MHEventDeck = _tiny([_card("only", 10, {"once": true})])
	var rng := MHRng.new(1, 1)
	assert_bool(d.draw(rng, MHEventDeck.make_context(1, 0, "spring", 0, 0, [], [])).is_empty()).is_false()
	assert_bool(d.draw(rng, MHEventDeck.make_context(500, 0, "spring", 0, 0, [], [])).is_empty()).is_true()


func test_conditions() -> void:
	var cards: Array = [
		_card("late", 10, {"min_day": 20}),
		_card("score", 10, {"min_avg_hole_score": 50}),
		_card("members", 10, {"min_members": 25}),
		_card("tiered", 10, {"min_tier": 2, "max_tier": 3}),
		_card("summer_only", 10, {"seasons": ["summer"]}),
		_card("needs_tag", 10, {"requires_tags": ["has_restaurant"]}),
		_card("bans_tag", 10, {"forbids_tags": ["busy"]}),
		_card("needs_flag", 10, {"requires_flags": ["opened_pool"]}),
		_card("bans_flag", 10, {"forbids_flags": ["opened_pool"]}),
	]
	var d: MHEventDeck = _tiny(cards)
	var ctx: Dictionary = MHEventDeck.make_context(10, 0, "winter", 10, 20, [], [])
	assert_array(_ids(d, ctx)).contains_exactly(["bans_tag", "bans_flag"])
	ctx = MHEventDeck.make_context(25, 2, "summer", 30, 60, ["has_restaurant", "busy"], ["opened_pool"])
	assert_array(_ids(d, ctx)).contains_exactly(["late", "score", "members", "tiered", "summer_only", "needs_tag", "needs_flag"])
	ctx = MHEventDeck.make_context(25, 4, "summer", 30, 60, [], [])
	assert_bool(_ids(d, ctx).has("tiered")).is_false()


func _ids(d: MHEventDeck, ctx: Dictionary) -> Array:
	var out: Array = []
	for i in d.eligible_indices(ctx):
		out.append(String(d.card_at(i)["id"]))
	return out


func test_daily_roll_uses_permille_gate() -> void:
	var d: MHEventDeck = _tiny([_card("solo", 10)])
	var rng := MHRng.new(5, 5)
	var ctx: Dictionary = MHEventDeck.make_context(1, 0, "spring", 0, 0, [], [])
	# permille 0 never fires, 1000 always fires
	for k in range(20):
		assert_bool(d.roll_daily(rng, ctx, 0).is_empty()).is_true()
	var e: MHEventDeck = _tiny([_card("solo", 10)])
	assert_bool(e.roll_daily(rng, ctx, 1000).is_empty()).is_false()


# ---------------------------------------------------------------- effects as data

func test_resolve_choice_returns_effects_and_scales_cash() -> void:
	var d: MHEventDeck = _deck()
	var base: Array = d.resolve_choice("storm_warning", "a")
	assert_int(base.size()).is_equal(1)
	assert_str(String((base[0] as Dictionary)["op"])).is_equal("add_cash")
	assert_int(int((base[0] as Dictionary)["amount"])).is_equal(-500)
	var half: Array = d.resolve_choice("storm_warning", "a", 50)
	assert_int(int((half[0] as Dictionary)["amount"])).is_equal(-250)
	var odd: Array = d.resolve_choice("storm_warning", "a", 33)
	assert_int(int((odd[0] as Dictionary)["amount"])).is_equal(-165)
	# non-cash effects are never scaled
	var b: Array = d.resolve_choice("storm_warning", "b", 50)
	assert_int(int((b[0] as Dictionary)["amount"])).is_equal(-5)
	assert_int(d.resolve_choice("storm_warning", "q").size()).is_equal(0)
	assert_int(d.resolve_choice("nope", "a").size()).is_equal(0)


func test_resolving_does_not_modify_the_deck() -> void:
	var d: MHEventDeck = _deck()
	d.resolve_choice("storm_warning", "a", 10)
	var again: Array = d.resolve_choice("storm_warning", "a")
	assert_int(int((again[0] as Dictionary)["amount"])).is_equal(-500)


# ---------------------------------------------------------------- loading and saving

func test_load_rejects_bad_decks() -> void:
	var d := MHEventDeck.new()
	assert_bool(d.load_from_text("not json")).is_false()
	assert_bool(d.load_from_dict({"schema": "x", "schema_version": 1, "cards": []})).is_false()
	assert_bool(d.load_from_dict({"schema": "mh.event_cards", "schema_version": 2, "cards": [_card("a", 5)]})).is_false()
	assert_bool(d.load_from_dict({"schema": "mh.event_cards", "schema_version": 1, "cards": []})).is_false()
	assert_bool(d.load_from_dict({"schema": "mh.event_cards", "schema_version": 1, "cards": [_card("a", 0)]})).is_false()
	assert_bool(d.load_from_dict({"schema": "mh.event_cards", "schema_version": 1, "cards": [_card("a", 5), _card("a", 5)]})).is_false()
	var bad_op: Dictionary = _card("a", 5)
	((bad_op["choices"] as Array)[0] as Dictionary)["effects"] = [{"op": "give_gems", "amount": 5}]
	assert_bool(d.load_from_dict({"schema": "mh.event_cards", "schema_version": 1, "cards": [bad_op]})).is_false()
	assert_bool(d.load_error.begins_with("bad effect")).is_true()
	var no_flag: Dictionary = _card("b", 5)
	((no_flag["choices"] as Array)[0] as Dictionary)["effects"] = [{"op": "set_flag", "amount": 1}]
	assert_bool(d.load_from_dict({"schema": "mh.event_cards", "schema_version": 1, "cards": [no_flag]})).is_false()
	assert_bool(d.load_from_file("res://data/does_not_exist.json")).is_false()


func test_fired_state_round_trips_and_continues_identically() -> void:
	var a: MHEventDeck = _deck()
	var rng := MHRng.new(77, 2)
	for k in range(6):
		a.draw(rng, _ctx(40 + k))
	var saved: Variant = JSON.parse_string(JSON.stringify(a.to_dict()))
	var b: MHEventDeck = _deck()
	assert_bool(b.from_dict(saved as Dictionary)).is_true()
	assert_bool(b.to_dict() == a.to_dict()).is_true()
	# both decks continue with the same rng state and give the same cards
	# the restored deck must behave exactly like the original from here on (same fresh generator per deck)
	var ra := MHRng.new(5, 5)
	var rb := MHRng.new(5, 5)
	for k in range(8):
		var ca: Dictionary = a.draw(ra, _ctx(60 + k))
		var cb: Dictionary = b.draw(rb, _ctx(60 + k))
		assert_str(String(ca["id"])).is_equal(String(cb["id"]))


func test_card_history_matches_the_save_schema_shape() -> void:
	var a: MHEventDeck = _deck()
	var rng := MHRng.new(20260929, 7)
	for k in range(4):
		a.draw(rng, _ctx(40 + k))
	var history: Array = a.to_card_history()
	assert_int(history.size()).is_equal(4)
	for h in history:
		var hd: Dictionary = h
		assert_int(hd.size()).is_equal(2)
		assert_bool(hd.has("card_id") and hd.has("last_day")).is_true()
	# the shape passes the save validator
	var doc: Dictionary = preload("res://tests/save/save_fixture.gd").make_doc()
	((doc["progress"] as Dictionary))["card_history"] = history
	MHSaveGame.seal(doc)
	assert_int(MHSaveGame.validate(doc).size()).is_equal(0)
	var b: MHEventDeck = _deck()
	assert_bool(b.from_card_history(history)).is_true()
	assert_bool(b.to_card_history() == history).is_true()
	assert_bool(b.from_card_history([5])).is_false()

extends GdUnitTestSuite
## Builds every screen and modal headless on sample data and refreshes it. Catches runtime errors in the
## code-built UI (null refs, bad keys) without a window. NOT YET RUN.


func _ctx() -> MHUIContext:
	var c: MHUIContext = MHUIContext.new()
	c.recompute(Vector2(2400, 1080), Vector2(1280, 720), 420.0, Rect2(0, 0, 2400, 1080))
	return c


func test_ids_are_unique_and_creatable() -> void:
	var seen: Dictionary = {}
	for id: Variant in MHScreenIds.ALL:
		var sid: String = str(id)
		assert_bool(seen.has(sid)).is_false()
		seen[sid] = true
		assert_bool(MHScreenIds.is_known(sid)).is_true()
		var node: MHScreen = MHScreenFactory.create(sid)
		assert_bool(node != null).override_failure_message("no screen for " + sid).is_true()
		node.free()
	assert_bool(MHScreenFactory.create("nope") == null).is_true()
	assert_bool(MHScreenIds.is_modal(MHScreenIds.BANKRUPTCY)).is_true()
	assert_bool(MHScreenIds.is_modal(MHScreenIds.HUD)).is_false()


func test_every_screen_builds_and_refreshes() -> void:
	var view: MHFakeGameStateView = MHFakeGameStateView.new()
	view.sample_set_recovery(true)
	var ctx: MHUIContext = _ctx()
	for id: Variant in MHScreenIds.ALL:
		var node: MHScreen = MHScreenFactory.create(str(id))
		auto_free(node)
		node.setup(view, ctx, {})
		assert_bool(node.get_child_count() > 0).override_failure_message("empty screen " + str(id)).is_true()
		node.refresh()
		assert_str(node.screen_id()).is_equal(str(id))


func test_editor_pause_routes_to_live_clock_and_can_resume() -> void:
	var session: MHGameSession = MHGameSession.create()
	var view: MHLiveGameStateView = MHLiveGameStateView.new(session)
	var editor: MHEditorScreen = MHEditorScreen.new()
	auto_free(editor)
	editor.setup(view, _ctx(), {})
	editor.intent.connect(func(id: StringName, args: Dictionary) -> void: session.handle_intent(id, args))
	var pause: MHTapButton = editor.region_buttons()[&"editor_pause"] as MHTapButton
	pause.pressed.emit()
	assert_bool(session.clock.is_paused()).is_true()
	editor.refresh()
	assert_str(pause.text).is_equal(MHStrings.t("hud.resume"))
	pause.pressed.emit()
	assert_bool(session.clock.is_paused()).is_false()


func test_screens_survive_empty_game_state() -> void:
	var view: MHGameStateView = MHGameStateView.new()
	var ctx: MHUIContext = _ctx()
	for id: Variant in MHScreenIds.ALL:
		var node: MHScreen = MHScreenFactory.create(str(id))
		auto_free(node)
		node.setup(view, ctx, {})
		node.refresh()


func test_screens_build_in_portrait_left_handed_and_large_text() -> void:
	var view: MHFakeGameStateView = MHFakeGameStateView.new()
	var ctx: MHUIContext = MHUIContext.new()
	ctx.recompute(Vector2(1080, 2400), Vector2(720, 1280), 420.0, Rect2(0, 0, 1080, 2400))
	ctx.settings.set_left_handed(true)
	ctx.settings.set_text_scale(160)
	assert_bool(ctx.is_portrait()).is_true()
	for id: Variant in MHScreenIds.ALL:
		var node: MHScreen = MHScreenFactory.create(str(id))
		auto_free(node)
		node.setup(view, ctx, {})


func test_overlay_flags_and_regions() -> void:
	var view: MHFakeGameStateView = MHFakeGameStateView.new()
	var ctx: MHUIContext = _ctx()
	var hud: MHScreen = MHScreenFactory.create(MHScreenIds.HUD)
	auto_free(hud)
	hud.setup(view, ctx, {})
	assert_bool(hud.is_overlay).is_true()
	assert_bool(hud.region_buttons().size() >= 9).is_true()
	assert_int(hud.button_rect_getters().size()).is_equal(hud.region_buttons().size())
	var ed: MHEditorScreen = MHEditorScreen.new()
	auto_free(ed)
	ed.setup(view, ctx, {})
	var sel: Dictionary = ed.current_selection()
	assert_int(int(sel["brush_mode"])).is_equal(MHBrush.Mode.RAISE)
	assert_int(int(sel["surface_layer"])).is_equal(1)
	var build: MHScreen = MHScreenFactory.create(MHScreenIds.BUILD)
	auto_free(build)
	build.setup(view, ctx, {})
	assert_bool(build.is_overlay).is_false()


func test_consent_default_off_and_one_tap() -> void:
	var view: MHFakeGameStateView = MHFakeGameStateView.new()
	var ctx: MHUIContext = _ctx()
	var consent: MHConsentScreen = MHConsentScreen.new()
	auto_free(consent)
	consent.setup(view, ctx, {})
	assert_bool(ctx.settings.analytics_opt_in).is_false()
	var got: Array = []
	consent.intent.connect(func(id: StringName, a: Dictionary) -> void: got.append([id, a]))
	consent._on_continue()
	assert_int(got.size()).is_equal(1)
	assert_str(str((got[0] as Array)[0])).is_equal("consent_done")
	assert_bool(bool(((got[0] as Array)[1] as Dictionary)["opt_in"])).is_false()
	assert_bool(ctx.settings.consent_shown).is_true()


func test_token_store_has_no_purchase_path() -> void:
	var view: MHFakeGameStateView = MHFakeGameStateView.new()
	var ctx: MHUIContext = _ctx()
	var store: MHTokenStoreScreen = MHTokenStoreScreen.new()
	auto_free(store)
	var got: Array = []
	store.intent.connect(func(id: StringName, _a: Dictionary) -> void: got.append(id))
	store.setup(view, ctx, {})
	var buttons: Array = store.find_children("*", "Button", true, false)
	assert_bool(buttons.size() > 0).is_true()
	for b: Variant in buttons:
		var btn: Button = b
		if btn.get_parent() != null and btn.text == MHStrings.t("tokens.unavailable"):
			assert_bool(btn.disabled).is_true()
	assert_int(got.size()).is_equal(0)


func test_gallery_is_in_the_launcher() -> void:
	var found: bool = false
	for e: Variant in MHLauncher.SCENES:
		var entry: Array = e
		if str(entry[1]) == "res://ui/mh_ui_gallery.tscn":
			found = true
	assert_bool(found).is_true()
	assert_bool(ResourceLoader.exists("res://ui/mh_ui_gallery.tscn")).is_true()


func test_achievement_filter() -> void:
	# Test filtering independently of the full catalogue's changing category counts.
	var rows: Array = [
		{"id": "daily_locked", "category": "daily", "earned": false},
		{"id": "design_earned", "category": "design", "earned": true},
		{"id": "daily_earned", "category": "daily", "earned": true},
	]
	var all: Array = MHAchievementsScreen.filtered(rows, "all")
	assert_int(all.size()).is_equal(3)
	var daily: Array = MHAchievementsScreen.filtered(rows, "daily")
	assert_int(daily.size()).is_equal(2)
	assert_str(str((daily[0] as Dictionary)["id"])).is_equal("daily_earned")
	assert_str(str((daily[1] as Dictionary)["id"])).is_equal("daily_locked")
	assert_int(MHAchievementsScreen.filtered(rows, "nothing").size()).is_equal(0)


func test_management_screen_emits_difficulty_intent() -> void:
	var session: MHGameSession = MHGameSession.create()
	var view: MHLiveGameStateView = MHLiveGameStateView.new(session)
	var screen: MHManagementScreen = MHManagementScreen.new()
	auto_free(screen)
	screen.setup(view, _ctx(), {})
	var hits: Array = []
	screen.intent.connect(func(id: StringName, args: Dictionary) -> void:
		hits.append([id, args])
		session.handle_intent(id, args))
	var buttons: Array = screen.find_children("*", "Button", true, false)
	var relaxed: Button = null
	for value: Variant in buttons:
		var b: Button = value
		if b.text == "Relaxed":
			relaxed = b
			break
	assert_bool(relaxed != null).is_true()
	relaxed.pressed.emit()
	assert_int(hits.size()).is_equal(1)
	assert_str(str((hits[0] as Array)[0])).is_equal("set_management_difficulty")
	assert_str(session.management_difficulty).is_equal("relaxed")

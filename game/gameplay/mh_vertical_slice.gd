class_name MHVerticalSlice
extends Node3D
## First playable vertical-slice loop (res://gameplay/mh_vertical_slice.tscn).
##
## What it shows: a flat 128 m course on the 4x4 parcel grid with an in-memory MHGameSession. Bought buildings
## appear as procedural meshes on their parcels at the right tier, nature is scattered by seed around the
## course, visual golfer groups tee off on the built holes and walk them, and a HUD shows cash, clock, rating
## and income per hour with a buy/upgrade menu, a build-hole button and a buy-land button.
##
## Rules kept: the sim stays integer and deterministic. Rendering code (this file's _sync_* and
## MHSliceGolfers) only READS the session. The session changes only through its public player paths
## (handle_intent, submit_course), triggered by buttons. Nothing is saved: the session lives in memory and
## nothing is written to user://, so ordinary saves and the live construction slot are untouched.
## No terrain editing here. NOT YET RUN in Godot (see docs/phase1/vertical_slice.md).
@warning_ignore_start("integer_division")

const SCENE_PATH: String = "res://gameplay/mh_vertical_slice.tscn"
const NATURE_SEED: int = 20261005
const NATURE_COUNT: int = 90
const HUD_REFRESH_S: float = 0.2
## Holes built on entry, so the first minutes are not an empty course (each is paid for through submit_course).
## The starter club (holes, tier 1 buildings, fee) is MHSliceStarter; see docs/phase1/vertical_slice.md for why.
const STARTER_HOLES: int = MHSliceStarter.STARTER_HOLES
## Golfers waiting on the first tee at 7:00 (picture only, never booked): the economy books its first golfers when
## the first game hour ends, about 2.3 real minutes at 1x.
const OPENING_GOLFERS: int = 3
## Development only: turns the in-memory session's demo flag off so all ten buildings can be bought and shown
## (the demo caps six of them at tier 0). Never persisted. Set false to test the demo limits.
const UNLOCK_FULL_GAME: bool = true
const TIERS_ORDER: Array = ["low", "medium", "high"]

var session: MHGameSession
var view: MHLiveGameStateView
var controller: MHIsoCameraController
var golfers: MHSliceGolfers
var schedule: MHSliceSchedule
var tier_name: String = "low"
var nature_seed: int = NATURE_SEED
## building id -> MeshInstance3D / tier currently drawn / slot (see MHSliceLayout).
var building_nodes: Dictionary = {}
var building_tiers: Dictionary = {}
var slots: Dictionary = {}
## Hole slots built so far and their world points, refreshed when the course changes.
var built_slots: Array = []
var hole_points: Array = []
var nature_group_count: int = 0
var starter_hole_error: String = ""

var _mat: StandardMaterial3D
var _ready_ok: bool = false
var _last_usec: int = 0
var _last_hour: int = 0
var _sig: int = -1
var _course_sig: String = ""
var _hud_timer: float = 0.0
var _mesh_cache: Dictionary = {}
var _bounds_cache: Dictionary = {}
var _buildings_root: Node3D
var _course_root: Node3D
var _ground: MeshInstance3D
var _hud_line: Label
var _detail_line: Label
var _status: Label
var _menu_panel: PanelContainer
var _menu_rows: Dictionary = {}
var _pause_button: MHTapButton
var _speed_button: MHTapButton
var _hole_button: MHTapButton
var _land_button: MHTapButton
var _quality_button: MHTapButton
var _touches: Dictionary = {}
var _pinch_ref: float = 0.0
var _menu_dirty: bool = true
var _tab_rows: Dictionary = {}
var _active_tab: String = "course"
var _readout: Label
var _readout_hole: int = 0


func _ready() -> void:
	session = MHGameSession.create()
	if session == null:
		_fail("Game data could not load.")
		return
	session.demo = not UNLOCK_FULL_GAME
	view = MHLiveGameStateView.new(session)
	_mat = MHArtMaterials.vertex_color()
	MHSkySetup.apply(self, false)
	_build_camera()
	_build_nature()
	_ground = MeshInstance3D.new()
	add_child(_ground)
	_course_root = Node3D.new()
	add_child(_course_root)
	_buildings_root = Node3D.new()
	add_child(_buildings_root)
	golfers = MHSliceGolfers.new()
	add_child(golfers)
	golfers.setup(_mat)
	_apply_quality()
	_build_hud()
	# Starter club, through the same player paths a button uses: holes, tier 1 buildings, the economy's own fee.
	starter_hole_error = MHSliceStarter.setup(session, view)
	schedule = MHSliceSchedule.from_economy(session.economy)
	# Opening golfers are presentation-only ambience; all subsequent traffic comes from booked economy arrivals.
	schedule.prime(0, OPENING_GOLFERS)
	_last_hour = _absolute_hour()
	session.golfers_booked.connect(_on_golfers_booked)
	session.changed.connect(_on_session_changed)
	_sync_world(true)
	_refresh_hud()
	_ready_ok = true
	_last_usec = Time.get_ticks_usec()


func _process(delta: float) -> void:
	if not _ready_ok:
		return
	var now: int = Time.get_ticks_usec()
	var elapsed: int = maxi(0, now - _last_usec)
	_last_usec = now
	tick(elapsed, int(Time.get_unix_time_from_system()), delta)


## One frame of the slice. Public so tests can drive it without engine frames.
## elapsed_us / wall_unix go to the session exactly as the live construction scene does; delta is the frame
## time in seconds and only drives the cosmetic golfer animation.
func tick(elapsed_us: int, wall_unix: int, delta: float) -> void:
	session.advance(elapsed_us, wall_unix)
	_poll_arrivals()
	var visual_dt: float = 0.0
	if not session.clock.is_paused():
		visual_dt = delta * float(mini(session.clock.speed(), 2))
	golfers.advance(visual_dt, _camera_position())
	for completed: Variant in golfers.drain_completed_groups():
		_on_visual_round_complete(completed as Dictionary)
	_sync_world(false)
	_hud_timer += delta
	if _hud_timer >= HUD_REFRESH_S:
		_hud_timer = 0.0
		_refresh_hud()


# ---------------------------------------------------------------- player actions (the only session writers)

## Builds the next free hole slot through MHGameSession.submit_course (cost, caps and rating are the session's).
## Returns "" on success or a reason in plain words.
func build_next_hole() -> String:
	return MHSliceStarter.build_next_hole(session)


func buy_next_tier(building_id: String) -> String:
	return MHSliceStarter.buy_next_tier(session, view, building_id)


## What the Buy land button would do right now: {"parcel": int (-1 when none), "price": dollars the session charges,
## "affordable": bool, "reason": plain words, empty when the purchase can go ahead}.
func land_offer() -> Dictionary:
	var land: MHLandModel = session.land
	var buyable: PackedInt32Array = land.buyable_parcels()
	var parcel: int = MHSliceLayout.next_land_parcel(buyable)
	var price: int = land.next_price()
	var out: Dictionary = {"parcel": parcel, "price": price, "affordable": false, "reason": ""}
	if parcel < 0:
		if land.owned_count() >= land.parcel_count():
			out["reason"] = "you already own all %d parcels" % land.parcel_count()
		else:
			out["reason"] = "no unowned parcel touches your land"
		return out
	if session.economy.is_bankrupt():
		out["reason"] = "the club is bankrupt"
	elif not session.economy.can_afford(price * 100):
		out["reason"] = "parcel %d costs %s and you have %s" % [parcel, MHFormat.money(price), MHFormat.money(session.economy.cash / 100)]
	else:
		out["affordable"] = true
	return out


## Buys the parcel land_offer() names. Returns "" on success or the reason in plain words.
func buy_next_parcel() -> String:
	var offer: Dictionary = land_offer()
	if not bool(offer["affordable"]):
		return str(offer["reason"])
	var result: Dictionary = session.handle_intent(&"buy_parcel", {"parcel": int(offer["parcel"])})
	if bool(result.get("ok", false)):
		return ""
	return MHSliceText.intent_words(str(result.get("reason", "")))


func _real_cost_dollars(building_id: String, tier: int) -> int:
	var index: int = session.economy.params.building_index(building_id)
	return session.economy.price_cents(index, tier) / 100


# ---------------------------------------------------------------- arrivals (read only)

func _absolute_hour() -> int:
	return session.economy.day * MHEconomy.HOURS_PER_DAY + session.economy.hour


func _poll_arrivals() -> void:
	# MHGameSession publishes the authoritative booked count during advance().
	# This method only releases already-booked groups into visual tee slots.
	for g: Variant in schedule.release(session.clock.total_minutes()):
		_spawn_group(g as Dictionary)


func _on_golfers_booked(count: int) -> void:
	schedule.add_booked_golfers(count)

func _spawn_group(g: Dictionary) -> void:
	if hole_points.is_empty():
		return
	var serial: int = int(g["serial"])
	var route: Array = []
	for pts_value: Variant in hole_points:
		var pts: Dictionary = pts_value as Dictionary
		route.append({"tee": pts["tee"], "green": pts["green"]})
	golfers.spawn_course_group(serial, int(g["size"]), route)
	_readout_hole = 0

func _on_visual_round_complete(row: Dictionary) -> void:
	# Rendering reports a completed visit; MHGameSession alone owns customer progression and economy.
	var size: int = int(row.get("size", 0))
	var holes_played: int = int(row.get("holes", 0))
	if size <= 0 or holes_played <= 0:
		return
	var serial: int = int(row.get("serial", 0))
	var new_regulars: int = 0
	var member_candidates: int = 0
	var experience: Dictionary = {}
	for member: int in range(size):
		var customer_id: int = MHSliceSchedule.look_index(serial, member, MHGolferCustomers.COUNT)
		var visit: Dictionary = session.record_customer_visit(customer_id, holes_played,
			schedule.waiting_golfers() * schedule.interval_min)
		if visit.is_empty():
			continue
		experience = visit["experience"] as Dictionary
		var before: Dictionary = visit["before"] as Dictionary
		var after: Dictionary = visit["after"] as Dictionary
		if not bool(before["regular"]) and bool(after["regular"]):
			new_regulars += 1
		if not bool(before["member_eligible"]) and bool(after["member_eligible"]):
			member_candidates += 1
	if experience.is_empty():
		return
	var tail: String = ""
	if new_regulars > 0:
		tail += " %d became regular%s." % [new_regulars, "" if new_regulars == 1 else "s"]
	if member_candidates > 0:
		tail += " %d can apply for membership." % member_candidates
	_set_status("Group %d: %d/100 satisfaction. %s%s" % [
		serial + 1, int(experience["score"]), str(experience["reaction"]), tail])

func _camera_position() -> Vector3:
	if controller == null:
		return Vector3(64.0, 80.0, 160.0)
	return controller.rig.lod_eye()


func _on_session_changed() -> void:
	_menu_dirty = true


# ---------------------------------------------------------------- world (read only)

## Cheap integer fingerprint of what the world draws: holes, owned parcel count (land is never sold, so the count
## identifies the set), and the ten tiers (each below 8).
func _world_signature() -> int:
	var h: int = session.economy.holes
	h = h * 32 + session.land.owned_count()
	for t: int in session.economy.tiers:
		h = h * 8 + t
	return h


func _sync_world(force: bool) -> void:
	var sig: int = _world_signature()
	if sig == _sig and not force:
		return
	_sig = sig
	var owned: PackedInt32Array = session.land.owned_ids()
	var course_sig: String = "%s|%d" % [str(owned), session.economy.holes]
	if course_sig != _course_sig or force:
		_course_sig = course_sig
		_rebuild_course(owned)
	var tiers: Dictionary = session.tiers()
	slots = MHSliceLayout.assign_slots(tiers, owned, slots)
	for id: Variant in MHSliceLayout.ORDER:
		_sync_building(str(id), int(tiers.get(str(id), 0)))
	_menu_dirty = true


func _sync_building(id: String, tier: int) -> void:
	if tier <= 0 or not slots.has(id):
		if building_nodes.has(id):
			(building_nodes[id] as Node3D).queue_free()
			building_nodes.erase(id)
			building_tiers.erase(id)
		return
	var node: MeshInstance3D
	if building_nodes.has(id):
		node = building_nodes[id] as MeshInstance3D
	else:
		node = MHArtMaterials.make_instance(null, _mat, false)
		_buildings_root.add_child(node)
		building_nodes[id] = node
		building_tiers[id] = 0
	if int(building_tiers[id]) != tier or node.mesh == null:
		var key: String = "%s:%d" % [id, tier]
		if not _mesh_cache.has(key):
			_mesh_cache[key] = MHBuildingMeshes.build(id, tier, "a")
		node.mesh = _mesh_cache[key] as Mesh
		building_tiers[id] = tier
	var bkey: String = "%s:%d" % [id, tier]
	if not _bounds_cache.has(bkey):
		_bounds_cache[bkey] = MHBuildingMeshes.bounds(id, tier, "a")
	# Scaled so tier 1 fills about half a cell and tier 5 the whole cell (MHSliceLayout.TIER_FOOTPRINT_SHARE).
	node.transform = MHSliceLayout.building_transform_tier(int(slots[id]), _bounds_cache[bkey] as AABB, tier)


func _rebuild_course(owned: PackedInt32Array) -> void:
	for child: Node in _course_root.get_children():
		_course_root.remove_child(child)
		child.queue_free()
	var b: MHMeshBuilder = MHMeshBuilder.new()
	MHBuildingParts.flat(b, Vector3(MHSliceLayout.MAP_M * 0.5, -0.1, MHSliceLayout.MAP_M * 0.5 + 20.0),
		MHSliceLayout.MAP_M + 240.0, MHSliceLayout.MAP_M + 280.0, MHPalette.shade(MHPalette.ROUGH, 0.85))
	for parcel: int in range(MHSliceLayout.PARCEL_COUNT):
		var o: Vector2 = MHSliceLayout.parcel_origin_m(parcel)
		var col: Color = MHPalette.GRASS if owned.has(parcel) else MHPalette.shade(MHPalette.ROUGH, 0.7)
		if (parcel % MHSliceLayout.COLS + parcel / MHSliceLayout.COLS) % 2 == 1:
			col = MHPalette.shade(col, 0.95)
		MHBuildingParts.flat(b, Vector3(o.x + MHSliceLayout.PARCEL_M * 0.5, 0.0, o.y + MHSliceLayout.PARCEL_M * 0.5),
			MHSliceLayout.PARCEL_M, MHSliceLayout.PARCEL_M, col)
	built_slots = []
	hole_points = []
	var flag_xf: Array = []
	var tree_xf: Array = []
	for d: Variant in session.hole_definitions():
		var def: Dictionary = d
		var slot: int = int(def["slot_id"])
		built_slots.append(slot)
		hole_points.append(MHSliceLayout.hole_points_m(def))
		_add_hole_geometry(b, slot, def, flag_xf, tree_xf)
	_ground.mesh = b.to_mesh()
	_ground.material_override = _mat
	_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not flag_xf.is_empty():
		_course_root.add_child(MHArtMaterials.make_multimesh(MHPropMeshes.build(MHPropMeshes.KIND_FLAG, 0, 0), _mat, flag_xf))
	if not tree_xf.is_empty():
		_course_root.add_child(MHArtMaterials.make_multimesh(MHNatureMeshes.build("pine", 0, 0), _mat, tree_xf))


func _add_hole_geometry(b: MHMeshBuilder, slot: int, def: Dictionary, flag_xf: Array, tree_xf: Array) -> void:
	var pts: Dictionary = MHSliceLayout.hole_points_m(def)
	var tee: Vector2 = pts["tee"] as Vector2
	var green: Vector2 = pts["green"] as Vector2
	for f: Variant in def["features"]:
		var feat: Dictionary = f
		var kind: String = str(feat["t"])
		if kind == "fairway":
			_flat_rect(b, MHSliceLayout.feature_rect_m(slot, feat["rect"] as Array), 0.08, MHPalette.GRASS_LIGHT)
		elif kind == "bunker":
			_flat_rect(b, MHSliceLayout.feature_rect_m(slot, feat["rect"] as Array), 0.16, MHPalette.SAND)
		elif kind == "water":
			_flat_rect(b, MHSliceLayout.feature_rect_m(slot, feat["rect"] as Array), 0.16, MHPalette.WATER)
		elif kind == "tree":
			for t: Variant in feat["at"]:
				var p: Vector2 = MHSliceLayout.hole_point_m(slot, int((t as Array)[0]), int((t as Array)[1]))
				tree_xf.append(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.0)), Vector3(p.x, 0.0, p.y)))
	b.disc(Vector3(green.x, 0.24, green.y), float(pts["green_radius_m"]), 14, MHPalette.GRASS_DARK)
	_flat_rect(b, Rect2(tee.x - 1.5, tee.y - 1.0, 3.0, 2.0), 0.16, MHPalette.PATH_STONE)
	flag_xf.append(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.0)), Vector3(green.x, 0.24, green.y)))
	# SimGolf pattern: a thin white line from the tee to the green and a floating hole label over the tee.
	_flat_rect(b, Rect2(minf(tee.x, green.x) - 0.12, minf(tee.y, green.y), absf(green.x - tee.x) + 0.24, absf(green.y - tee.y)),
		0.26, Color(1.0, 1.0, 1.0))
	var tag: Label3D = Label3D.new()
	tag.text = MHSliceBar.hole_label(slot, MHSliceLayout.hole_length_yd(slot))
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.03
	tag.font_size = 36
	tag.outline_size = 10
	tag.modulate = Color(1.0, 1.0, 1.0)
	tag.outline_modulate = Color(0.1, 0.12, 0.1)
	tag.position = Vector3(tee.x, 3.2, tee.y)
	_course_root.add_child(tag)


func _flat_rect(b: MHMeshBuilder, r: Rect2, y: float, col: Color) -> void:
	MHBuildingParts.flat(b, Vector3(r.position.x + r.size.x * 0.5, y, r.position.y + r.size.y * 0.5), r.size.x, r.size.y, col)


func _build_nature() -> void:
	var root: Node3D = Node3D.new()
	root.name = "Nature"
	add_child(root)
	var groups: Dictionary = MHSliceNature.group(MHSliceNature.scatter(nature_seed, NATURE_COUNT))
	nature_group_count = groups.size()
	for key: Variant in groups.keys():
		var parts: PackedStringArray = str(key).split("|")
		var items: Array = groups[key] as Array
		var xf: Array = []
		for it: Variant in items:
			var d: Dictionary = it
			var s: float = float(d["scale"])
			var basis: Basis = Basis(Vector3.UP, float(d["yaw"])) * Basis.from_scale(Vector3(s, s, s))
			xf.append(Transform3D(basis, Vector3(float(d["x"]), 0.0, float(d["z"]))))
		var mm: MultiMeshInstance3D = MHArtMaterials.make_multimesh(
			MHNatureMeshes.build(parts[0], int(parts[1]), int(parts[2])), _mat, xf)
		mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mm)


func _build_camera() -> void:
	controller = MHIsoCameraController.new()
	controller.rig.bounds = Rect2(0.0, 0.0, MHSliceLayout.MAP_M, MHSliceLayout.MAP_M + 24.0)
	add_child(controller)
	controller.rig.target = Vector3(64.0, 0.0, 64.0)
	controller.apply_now()


func _apply_quality() -> void:
	var caps: Dictionary = MHSliceVisibility.caps_for_tier(tier_name)
	golfers.set_caps(int(caps["near"]), int(caps["total"]))


# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = MHTheme.build(100)
	layer.add_child(root)
	add_child(MHTouchBridge.new()) # Raw touches to MHTapButton and MHScrollBox (emulate_mouse_from_touch is off).
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	root.add_child(margin)
	var page: VBoxContainer = MHUIKit.vbox(8)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(page)
	var top: HBoxContainer = MHUIKit.hbox(12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(top)

	var chip: PanelContainer = MHUIKit.panel(&"HudChip")
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var lines: VBoxContainer = MHUIKit.vbox(2)
	chip.add_child(lines)
	_hud_line = MHUIKit.label("", &"HudLabel", false)
	_detail_line = MHUIKit.label("", &"SmallLabel", false)
	_status = MHUIKit.label("Slice: in-memory club, nothing is saved.", &"SmallLabel", false)
	lines.add_child(_hud_line)
	lines.add_child(_detail_line)
	lines.add_child(_status)
	top.add_child(chip)
	var gap: Control = MHUIKit.spacer()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(gap)

	_menu_panel = MHUIKit.panel(&"CardPanel")
	_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_panel.custom_minimum_size = Vector2(540.0, 0.0)
	_menu_panel.visible = false
	var menu_box: VBoxContainer = MHUIKit.vbox(6)
	_menu_panel.add_child(menu_box)
	menu_box.add_child(MHUIKit.label("Buildings (buy or upgrade)", &"H2Label", false))
	var scroll: MHScrollBox = MHScrollBox.new()
	scroll.custom_minimum_size = Vector2(0.0, 360.0)
	menu_box.add_child(scroll)
	var list: VBoxContainer = MHUIKit.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for id: Variant in MHSliceLayout.ORDER:
		var bid: String = str(id)
		var row: HBoxContainer = MHUIKit.hbox(8)
		list.add_child(row)
		var label: Label = MHUIKit.label("", &"SmallLabel", true)
		label.custom_minimum_size = Vector2(300.0, 0.0)
		row.add_child(label)
		var button: MHTapButton = MHTapButton.make("-", &"GreenButton", 150.0, 56.0)
		button.pressed.connect(_on_buy.bind(bid))
		row.add_child(button)
		_menu_rows[bid] = {"label": label, "button": button}
	top.add_child(_menu_panel)

	var world_gap: Control = MHUIKit.spacer()
	world_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	world_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(world_gap)
	page.add_child(_build_bar())


## The bottom mode bar: tab buttons on the left, the active tab's buttons in the middle, the hole readout on the right.
func _build_bar() -> PanelContainer:
	var bar: PanelContainer = MHUIKit.panel(&"CardPanel")
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var row: HBoxContainer = MHUIKit.hbox(12)
	bar.add_child(row)
	var tabs: VBoxContainer = MHUIKit.vbox(6)
	row.add_child(tabs)
	var content: VBoxContainer = MHUIKit.vbox(6)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(content)
	for t: Variant in MHSliceBar.TABS:
		var tab_id: String = str((t as Array)[0])
		var tab_button: MHTapButton = MHTapButton.make(str((t as Array)[1]), &"ChipButton", 110.0, 48.0)
		tab_button.pressed.connect(_on_tab.bind(tab_id))
		tabs.add_child(tab_button)
		var flow: HFlowContainer = MHUIKit.flow(6)
		flow.visible = tab_id == _active_tab
		content.add_child(flow)
		_tab_rows[tab_id] = flow
		for bid: Variant in (t as Array)[2]:
			_make_bar_button(flow, str(bid))
	_readout = MHUIKit.label("", &"SmallLabel", true)
	_readout.custom_minimum_size = Vector2(300.0, 0.0)
	row.add_child(_readout)
	return bar


func _make_bar_button(parent: Control, bid: String) -> void:
	match bid:
		"build_hole":
			_hole_button = _chip_button(parent, "Build hole", _on_build_hole)
		"buy_land":
			_land_button = _chip_button(parent, "Buy land", _on_buy_land)
		"buildings":
			_chip_button(parent, "Buildings", _on_toggle_menu)
		"pause":
			_pause_button = _chip_button(parent, "Pause", _on_pause)
		"speed":
			_speed_button = _chip_button(parent, "Speed x1", _on_speed)
		"fee_down":
			_chip_button(parent, "Fee -$1", _on_fee.bind(-100))
		"fee_up":
			_chip_button(parent, "Fee +$1", _on_fee.bind(100))
		"zoom_in":
			_chip_button(parent, "Zoom +", func() -> void: controller.desktop_zoom(1))
		"zoom_out":
			_chip_button(parent, "Zoom -", func() -> void: controller.desktop_zoom(-1))
		"turn_left":
			_chip_button(parent, "Turn <", func() -> void: controller.rotate_step(-1))
		"turn_right":
			_chip_button(parent, "Turn >", func() -> void: controller.rotate_step(1))
		"quality":
			_quality_button = _chip_button(parent, "Quality: " + tier_name, _on_quality)
		"back":
			_chip_button(parent, "Back", _on_back)


func _on_tab(tab_id: String) -> void:
	_active_tab = tab_id
	for k: Variant in _tab_rows.keys():
		(_tab_rows[k] as Control).visible = str(k) == tab_id


func _update_readout() -> void:
	if _readout == null or built_slots.is_empty():
		return
	var slot: int = int(built_slots[_readout_hole % built_slots.size()])
	var d: Dictionary = MHSliceLayout.HOLE_DESIGNS[clampi(slot, 0, MHSliceLayout.HOLE_DESIGNS.size() - 1)] as Dictionary
	_readout.text = MHSliceBar.readout(slot, MHSliceLayout.hole_length_yd(slot), not (d["water"] as Array).is_empty(),
		not (d["trees"] as Array).is_empty())


func _chip_button(parent: Control, text_value: String, action: Callable) -> MHTapButton:
	var b: MHTapButton = MHTapButton.make(text_value, &"ChipButton", 110.0, 52.0)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _set_status(text_value: String) -> void:
	if _status != null:
		_status.text = text_value


func _on_pause() -> void:
	session.handle_intent(&"toggle_pause", {})
	_refresh_hud()


func _on_speed() -> void:
	var next: int = 1
	match session.clock.speed():
		1:
			next = 2
		2:
			next = 8
		_:
			next = 1
	var result: Dictionary = session.handle_intent(&"set_speed", {"speed": next})
	if not bool(result.get("ok", false)):
		_set_status("Speed x%d needs tokens; staying at x%d." % [next, session.clock.speed()])
	_refresh_hud()


func _on_fee(delta_cents: int) -> void:
	session.handle_intent(&"set_green_fee", {"cents": session.economy.fee + delta_cents})
	_refresh_hud()


func _on_build_hole() -> void:
	var err: String = build_next_hole()
	_set_status("Hole built." if err == "" else "Cannot build hole: " + err + ".")
	_sync_world(false)
	_refresh_hud()


func _on_buy_land() -> void:
	var offer: Dictionary = land_offer()
	var err: String = buy_next_parcel()
	if err == "":
		var next_offer: Dictionary = land_offer()
		var tail: String = "" if int(next_offer["parcel"]) < 0 else " The next parcel costs %s." % MHFormat.money(int(next_offer["price"]))
		_set_status("Bought parcel %d for %s.%s" % [int(offer["parcel"]), MHFormat.money(int(offer["price"])), tail])
	else:
		_set_status("Cannot buy land: " + err + ".")
	_sync_world(false)
	_refresh_hud()


func _on_toggle_menu() -> void:
	_menu_panel.visible = not _menu_panel.visible
	_menu_dirty = true
	_refresh_hud()


func _on_buy(id: String) -> void:
	var err: String = buy_next_tier(id)
	_set_status("Bought %s." % MHSliceText.building_title(id) if err == "" else "Cannot buy %s: %s." % [MHSliceText.building_title(id), err])
	_sync_world(false)
	_refresh_hud()


func _on_quality() -> void:
	var i: int = TIERS_ORDER.find(tier_name)
	tier_name = str(TIERS_ORDER[(i + 1) % TIERS_ORDER.size()])
	_apply_quality()
	_quality_button.text = "Quality: " + tier_name


func _on_back() -> void:
	get_tree().change_scene_to_file(MHLauncher.LAUNCHER_PATH)


func _refresh_hud() -> void:
	if _hud_line == null:
		return
	_update_readout()
	var e: MHEconomy = session.economy
	var est: Dictionary = e.estimate_day()
	_hud_line.text = MHSliceText.hud_line(view.cash(), session.clock.day(), session.clock.minute_of_day(),
		view.course_score_x10(), MHSliceText.income_per_hour_dollars(int(est["revenue"])), golfers.golfer_count())
	_detail_line.text = MHSliceText.detail_line(e.fee / 100, int(est["net"]) / 100, e.holes, e.members())
	_pause_button.text = "Resume" if session.clock.is_paused() else "Pause"
	_speed_button.text = "Speed x%d" % session.clock.speed()
	var slot: int = MHSliceLayout.next_hole_slot(built_slots, session.land.owned_ids())
	if slot < 0:
		_hole_button.text = "All holes built" if built_slots.size() >= MHSliceLayout.hole_slot_count() else "Holes need land"
		_hole_button.disabled = true
	else:
		_hole_button.text = "Build hole %s" % MHFormat.money(e.hole_cost_cents() / 100)
		_hole_button.disabled = false
	# The price is what the session charges (it grows 15 percent with every parcel bought). The button stays enabled
	# while a parcel exists, so a tap that cannot go through says why in the status line.
	var offer: Dictionary = land_offer()
	if int(offer["parcel"]) < 0:
		_land_button.text = "No land to buy"
		_land_button.disabled = true
	else:
		_land_button.text = "Buy land %s" % MHFormat.money(int(offer["price"]))
		_land_button.disabled = false
	if _menu_panel.visible:
		_menu_dirty = false
		_refresh_menu() # cash moves every game hour, so affordability is re-read on every HUD refresh


func _refresh_menu() -> void:
	var cash_dollars: int = session.economy.cash / 100
	for id: Variant in MHSliceLayout.ORDER:
		var bid: String = str(id)
		var refs: Dictionary = _menu_rows[bid] as Dictionary
		var row: Dictionary = MHBuildMenuModel.row(view, bid)
		var label: Label = refs["label"] as Label
		var button: MHTapButton = refs["button"] as MHTapButton
		if row.is_empty() or bool(row["maxed"]) or bool(row["demo_locked"]):
			label.text = MHSliceText.row_text(row, 0, cash_dollars)
			button.text = MHSliceText.buy_label(row, 0)
			button.disabled = true
			continue
		# Always the real charge (economy.price_cents), also while a requirement is unmet.
		var cost: int = _real_cost_dollars(bid, int(row["next_tier"]))
		label.text = MHSliceText.row_text(row, cost, cash_dollars)
		button.text = MHSliceText.buy_label(row, cost)
		button.disabled = not bool(row["met"]) or not session.economy.can_afford(cost * 100)


# ---------------------------------------------------------------- camera input (world area only)

func _unhandled_input(event: InputEvent) -> void:
	if controller == null:
		return
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			controller.desktop_pan(mm.relative)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			controller.desktop_zoom(1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			controller.desktop_zoom(-1)
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		_pinch_ref = 0.0
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		if not _touches.has(sd.index):
			return
		_touches[sd.index] = sd.position
		if _touches.size() == 1:
			controller.desktop_pan(sd.relative)
		elif _touches.size() == 2:
			var keys: Array = _touches.keys()
			var dist: float = (_touches[keys[0]] as Vector2).distance_to(_touches[keys[1]] as Vector2)
			if _pinch_ref <= 0.0:
				_pinch_ref = dist
			elif dist > _pinch_ref * 1.06:
				controller.desktop_zoom(1)
				_pinch_ref = dist
			elif dist < _pinch_ref * 0.94:
				controller.desktop_zoom(-1)
				_pinch_ref = dist


func _fail(message: String) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var box: VBoxContainer = VBoxContainer.new()
	layer.add_child(box)
	var l: Label = Label.new()
	l.text = message
	box.add_child(l)
	var back: MHTapButton = MHTapButton.new()
	back.text = "Back to launcher"
	back.custom_minimum_size = Vector2(200.0, 64.0)
	back.pressed.connect(_on_back)
	box.add_child(back)
	box.add_child(MHTouchBridge.new())

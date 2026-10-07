extends GdUnitTestSuite
## MHSliceLayout: parcel cells, building slots, hole sites. Pure logic. NOT YET RUN in Godot.

const START_OWNED: Array = [5, 6, 8, 9, 10]


func _owned(ids: Array) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i: Variant in ids:
		out.append(int(i))
	return out


func _tiers(ids: Array) -> Dictionary:
	var out: Dictionary = {}
	for i: Variant in ids:
		out[str(i)] = 1
	return out


func test_order_matches_the_art_catalogue() -> void:
	assert_int(MHSliceLayout.ORDER.size()).is_equal(MHBuildingMeshes.IDS.size())
	for i: int in range(MHBuildingMeshes.IDS.size()):
		assert_str(str(MHSliceLayout.ORDER[i])).is_equal(str(MHBuildingMeshes.IDS[i]))
		assert_bool(MHSliceLayout.PREFERENCE.has(str(MHSliceLayout.ORDER[i]))).is_true()


func test_reserved_parcels_are_the_hole_parcels_and_never_preferred() -> void:
	var reserved: PackedInt32Array = MHSliceLayout.reserved_parcels()
	assert_int(reserved.size()).is_equal(6)
	for p: int in [0, 4, 5, 7, 9, 11]:
		assert_bool(reserved.has(p)).is_true()
	for id: Variant in MHSliceLayout.ORDER:
		for p: Variant in (MHSliceLayout.PREFERENCE[str(id)] as Array):
			assert_bool(reserved.has(int(p))).override_failure_message("%s prefers reserved parcel %d" % [str(id), int(p)]).is_false()


func test_hole_tables_have_one_entry_per_slot() -> void:
	assert_int(MHSliceLayout.HOLE_PARCELS.size()).is_equal(MHSliceLayout.hole_slot_count())
	assert_int(MHSliceLayout.hole_slot_count()).is_equal(7)


func test_hole_corridors_lie_inside_their_parcels_and_the_map() -> void:
	for slot: int in range(MHSliceLayout.hole_slot_count()):
		var def: Dictionary = MHSliceLayout.hole_template(slot)
		var parcels: Array = MHSliceLayout.HOLE_PARCELS[slot] as Array
		var lo: Vector2 = Vector2(1000.0, 1000.0)
		var hi: Vector2 = Vector2(-1000.0, -1000.0)
		for p: Variant in parcels:
			var o: Vector2 = MHSliceLayout.parcel_origin_m(int(p))
			lo = Vector2(minf(lo.x, o.x), minf(lo.y, o.y))
			hi = Vector2(maxf(hi.x, o.x + MHSliceLayout.PARCEL_M), maxf(hi.y, o.y + MHSliceLayout.PARCEL_M))
		var fairway: Rect2 = MHSliceLayout.feature_rect_m(slot, ((def["features"] as Array)[0] as Dictionary)["rect"] as Array)
		var msg: String = "slot %d" % slot
		assert_float(fairway.position.x).override_failure_message(msg).is_greater_equal(lo.x)
		assert_float(fairway.position.y).override_failure_message(msg).is_greater_equal(lo.y)
		assert_float(fairway.end.x).override_failure_message(msg).is_less_equal(hi.x)
		assert_float(fairway.end.y).override_failure_message(msg).is_less_equal(hi.y)
		var pts: Dictionary = MHSliceLayout.hole_points_m(def)
		var green: Vector2 = pts["green"] as Vector2
		# The green fringe may overhang the parcel pair by under 2 m (it stays on the map).
		assert_float(green.y).override_failure_message(msg).is_less_equal(hi.y)
		assert_float(green.y + float(pts["green_radius_m"])).override_failure_message(msg).is_less_equal(hi.y + 2.0)


func test_hole_templates_pass_rating_validation() -> void:
	for slot: int in range(MHSliceLayout.hole_slot_count()):
		var check: Dictionary = MHRatingEngine.validate_input({"schema": 1, "engine": MHRatingEngine.RATING_VERSION,
			"hole": MHSliceLayout.hole_template(slot)})
		assert_bool(bool(check["ok"])).override_failure_message("slot %d: %s" % [slot, str(check.get("code", ""))]).is_true()


func test_hole_site_availability_follows_ownership() -> void:
	var owned: PackedInt32Array = _owned(START_OWNED)
	assert_bool(MHSliceLayout.can_build_hole_slot(0, owned)).is_true()
	assert_bool(MHSliceLayout.can_build_hole_slot(2, owned)).is_true()
	assert_bool(MHSliceLayout.can_build_hole_slot(3, owned)).is_false()
	assert_bool(MHSliceLayout.can_build_hole_slot(4, owned)).is_false()
	assert_bool(MHSliceLayout.can_build_hole_slot(-1, owned)).is_false()
	assert_bool(MHSliceLayout.can_build_hole_slot(99, owned)).is_false()
	assert_int(MHSliceLayout.next_hole_slot([], owned)).is_equal(0)
	assert_int(MHSliceLayout.next_hole_slot([0, 1], owned)).is_equal(2)
	assert_int(MHSliceLayout.next_hole_slot([0, 1, 2], owned)).is_equal(-1)
	assert_int(MHSliceLayout.next_hole_slot([0, 1, 2, 3], _owned([5, 6, 7, 9, 10, 11]))).is_equal(4)


func test_slot_centres() -> void:
	var c0: Vector2 = MHSliceLayout.slot_centre_m(0)
	assert_float(c0.x).is_equal_approx(8.0, 0.0001)
	assert_float(c0.y).is_equal_approx(8.0, 0.0001)
	var c3: Vector2 = MHSliceLayout.slot_centre_m(3)
	assert_float(c3.x).is_equal_approx(24.0, 0.0001)
	assert_float(c3.y).is_equal_approx(24.0, 0.0001)
	# Parcel 8 is col 0, row 2: origin (0, 64).
	var c32: Vector2 = MHSliceLayout.slot_centre_m(32)
	assert_float(c32.x).is_equal_approx(8.0, 0.0001)
	assert_float(c32.y).is_equal_approx(72.0, 0.0001)
	var annex: Vector2 = MHSliceLayout.slot_centre_m(MHSliceLayout.ANNEX_BASE)
	assert_float(annex.y).is_equal_approx(MHSliceLayout.ANNEX_Z0_M, 0.0001)
	assert_bool(MHSliceLayout.slot_is_annex(MHSliceLayout.ANNEX_BASE)).is_true()
	assert_int(MHSliceLayout.slot_parcel(MHSliceLayout.ANNEX_BASE)).is_equal(-1)
	assert_int(MHSliceLayout.slot_parcel(35)).is_equal(8)
	assert_float(MHSliceLayout.slot_centre_m(-5).x).is_equal(-1.0)


func test_every_cell_centre_is_inside_its_parcel() -> void:
	for slot: int in range(MHSliceLayout.ANNEX_BASE):
		var parcel: int = MHSliceLayout.slot_parcel(slot)
		var o: Vector2 = MHSliceLayout.parcel_origin_m(parcel)
		var c: Vector2 = MHSliceLayout.slot_centre_m(slot)
		assert_bool(Rect2(o, Vector2(MHSliceLayout.PARCEL_M, MHSliceLayout.PARCEL_M)).has_point(c)).is_true()


func test_fit_scale_never_enlarges() -> void:
	assert_float(MHSliceLayout.fit_scale(10.0, 8.0)).is_equal_approx(1.0, 0.0001)
	assert_float(MHSliceLayout.fit_scale(28.0, 34.0)).is_equal_approx(14.0 / 34.0, 0.0001)
	assert_float(MHSliceLayout.fit_scale(0.0, 0.0)).is_equal_approx(1.0, 0.0001)


func test_building_transform_centres_the_tier_5_footprint_on_the_slot() -> void:
	var bounds: AABB = AABB(Vector3(2.0, 0.0, -3.0), Vector3(10.0, 5.0, 8.0))
	var xf: Transform3D = MHSliceLayout.building_transform(0, bounds)
	# Footprint centre (7, -3+4=1) maps to the slot centre (8, 8) at scale 1.
	assert_float(xf.origin.x + 7.0).is_equal_approx(8.0, 0.0001)
	assert_float(xf.origin.z + 1.0).is_equal_approx(8.0, 0.0001)
	var big: AABB = AABB(Vector3(-14.0, 0.0, -17.0), Vector3(28.0, 9.0, 34.0))
	var xf2: Transform3D = MHSliceLayout.building_transform(0, big)
	var s: float = 14.0 / 34.0
	assert_float(xf2.basis.x.x).is_equal_approx(s, 0.0001)
	assert_float(xf2.origin.x).is_equal_approx(8.0, 0.0001)
	assert_float(xf2.origin.z).is_equal_approx(8.0, 0.0001)


func test_assign_slots_fills_the_start_facility_parcel_then_the_annex() -> void:
	var owned: PackedInt32Array = _owned(START_OWNED)
	var tiers: Dictionary = _tiers(["clubhouse", "pro_shop", "restaurant", "cart_barn", "maintenance"])
	var slots: Dictionary = MHSliceLayout.assign_slots(tiers, owned, {})
	assert_int(slots.size()).is_equal(5)
	assert_int(int(slots["clubhouse"])).is_equal(32)
	assert_int(int(slots["pro_shop"])).is_equal(33)
	assert_int(int(slots["restaurant"])).is_equal(34)
	assert_int(int(slots["cart_barn"])).is_equal(35)
	assert_int(int(slots["maintenance"])).is_equal(25) # parcel 6 east column, beside the starter holes


func test_assign_slots_are_unique_and_never_in_reserved_parcels() -> void:
	var owned: PackedInt32Array = _owned([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])
	var tiers: Dictionary = _tiers(MHSliceLayout.ORDER)
	var slots: Dictionary = MHSliceLayout.assign_slots(tiers, owned, {})
	assert_int(slots.size()).is_equal(10)
	var seen: Dictionary = {}
	for id: Variant in slots.keys():
		var slot: int = int(slots[id])
		assert_bool(seen.has(slot)).is_false()
		seen[slot] = true
		var parcel: int = MHSliceLayout.slot_parcel(slot)
		if parcel >= 0:
			assert_bool(MHSliceLayout.is_reserved(parcel)).is_false()
	# homes go to a homes parcel (3 or 15) when owned.
	assert_bool([3, 15].has(MHSliceLayout.slot_parcel(int(slots["homes"])))).is_true()


func test_heavy_buildings_prefer_free_golf_parcels() -> void:
	var owned: PackedInt32Array = _owned([1, 5, 6, 8, 9, 10])
	var slots: Dictionary = MHSliceLayout.assign_slots(_tiers(["driving_range", "clubhouse"]), owned, {})
	assert_int(MHSliceLayout.slot_parcel(int(slots["driving_range"]))).is_equal(1)
	assert_int(MHSliceLayout.slot_parcel(int(slots["clubhouse"]))).is_equal(8)


func test_slots_are_sticky_when_land_grows() -> void:
	var tiers: Dictionary = _tiers(["clubhouse", "driving_range"])
	var first: Dictionary = MHSliceLayout.assign_slots(tiers, _owned(START_OWNED), {})
	var grown: Dictionary = MHSliceLayout.assign_slots(tiers, _owned([1, 5, 6, 8, 9, 10]), first)
	assert_int(int(grown["clubhouse"])).is_equal(int(first["clubhouse"]))
	assert_int(int(grown["driving_range"])).is_equal(int(first["driving_range"]))
	# Without the previous result the driving range would move to the newly owned parcel 1.
	var fresh: Dictionary = MHSliceLayout.assign_slots(tiers, _owned([1, 5, 6, 8, 9, 10]), {})
	assert_int(MHSliceLayout.slot_parcel(int(fresh["driving_range"]))).is_equal(1)


func test_assign_slots_is_deterministic_and_skips_unowned_tiers() -> void:
	var tiers: Dictionary = {"clubhouse": 2, "pro_shop": 0, "restaurant": 1}
	var a: Dictionary = MHSliceLayout.assign_slots(tiers, _owned(START_OWNED), {})
	var b: Dictionary = MHSliceLayout.assign_slots(tiers, _owned(START_OWNED), {})
	assert_int(a.size()).is_equal(2)
	assert_bool(a.has("pro_shop")).is_false()
	for k: Variant in a.keys():
		assert_int(int(a[k])).is_equal(int(b[k]))


func test_an_invalid_previous_slot_is_replaced() -> void:
	var tiers: Dictionary = _tiers(["clubhouse"])
	# Slot 20 lies in parcel 5, which is reserved for a hole: not valid for a building.
	var out: Dictionary = MHSliceLayout.assign_slots(tiers, _owned(START_OWNED), {"clubhouse": 20})
	assert_int(int(out["clubhouse"])).is_equal(32)


func test_the_real_session_can_build_the_starter_holes_and_they_are_not_dead() -> void:
	var s: MHGameSession = MHGameSession.create()
	assert_object(s).is_not_null()
	var defs: Array = []
	for slot: int in range(2):
		defs.append(MHSliceLayout.hole_template(slot))
		var result: Dictionary = s.submit_course(defs)
		assert_bool(bool(result["ok"])).override_failure_message("slot %d: %s" % [slot, str(result["reason"])]).is_true()
	assert_int(s.economy.holes).is_equal(2)
	for r: Variant in s.hole_results():
		var row: Dictionary = r
		assert_bool(bool(row["valid"])).is_true()
		assert_bool(bool(row["dead"])).override_failure_message("score %d" % int(row["score"])).is_false()

func test_slice_starter_populates_world_points_for_every_hole() -> void:
	var s: MHGameSession = MHGameSession.create()
	assert_object(s).is_not_null()
	var view: MHLiveGameStateView = MHLiveGameStateView.new(s)
	assert_str(MHSliceStarter.setup(s, view)).is_equal("")
	assert_int(s.hole_origins_dm().size()).is_equal(MHSliceStarter.STARTER_HOLES)
	assert_int(s.hole_world_points_m().size()).is_equal(MHSliceStarter.STARTER_HOLES)


func test_origin_aware_hole_points_ignore_slot_placement() -> void:
	var h: Dictionary = {"slot_id": 0, "tee": [0, 0], "green": [0, 100, 8], "features": []}
	var a: Dictionary = MHSliceLayout.hole_points_at_origin_m(h, [600, 560])
	var b: Dictionary = MHSliceLayout.hole_points_at_origin_m(h, [1320, 560])
	assert_float((a["tee"] as Vector2).x).is_equal_approx(60.0, 0.001)
	assert_float((b["tee"] as Vector2).x).is_equal_approx(132.0, 0.001)
	assert_float((a["green"] as Vector2).y).is_equal_approx(147.44, 0.001)
	assert_float((b["green"] as Vector2).y).is_equal_approx(147.44, 0.001)

func test_session_world_route_uses_persisted_origins_not_slot_defaults() -> void:
	var s: MHGameSession = MHGameSession.create()
	var craft: MHCraftCourse = MHCraftCourse.new()
	craft.ensure_holes(3)
	var defs: Array = craft.valid_hole_defs()
	assert_bool(s.submit_course(defs)["ok"]).is_true()
	var origins: Array = [[600, 560], [960, 560], [1320, 560]]
	assert_bool(s.set_hole_origins_dm(origins)).is_true()
	var route: Array = s.hole_world_points_m()
	assert_int(route.size()).is_equal(3)
	for i: int in range(3):
		var tee: Vector2 = (route[i] as Dictionary)["tee"] as Vector2
		assert_float(tee.x).is_equal_approx(float(origins[i][0]) * 0.1 + float((defs[i] as Dictionary)["tee"][0]) * 0.9144, 0.001)
		assert_int(int((route[i] as Dictionary)["slot_id"])).is_equal(i)
	assert_bool(((route[0] as Dictionary)["tee"] as Vector2).is_equal_approx((route[1] as Dictionary)["tee"] as Vector2)).is_false()

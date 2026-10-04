extends GdUnitTestSuite
## MHUnlockRules: gates, prerequisites, demo caps, parcel requirements. NOT YET RUN.

var _defs: MHBuildingDefs


func before_test() -> void:
	_defs = MHBuildingDefs.load_default()


# A view that exactly meets one tier's gate and nothing more.
func _exact_view(id: String, tier: int) -> MHGateView:
	var v: MHGateView = MHGateView.new()
	var r: Dictionary = _defs.tier_requires(id, tier)
	v.holes = int(r["min_holes"])
	v.avg_hole_score = int(r["min_avg_hole_score"])
	v.parcels_owned = int(r["min_parcels_owned"])
	v.members = int(r["min_members"])
	v.parcels_by_kind = {"golf": 0, "facility": 0, "homes": 1}
	if tier > 1:
		v.tiers[id] = tier - 1
	for s: Variant in (r["specific"] as Array):
		var sd: Dictionary = s
		v.tiers[str(sd["building"])] = int(sd["min_tier"])
	var ao: Variant = r["any_others"]
	if ao != null:
		var aod: Dictionary = ao
		var placed: int = 0
		for other: Variant in _defs.ids():
			var oid: String = str(other)
			if oid == id or v.tiers.has(oid):
				continue
			if placed < int(aod["count"]):
				v.tiers[oid] = int(aod["min_tier"])
				placed += 1
	var ht: Variant = r["hosted_tournament"]
	if ht != null:
		var htd: Dictionary = ht
		v.hosted_level = str(htd["min_level"])
	return v


func test_exact_view_passes_every_tier() -> void:
	for b: Variant in _defs.ids():
		for t: int in range(1, 6):
			var rep: MHGateReport = MHUnlockRules.check_gate(_defs, str(b), t, _exact_view(str(b), t))
			assert_bool(rep.met).override_failure_message("%s tier %d: missing %s" % [str(b), t, str(rep.missing_keys())]).is_true()


func test_each_numeric_requirement_one_short_fails() -> void:
	for b: Variant in _defs.ids():
		var id: String = str(b)
		for t: int in range(1, 6):
			var r: Dictionary = _defs.tier_requires(id, t)
			var v: MHGateView = _exact_view(id, t)
			if int(r["min_holes"]) > 0:
				v.holes -= 1
				assert_bool(MHUnlockRules.check_gate(_defs, id, t, v).met).is_false()
				v.holes += 1
			if int(r["min_avg_hole_score"]) > 0:
				v.avg_hole_score -= 1
				assert_bool(MHUnlockRules.check_gate(_defs, id, t, v).met).is_false()
				v.avg_hole_score += 1
			v.parcels_owned -= 1
			assert_bool(MHUnlockRules.check_gate(_defs, id, t, v).met).is_false()
			v.parcels_owned += 1
			if int(r["min_members"]) > 0:
				v.members -= 1
				assert_bool(MHUnlockRules.check_gate(_defs, id, t, v).met).is_false()
				v.members += 1
			assert_bool(MHUnlockRules.check_gate(_defs, id, t, v).met).is_true()


func test_specific_prerequisite_one_short_fails() -> void:
	for b: Variant in _defs.ids():
		var id: String = str(b)
		for t: int in range(1, 6):
			var r: Dictionary = _defs.tier_requires(id, t)
			for s: Variant in (r["specific"] as Array):
				var sd: Dictionary = s
				var v: MHGateView = _exact_view(id, t)
				v.tiers[str(sd["building"])] = int(sd["min_tier"]) - 1
				var rep: MHGateReport = MHUnlockRules.check_gate(_defs, id, t, v)
				assert_bool(rep.met).is_false()
				assert_bool(rep.row_met("building:" + str(sd["building"]))).is_false()


func test_any_others_one_short_fails() -> void:
	# Clubhouse tier 4 needs two others at tier 3.
	var v: MHGateView = _exact_view("clubhouse", 4)
	assert_bool(MHUnlockRules.check_gate(_defs, "clubhouse", 4, v).met).is_true()
	for k: Variant in v.tiers.keys():
		if str(k) != "clubhouse":
			v.tiers[k] = 2
			break
	var rep: MHGateReport = MHUnlockRules.check_gate(_defs, "clubhouse", 4, v)
	assert_bool(rep.met).is_false()
	assert_bool(rep.row_met("any_others")).is_false()


func test_tier_5_needs_hosted_tournament_and_landmark_regional() -> void:
	var v: MHGateView = _exact_view("clubhouse", 5)
	assert_bool(MHUnlockRules.check_gate(_defs, "clubhouse", 5, v).met).is_true()
	v.hosted_level = ""
	assert_bool(MHUnlockRules.check_gate(_defs, "clubhouse", 5, v).met).is_false()
	var lv: MHGateView = _exact_view("landmark", 5)
	assert_bool(MHUnlockRules.check_gate(_defs, "landmark", 5, lv).met).is_true()
	lv.hosted_level = "local"
	assert_bool(MHUnlockRules.check_gate(_defs, "landmark", 5, lv).met).is_false()
	lv.hosted_level = "national"
	assert_bool(MHUnlockRules.check_gate(_defs, "landmark", 5, lv).met).is_true()


func test_tiers_must_be_bought_in_order() -> void:
	var v: MHGateView = _exact_view("clubhouse", 2)
	assert_bool(MHUnlockRules.check_gate(_defs, "clubhouse", 3, v).met).is_false()
	assert_bool(MHUnlockRules.check_gate(_defs, "clubhouse", 2, v).met).is_true()
	v.tiers["clubhouse"] = 2
	assert_bool(MHUnlockRules.check_gate(_defs, "clubhouse", 2, v).met).is_false()  # already built
	assert_int(MHUnlockRules.next_tier(v, "clubhouse")).is_equal(3)
	v.tiers["clubhouse"] = 5
	assert_int(MHUnlockRules.next_tier(v, "clubhouse")).is_equal(0)


func test_unknown_ids_and_tiers_fail() -> void:
	var v: MHGateView = MHGateView.new()
	assert_bool(MHUnlockRules.check_gate(_defs, "nope", 1, v).met).is_false()
	assert_bool(MHUnlockRules.check_gate(_defs, "clubhouse", 0, v).met).is_false()
	assert_bool(MHUnlockRules.check_gate(_defs, "clubhouse", 6, v).met).is_false()


func test_demo_caps_block_purchase() -> void:
	var caps: Dictionary = {"clubhouse": 3, "pro_shop": 2, "driving_range": 2, "restaurant": 1, "pool_spa": 0}
	for k: Variant in caps.keys():
		var id: String = str(k)
		var cap: int = int(caps[k])
		if cap < 5:
			var v: MHGateView = _exact_view(id, cap + 1)
			v.demo = true
			var rep: MHGateReport = MHUnlockRules.check_gate(_defs, id, cap + 1, v)
			assert_bool(rep.met).is_false()
			assert_bool(rep.demo_locked).is_true()
			v.demo = false
			assert_bool(MHUnlockRules.check_gate(_defs, id, cap + 1, v).met).is_true()
		if cap >= 1:
			var v2: MHGateView = _exact_view(id, cap)
			v2.demo = true
			assert_bool(MHUnlockRules.check_gate(_defs, id, cap, v2).demo_locked).is_false()


func test_demo_has_no_unreachable_tiers() -> void:
	# DEC-063: demo Clubhouse is capped at tier 2 (tier 3 needs 10 holes, demo caps at 9).
	assert_array(MHUnlockRules.demo_unreachable(_defs)).is_empty()


func test_heavy_parcel_requirement_in_gate() -> void:
	var v: MHGateView = _exact_view("driving_range", 2)
	assert_int(MHUnlockRules.parcels_required(_defs, "driving_range", 2)).is_equal(6)
	assert_int(MHUnlockRules.parcels_required(_defs, "clubhouse", 2)).is_equal(5)
	assert_bool(MHUnlockRules.check_gate(_defs, "driving_range", 2, v).met).is_true()
	v.parcels_owned = 5
	var rep: MHGateReport = MHUnlockRules.check_gate(_defs, "driving_range", 2, v)
	assert_bool(rep.met).is_false()
	assert_bool(rep.row_met("parcels_owned")).is_false()
	assert_bool(MHUnlockRules.check_gate(_defs, "clubhouse", 2, _exact_view("clubhouse", 2)).met).is_true()


func test_homes_need_a_homes_parcel() -> void:
	var v: MHGateView = _exact_view("homes", 1)
	assert_bool(MHUnlockRules.check_gate(_defs, "homes", 1, v).met).is_true()
	v.parcels_by_kind = {"golf": 4, "facility": 1, "homes": 0}
	var rep: MHGateReport = MHUnlockRules.check_gate(_defs, "homes", 1, v)
	assert_bool(rep.met).is_false()
	assert_bool(rep.row_met("parcel_kind:homes")).is_false()


func test_all_fifty_tiers_reachable_in_order() -> void:
	var v: MHGateView = MHGateView.new()
	v.holes = 18
	v.avg_hole_score = 100
	v.parcels_owned = 16
	v.parcels_by_kind = {"golf": 12, "facility": 2, "homes": 2}
	v.members = 50
	v.hosted_level = "major"
	var bought: int = 0
	var progress: bool = true
	while progress:
		progress = false
		for id: Variant in MHUnlockRules.purchasable(_defs, v):
			# re-check: earlier buys this round may not change the answer for others, but stay honest
			var nt: int = MHUnlockRules.next_tier(v, str(id))
			if nt > 0 and MHUnlockRules.check_gate(_defs, str(id), nt, v).met:
				v.tiers[str(id)] = nt
				bought += 1
				progress = true
	assert_int(bought).is_equal(50)


func test_dead_hole_rule_in_view() -> void:
	var v: MHGateView = MHGateView.new()
	v.set_from_hole_scores([80, 24, 25, 60, 10, 0], _defs.dead_hole_score_below())
	assert_int(v.holes).is_equal(3)               # 80, 25, 60 count; 24, 10, 0 are dead
	assert_int(v.avg_hole_score).is_equal(33)     # (80+24+25+60+10+0) / 6 = 33
	var empty: MHGateView = MHGateView.new()
	empty.set_from_hole_scores([], 25)
	assert_int(empty.holes).is_equal(0)
	assert_int(empty.avg_hole_score).is_equal(0)


func test_dead_holes_do_not_meet_hole_gate() -> void:
	var v: MHGateView = _exact_view("clubhouse", 2)
	v.set_from_hole_scores([90, 90, 90, 90, 90, 24], 25)  # 6 holes but one is dead
	assert_int(v.holes).is_equal(5)
	assert_bool(MHUnlockRules.check_gate(_defs, "clubhouse", 2, v).row_met("holes")).is_false()


func test_deterministic_repeat() -> void:
	var a: MHGateReport = MHUnlockRules.check_gate(_defs, "pool_spa", 3, _exact_view("pool_spa", 3))
	var b: MHGateReport = MHUnlockRules.check_gate(_defs, "pool_spa", 3, _exact_view("pool_spa", 3))
	assert_str(str(a.rows)).is_equal(str(b.rows))

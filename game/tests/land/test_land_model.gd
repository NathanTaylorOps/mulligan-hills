extends GdUnitTestSuite
## MHLandModel: 16 parcels, start plot, adjacency, prices, heavy-building parcel requirement. NOT YET RUN.

var _defs: MHBuildingDefs
var _land: MHLandModel


func before_test() -> void:
	_defs = MHBuildingDefs.load_default()
	_land = MHLandModel.create(_defs)


func test_layout_counts() -> void:
	assert_int(_land.parcel_count()).is_equal(16)
	var golf: int = 0
	var fac: int = 0
	var homes: int = 0
	for i: int in range(16):
		match _land.kind_of(i):
			"golf":
				golf += 1
			"facility":
				fac += 1
			"homes":
				homes += 1
	assert_int(golf).is_equal(12)
	assert_int(fac).is_equal(2)
	assert_int(homes).is_equal(2)


func test_start_plot() -> void:
	assert_int(_land.owned_count()).is_equal(5)
	assert_int(_land.owned_count_of_kind("golf")).is_equal(4)
	assert_int(_land.owned_count_of_kind("facility")).is_equal(1)
	assert_int(_land.owned_count_of_kind("homes")).is_equal(0)
	assert_int(_land.hole_capacity()).is_equal(6)
	assert_int(_land.home_slot_capacity()).is_equal(0)
	assert_int(_land.purchases_made()).is_equal(0)


func test_neighbors() -> void:
	assert_array(_land.neighbors(0)).is_equal(PackedInt32Array([1, 4]))
	assert_array(_land.neighbors(5)).is_equal(PackedInt32Array([1, 4, 6, 9]))
	assert_array(_land.neighbors(15)).is_equal(PackedInt32Array([11, 14]))
	assert_int(_land.neighbors(99).size()).is_equal(0)


func test_adjacency_rule() -> void:
	assert_str(_land.check_buy(0)).is_equal("not_adjacent")
	assert_str(_land.check_buy(5)).is_equal("already_owned")
	assert_str(_land.check_buy(-1)).is_equal("bad_id")
	assert_str(_land.check_buy(16)).is_equal("bad_id")
	assert_str(_land.check_buy(4)).is_equal("")
	assert_int(_land.buy(15)).is_equal(-1)
	assert_int(_land.owned_count()).is_equal(5)


func test_buyable_at_start_sorted() -> void:
	assert_array(_land.buyable_parcels()).is_equal(PackedInt32Array([1, 2, 4, 7, 11, 12, 13, 14]))


func test_price_curve_integer() -> void:
	# base 25000, growth 130 percent, truncating integer division each step
	assert_int(_land.price_for_purchase_index(0)).is_equal(25000)
	assert_int(_land.price_for_purchase_index(1)).is_equal(32500)
	assert_int(_land.price_for_purchase_index(2)).is_equal(42250)
	assert_int(_land.price_for_purchase_index(3)).is_equal(54925)
	assert_int(_land.next_price()).is_equal(25000)
	assert_int(_land.buy(4)).is_equal(25000)
	assert_int(_land.next_price()).is_equal(32500)
	assert_int(_land.buy(0)).is_equal(32500)


func test_buy_all_in_recommended_order() -> void:
	var total: int = 0
	var count: int = 0
	var guard: int = 0
	while _land.recommended_next() != -1 and guard < 40:
		var got: int = _land.buy(_land.recommended_next())
		assert_bool(got >= 0).is_true()
		total += got
		count += 1
		guard += 1
	assert_int(count).is_equal(11)
	assert_int(_land.owned_count()).is_equal(16)
	assert_int(_land.hole_capacity()).is_equal(18)
	assert_int(_land.home_slot_capacity()).is_equal(6)
	assert_int(_land.next_price()).is_equal(0)
	assert_int(_land.buyable_parcels().size()).is_equal(0)
	assert_bool(total > 0).is_true()


func test_recommended_prefers_golf_then_facility_then_homes() -> void:
	assert_int(_land.recommended_next()).is_equal(1)
	assert_str(_land.kind_of(_land.recommended_next())).is_equal("golf")


func test_hole_capacity_steps() -> void:
	# buying golf parcels 1, 2, 4, 0 gives 8 golf parcels = 12 holes
	for id: int in [1, 2, 4, 0]:
		assert_int(_land.buy(id)).is_greater(-1)
	assert_int(_land.owned_count_of_kind("golf")).is_equal(8)
	assert_int(_land.hole_capacity()).is_equal(12)


func test_heavy_parcel_requirement() -> void:
	assert_int(_land.heavy_extra_for("driving_range", 1)).is_equal(0)
	assert_int(_land.heavy_extra_for("driving_range", 2)).is_equal(1)
	assert_int(_land.heavy_extra_for("landmark", 5)).is_equal(1)
	assert_int(_land.heavy_extra_for("clubhouse", 5)).is_equal(0)
	assert_int(_land.parcels_required("driving_range", 2)).is_equal(6)
	assert_bool(_land.parcel_requirement_met("clubhouse", 2)).is_true()
	assert_bool(_land.parcel_requirement_met("driving_range", 2)).is_false()
	assert_int(_land.buy(4)).is_greater(-1)
	assert_bool(_land.parcel_requirement_met("driving_range", 2)).is_true()


func test_fill_view_and_gate_together() -> void:
	var v: MHGateView = MHGateView.new()
	_land.fill_view(v)
	assert_int(v.parcels_owned).is_equal(5)
	assert_int(v.kind_count("golf")).is_equal(4)
	v.holes = 6
	v.avg_hole_score = 32
	assert_bool(MHUnlockRules.check_gate(_defs, "clubhouse", 1, v).met).is_true()
	v.tiers["clubhouse"] = 1
	assert_bool(MHUnlockRules.check_gate(_defs, "driving_range", 1, v).met).is_true()
	v.tiers["driving_range"] = 1
	assert_bool(MHUnlockRules.check_gate(_defs, "driving_range", 2, v).row_met("parcels_owned")).is_false()
	assert_bool(MHUnlockRules.check_gate(_defs, "homes", 1, v).row_met("parcel_kind:homes")).is_false()


func test_load_owned_roundtrip_and_validation() -> void:
	_land.buy(4)
	_land.buy(0)
	var saved: PackedInt32Array = _land.owned_ids()
	var other: MHLandModel = MHLandModel.create(_defs)
	assert_str(other.load_owned(saved)).is_equal("")
	assert_array(other.owned_ids()).is_equal(saved)
	assert_str(other.load_owned(PackedInt32Array([99]))).is_equal("bad parcel id")
	assert_str(other.load_owned(PackedInt32Array([5, 5, 6, 8, 9, 10]))).is_equal("duplicate parcel id")
	assert_str(other.load_owned(PackedInt32Array([6, 8, 9, 10]))).is_equal("start parcel missing")
	assert_str(other.load_owned(PackedInt32Array([0, 5, 6, 8, 9, 10]))).is_equal("owned parcels are not connected")


func test_deterministic_two_runs() -> void:
	var a: MHLandModel = MHLandModel.create(_defs)
	var b: MHLandModel = MHLandModel.create(_defs)
	var sa: Array = []
	var sb: Array = []
	while a.recommended_next() != -1:
		sa.append(a.buy(a.recommended_next()))
	while b.recommended_next() != -1:
		sb.append(b.buy(b.recommended_next()))
	assert_str(str(sa)).is_equal(str(sb))

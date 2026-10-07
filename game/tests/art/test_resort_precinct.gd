extends GdUnitTestSuite
## Resort precinct composition remains presentation-only, deterministic in content,
## and scales decorative node count with the selected visual tier.

func _build(tier: MHVisualQuality.Tier) -> Dictionary:
	var parent: Node3D = Node3D.new()
	add_child(parent)
	var made: Array = MHResortPrecinct.populate(parent, "clubhouse", 3, "a", tier)
	var root: Node3D = made[0] as Node3D
	var names: Array[String] = []
	for child: Node in root.get_children():
		names.append(child.name)
	var out: Dictionary = {"count": root.get_child_count(), "names": names}
	parent.queue_free()
	return out


func test_precinct_scales_with_visual_quality() -> void:
	var low: Dictionary = _build(MHVisualQuality.Tier.LOW)
	var medium: Dictionary = _build(MHVisualQuality.Tier.MEDIUM)
	var high: Dictionary = _build(MHVisualQuality.Tier.HIGH)
	assert_bool(int(low["count"]) < int(medium["count"])).is_true()
	assert_bool(int(medium["count"]) < int(high["count"])).is_true()


func test_low_precinct_keeps_building_and_arrival_only() -> void:
	var low: Dictionary = _build(MHVisualQuality.Tier.LOW)
	assert_int(int(low["count"])).is_equal(2)
	assert_bool((low["names"] as Array[String]).has("Building")).is_true()
	assert_bool((low["names"] as Array[String]).has("ArrivalLandscape")).is_true()


func test_unknown_building_creates_nothing() -> void:
	var parent: Node3D = Node3D.new()
	add_child(parent)
	var made: Array = MHResortPrecinct.populate(parent, "not_real", 1, "a", MHVisualQuality.Tier.HIGH)
	assert_bool(made.is_empty()).is_true()
	assert_int(parent.get_child_count()).is_equal(0)
	parent.queue_free()

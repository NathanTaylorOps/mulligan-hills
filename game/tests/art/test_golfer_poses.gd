extends GdUnitTestSuite
## Golfer pose data: clip structure, sampling, and forward-kinematics sanity (grip, feet, club head).
## The keyframes were solved offline against a Python mirror of the same maths; these tests re-check them
## with the real GDScript. NOT YET RUN in Godot.

const KEY_GRIP_GAP: float = 0.08
const SAMPLE_GRIP_GAP: float = 0.12


func _joint_diff(a: Dictionary, b: Dictionary) -> float:
	var worst: float = 0.0
	for j: Variant in MHGolferMeshes.JOINTS:
		var joint: String = str(j)
		var ea: Vector3 = a.get(joint, Vector3.ZERO) as Vector3
		var eb: Vector3 = b.get(joint, Vector3.ZERO) as Vector3
		worst = maxf(worst, ea.distance_to(eb))
	var pa: Vector3 = a.get("hips_pos", Vector3.ZERO) as Vector3
	var pb: Vector3 = b.get("hips_pos", Vector3.ZERO) as Vector3
	return maxf(worst, pa.distance_to(pb) * 100.0)


func test_clips_are_well_formed() -> void:
	for c: Variant in MHGolferPoses.CLIPS:
		var clip: String = str(c)
		var keys: Array = MHGolferPoses.keys_for(clip)
		assert_int(keys.size()).is_greater_equal(3)
		assert_float(float((keys[0] as Array)[0])).is_equal(0.0)
		assert_float(float((keys[keys.size() - 1] as Array)[0])).is_equal_approx(MHGolferPoses.length_of(clip), 0.0001)
		var prev: float = -1.0
		for k: Variant in keys:
			var t: float = float((k as Array)[0])
			assert_bool(t > prev).override_failure_message(clip + " key times must increase").is_true()
			prev = t
			assert_bool(((k as Array)[1] as Dictionary).has("hips_pos")).is_true()
	assert_int(MHGolferPoses.key_count("swing")).is_equal(MHGolferPoses.keys_for("swing").size())
	assert_bool(MHGolferPoses.keys_for("nope").is_empty()).is_true()
	assert_float(MHGolferPoses.length_of("nope")).is_equal(0.0)


func test_only_known_joints_are_used() -> void:
	for c: Variant in MHGolferPoses.CLIPS:
		for k: Variant in MHGolferPoses.keys_for(str(c)):
			var pose: Dictionary = (k as Array)[1] as Dictionary
			for key: Variant in pose.keys():
				var key_name: String = str(key)
				var ok: bool = MHGolferMeshes.JOINTS.has(key_name) or key_name == "hips_pos" or key_name == "club_scale"
				assert_bool(ok).override_failure_message("unknown pose key " + key_name).is_true()


func test_looping_clips_close_their_loop() -> void:
	for clip in ["idle", "walk"]:
		assert_bool(MHGolferPoses.is_looping(clip)).is_true()
		var keys: Array = MHGolferPoses.keys_for(clip)
		var first: Dictionary = (keys[0] as Array)[1] as Dictionary
		var last: Dictionary = (keys[keys.size() - 1] as Array)[1] as Dictionary
		assert_float(_joint_diff(first, last)).is_less(0.01)
		assert_float(_joint_diff(MHGolferPoses.sample(clip, 0.0), MHGolferPoses.sample(clip, MHGolferPoses.length_of(clip)))).is_less(0.01)
		assert_float(_joint_diff(MHGolferPoses.sample(clip, 0.3), MHGolferPoses.sample(clip, 0.3 + MHGolferPoses.length_of(clip)))).is_less(0.01)
	assert_bool(MHGolferPoses.is_looping("swing")).is_false()
	assert_bool(MHGolferPoses.is_looping("putt")).is_false()


func test_one_shot_clips_clamp() -> void:
	for clip in ["swing", "putt"]:
		var length: float = MHGolferPoses.length_of(clip)
		assert_float(_joint_diff(MHGolferPoses.sample(clip, -5.0), MHGolferPoses.sample(clip, 0.0))).is_less(0.0001)
		assert_float(_joint_diff(MHGolferPoses.sample(clip, length + 5.0), MHGolferPoses.sample(clip, length))).is_less(0.0001)


func test_sample_hits_keys_and_blends_between_them() -> void:
	var keys: Array = MHGolferPoses.keys_for("walk")
	for k: Variant in keys:
		var kt: float = float((k as Array)[0])
		var kp: Dictionary = (k as Array)[1] as Dictionary
		if kt < 1.0:
			assert_float(_joint_diff(MHGolferPoses.sample("walk", kt), kp)).is_less(0.01)
	var a: Dictionary = (keys[0] as Array)[1] as Dictionary
	var b: Dictionary = (keys[1] as Array)[1] as Dictionary
	var mid: Dictionary = MHGolferPoses.sample("walk", 0.125)
	var ea: Vector3 = a.get("leg_l_upper", Vector3.ZERO) as Vector3
	var eb: Vector3 = b.get("leg_l_upper", Vector3.ZERO) as Vector3
	var em: Vector3 = mid.get("leg_l_upper", Vector3.ZERO) as Vector3
	assert_float(em.distance_to((ea + eb) * 0.5)).is_less(0.01)


func test_blend_handles_missing_joints_and_club_scale() -> void:
	var a: Dictionary = {"spine": Vector3(10.0, 0.0, 0.0)}
	var b: Dictionary = {"head": Vector3(0.0, 20.0, 0.0), "club_scale": 0.5, "hips_pos": Vector3(0.0, 0.2, 0.0)}
	var m: Dictionary = MHGolferPoses.blend(a, b, 0.5)
	assert_float((m["spine"] as Vector3).x).is_equal_approx(5.0, 0.0001)
	assert_float((m["head"] as Vector3).y).is_equal_approx(10.0, 0.0001)
	assert_float(float(m["club_scale"])).is_equal_approx(0.75, 0.0001)
	assert_float((m["hips_pos"] as Vector3).y).is_equal_approx(0.1, 0.0001)
	assert_bool(MHGolferPoses.sample("nope", 1.0).is_empty()).is_true()


func test_impact_times_sit_on_a_key_inside_the_clip() -> void:
	assert_float(MHGolferPoses.impact_time("idle")).is_equal(-1.0)
	assert_float(MHGolferPoses.impact_time("walk")).is_equal(-1.0)
	for clip in ["swing", "putt"]:
		var t: float = MHGolferPoses.impact_time(clip)
		assert_bool(t > 0.0 and t < MHGolferPoses.length_of(clip)).is_true()
		var has_key: bool = false
		for k: Variant in MHGolferPoses.keys_for(clip):
			if absf(float((k as Array)[0]) - t) < 0.0001:
				has_key = true
		assert_bool(has_key).override_failure_message(clip + " needs a key at impact").is_true()


func test_club_head_is_on_the_ball_at_address_and_impact() -> void:
	var cases: Array = [
		["swing", 0.0, MHGolferPoses.BALL_SWING],
		["swing", MHGolferPoses.IMPACT_SWING, MHGolferPoses.BALL_SWING],
		["putt", 0.0, MHGolferPoses.BALL_PUTT],
		["putt", MHGolferPoses.IMPACT_PUTT, MHGolferPoses.BALL_PUTT],
	]
	for c: Variant in cases:
		var row: Array = c as Array
		var head: Vector3 = MHGolferMeshes.club_head_position(MHGolferPoses.sample(str(row[0]), float(row[1])))
		var ball: Vector3 = row[2] as Vector3
		var msg: String = "%s at %.2f: head %s, expected near %s" % [str(row[0]), float(row[1]), str(head), str(ball)]
		assert_bool(head.distance_to(ball) < 0.12).override_failure_message(msg).is_true()


func test_two_hand_grip_holds_at_every_key_and_most_samples() -> void:
	for clip in ["swing", "putt"]:
		for k: Variant in MHGolferPoses.keys_for(clip):
			var gap: float = MHGolferMeshes.grip_gap((k as Array)[1] as Dictionary)
			assert_bool(gap < KEY_GRIP_GAP).override_failure_message("%s key %.2f gap %.3f" % [clip, float((k as Array)[0]), gap]).is_true()
		var length: float = MHGolferPoses.length_of(clip)
		var t: float = 0.0
		while t <= length:
			var gap2: float = MHGolferMeshes.grip_gap(MHGolferPoses.sample(clip, t))
			assert_bool(gap2 < SAMPLE_GRIP_GAP).override_failure_message("%s t=%.2f gap %.3f" % [clip, t, gap2]).is_true()
			t += 0.05


func test_feet_stay_on_the_ground_in_every_clip() -> void:
	for c: Variant in MHGolferPoses.CLIPS:
		var clip: String = str(c)
		var length: float = MHGolferPoses.length_of(clip)
		var t: float = 0.0
		while t <= length:
			var h: float = MHGolferMeshes.ankle_height(MHGolferPoses.sample(clip, t))
			assert_bool(h > 0.0 and h < 0.08).override_failure_message("%s t=%.2f lowest ankle %.3f" % [clip, t, h]).is_true()
			t += 0.05


func test_club_head_never_goes_through_the_ground() -> void:
	for c: Variant in MHGolferPoses.CLIPS:
		var clip: String = str(c)
		var length: float = MHGolferPoses.length_of(clip)
		var t: float = 0.0
		while t <= length:
			var head: Vector3 = MHGolferMeshes.club_head_position(MHGolferPoses.sample(clip, t))
			assert_bool(head.y > -0.01).override_failure_message("%s t=%.2f head y %.3f" % [clip, t, head.y]).is_true()
			t += 0.05


func test_swing_turns_the_chest_away_then_through() -> void:
	var address: Dictionary = MHGolferPoses.sample("swing", 0.0)
	var top: Dictionary = MHGolferPoses.sample("swing", 1.0)
	var finish: Dictionary = MHGolferPoses.sample("swing", 1.9)
	var top_chest: float = (top["hips"] as Vector3).y + (top["spine"] as Vector3).y
	var finish_chest: float = (finish["hips"] as Vector3).y + (finish["spine"] as Vector3).y
	assert_float(top_chest).is_less(-60.0)
	assert_float(finish_chest).is_greater(60.0)
	assert_float((address["spine"] as Vector3).x).is_greater(20.0)

extends GdUnitTestSuite
## MHTournamentSim: deterministic outcomes. Golden values come from an independent Python mirror of the algorithm
## (scratch script, not committed; it uses tools/reference/determinism/mh_rng.py). NOT YET RUN in Godot.

const SECRET: int = 777


func _seed(evt_id: int) -> int:
	return MHTournamentSim.event_seed(SECRET, evt_id, 1)


func _run(level_id: String, evt_id: int, mods: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = MHTournamentFixture.golden_ctx(_seed(evt_id))
	for k: Variant in mods.keys():
		ctx[k] = mods[k]
	return MHTournamentSim.evaluate(MHTournamentFixture.defs(), level_id, ctx)


func _first(arr: Array, n: int) -> Array:
	return arr.slice(0, n)


func test_event_seed_golden() -> void:
	assert_int(_seed(0)).is_equal(2070324804)
	assert_int(_seed(1)).is_equal(2031496134)
	assert_int(_seed(2)).is_equal(3964289467)
	assert_int(_seed(3)).is_equal(671949700)
	assert_int(_seed(4)).is_equal(1198258555)
	assert_int(_seed(8)).is_equal(3097767737)


func test_event_id_is_unique_per_day_and_level() -> void:
	assert_int(MHTournamentSim.event_id("local", 100)).is_equal(400)
	assert_int(MHTournamentSim.event_id("major", 100)).is_equal(403)
	assert_int(MHTournamentSim.event_id("local", 101)).is_equal(404)


func test_condition_draw_golden() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	assert_str(str(MHTournamentSim.draw_condition(d, _seed(0))["id"])).is_equal("breezy")
	assert_str(str(MHTournamentSim.draw_condition(d, _seed(1))["id"])).is_equal("calm")
	assert_str(str(MHTournamentSim.draw_condition(d, _seed(4))["id"])).is_equal("windy")
	assert_str(str(MHTournamentSim.draw_condition(d, _seed(8))["id"])).is_equal("storm")


func test_condition_draw_follows_the_weights() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	var counts: Dictionary = {"calm": 0, "breezy": 0, "windy": 0, "storm": 0}
	for i: int in range(2000):
		var cid: String = str(MHTournamentSim.draw_condition(d, MHRMath.tournament_seed(1, i, 1))["id"])
		counts[cid] = int(counts[cid]) + 1
	# python mirror: calm 991, breezy 534, windy 274, storm 201
	assert_int(int(counts["calm"])).is_equal(991)
	assert_int(int(counts["breezy"])).is_equal(534)
	assert_int(int(counts["windy"])).is_equal(274)
	assert_int(int(counts["storm"])).is_equal(201)


func test_local_golden_event_0() -> void:
	var r: Dictionary = _run("local", 0)
	assert_bool(bool(r["success"])).is_true()
	assert_int((r["failed_triggers"] as Array).size()).is_equal(0)
	assert_str(str(r["condition_id"])).is_equal("breezy")
	assert_int(int(r["satisfaction_pm"])).is_equal(950)
	assert_int(int(r["event_prestige_pm"])).is_equal(522)
	assert_int(int(r["prestige_points"])).is_equal(52)
	# 9,000 sponsor + 12 players x 300 entry + 150 spectators (Clubhouse 3) x 60% x 25 for 1 day
	assert_int(int(r["entry_income"])).is_equal(3600)
	assert_int(int(r["ticket_income"])).is_equal(2250)
	assert_int(int(r["cash_delta"])).is_equal(14850)
	assert_int(int(r["reputation_delta"])).is_equal(50)
	assert_int(int(r["cooldown_days"])).is_equal(10)
	assert_int(int(r["winner"])).is_equal(0)
	assert_int(int(r["winner_over_par"])).is_equal(-1)
	assert_array(_first(r["order"] as Array, 5)).contains_exactly([0, 9, 11, 2, 8])
	var totals: Array = r["totals"]
	assert_int(int(totals[0])).is_equal(39)
	assert_int(int(totals[9])).is_equal(40)
	assert_int(int(totals[6])).is_equal(46)


func test_local_golden_events_1_to_3() -> void:
	var r1: Dictionary = _run("local", 1)
	assert_str(str(r1["condition_id"])).is_equal("calm")
	assert_int(int(r1["winner"])).is_equal(6)
	assert_int(int(r1["winner_over_par"])).is_equal(0)
	assert_array(_first(r1["order"] as Array, 5)).contains_exactly([6, 8, 2, 7, 1])
	assert_int(int(r1["prestige_points"])).is_equal(53)
	var r2: Dictionary = _run("local", 2)
	assert_int(int(r2["winner"])).is_equal(6)
	assert_int(int(r2["winner_over_par"])).is_equal(-1)
	assert_array(_first(r2["order"] as Array, 5)).contains_exactly([6, 9, 7, 1, 2])
	var r3: Dictionary = _run("local", 3)
	assert_int(int(r3["winner"])).is_equal(11)
	assert_array(_first(r3["order"] as Array, 5)).contains_exactly([11, 8, 4, 7, 10])


func test_regional_and_national_golden() -> void:
	var rr: Dictionary = _run("regional", 0)
	assert_bool(bool(rr["success"])).is_true()
	assert_int(int(rr["winner"])).is_equal(11)
	assert_int(int(rr["winner_over_par"])).is_equal(-3)
	assert_array(_first(rr["order"] as Array, 5)).contains_exactly([11, 9, 6, 20, 17])
	assert_int(int(rr["prestige_points"])).is_equal(130)
	# 20,000 sponsor + 24 x 500 entry + 150 x 70% x 30 for 2 days
	assert_int(int(rr["entry_income"])).is_equal(12000)
	assert_int(int(rr["ticket_income"])).is_equal(6300)
	assert_int(int(rr["cash_delta"])).is_equal(38300)
	assert_int(int(rr["reputation_delta"])).is_equal(120)
	assert_int(int(rr["cooldown_days"])).is_equal(20)
	var rn: Dictionary = _run("national", 1)
	assert_int(int(rn["winner"])).is_equal(8)
	assert_int(int(rn["winner_over_par"])).is_equal(-11)
	assert_array(_first(rn["order"] as Array, 5)).contains_exactly([8, 15, 16, 4, 3])
	assert_int(int(rn["prestige_points"])).is_equal(318)
	assert_int((rn["totals"] as Array).size()).is_equal(36)


func test_major_fails_on_low_snapshot_with_penalties() -> void:
	var r: Dictionary = _run("major", 0)
	assert_bool(bool(r["success"])).is_false()
	assert_int((r["failed_triggers"] as Array).size()).is_equal(1)
	assert_str(str((r["failed_triggers"] as Array)[0])).is_equal("low_snapshot_score")
	assert_int(int(r["cash_delta"])).is_equal(-200000)
	assert_int(int(r["entry_income"])).is_equal(0)
	assert_int(int(r["ticket_income"])).is_equal(0)
	assert_int(int(r["reputation_delta"])).is_equal(-400)
	assert_int(int(r["prestige_points"])).is_equal(0)
	assert_int(int(r["cooldown_days"])).is_equal(67)
	# the field is still simulated for the result card
	assert_int(int(r["winner"])).is_equal(44)
	assert_int((r["totals"] as Array).size()).is_equal(48)


func test_same_inputs_same_result() -> void:
	var a: Dictionary = _run("regional", 5)
	var b: Dictionary = _run("regional", 5)
	assert_array(a["order"] as Array).contains_exactly(b["order"] as Array)
	assert_array(a["totals"] as Array).contains_exactly(b["totals"] as Array)
	assert_int(int(a["event_prestige_pm"])).is_equal(int(b["event_prestige_pm"]))


func test_different_seed_changes_the_field() -> void:
	var a: Dictionary = _run("regional", 5)
	var b: Dictionary = _run("regional", 6)
	assert_bool((a["totals"] as Array) == (b["totals"] as Array)).is_false()


func test_failure_trigger_boundaries() -> void:
	# pace: local needs 50, margin 10, so 40 passes and 39 fails
	var p40: Dictionary = _run("local", 0, {"pace_score": 40})
	assert_bool(bool(p40["success"])).is_true()
	assert_int(int(p40["event_prestige_pm"])).is_equal(482)
	var p39: Dictionary = _run("local", 0, {"pace_score": 39})
	assert_bool(bool(p39["success"])).is_false()
	assert_str(str((p39["failed_triggers"] as Array)[0])).is_equal("slow_pace")
	assert_int(int(p39["cooldown_days"])).is_equal(15)
	assert_int(int(p39["cash_delta"])).is_equal(-12500)
	assert_int(int(p39["reputation_delta"])).is_equal(-25)
	# snapshot: local needs 30, margin 3, so 27 passes and 26 fails
	assert_bool(bool(_run("local", 0, {"snapshot_score": 27})["success"])).is_true()
	var s26: Dictionary = _run("local", 0, {"snapshot_score": 26})
	assert_str(str((s26["failed_triggers"] as Array)[0])).is_equal("low_snapshot_score")
	assert_int(int(s26["event_prestige_pm"])).is_equal(459)


func test_unfair_holes_cost_satisfaction_then_fail() -> void:
	var one: Dictionary = _run("local", 0, {"fairness": [29, 60, 60, 60, 60, 60, 60, 60, 60, 60]})
	assert_bool(bool(one["success"])).is_true()
	assert_int(int(one["unfair_holes"])).is_equal(1)
	assert_int(int(one["satisfaction_pm"])).is_equal(850)
	assert_int(int(one["event_prestige_pm"])).is_equal(507)
	var two: Dictionary = _run("local", 0, {"fairness": [29, 29, 60, 60, 60, 60, 60, 60, 60, 60]})
	assert_bool(bool(two["success"])).is_false()
	assert_str(str((two["failed_triggers"] as Array)[0])).is_equal("unfair_hole")
	assert_int(int(two["satisfaction_pm"])).is_equal(750)


func test_bad_conditions_need_maintenance() -> void:
	# event 8 draws a storm (needs maintenance 3), event 4 a windy day (needs 2), event 0 a breezy day (needs 1)
	var storm_ok: Dictionary = _run("local", 8, {"maintenance_tier": 3})
	assert_str(str(storm_ok["condition_id"])).is_equal("storm")
	assert_bool(bool(storm_ok["success"])).is_true()
	var storm_bad: Dictionary = _run("local", 8, {"maintenance_tier": 2})
	assert_bool(bool(storm_bad["success"])).is_false()
	assert_str(str((storm_bad["failed_triggers"] as Array)[0])).is_equal("bad_conditions")
	assert_bool(bool(_run("local", 4, {"maintenance_tier": 2})["success"])).is_true()
	assert_bool(bool(_run("local", 4, {"maintenance_tier": 1})["success"])).is_false()
	assert_bool(bool(_run("local", 0, {"maintenance_tier": 0})["success"])).is_false()


func test_all_triggers_can_fire_together() -> void:
	var r: Dictionary = _run("local", 0, {"pace_score": 0, "snapshot_score": 0, "fairness": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "maintenance_tier": 0})
	assert_int((r["failed_triggers"] as Array).size()).is_equal(4)
	assert_int(int(r["satisfaction_pm"])).is_equal(0)
	assert_int(int(r["event_prestige_pm"])).is_equal(80)
	assert_int(int(r["cooldown_days"])).is_equal(15)


func test_only_listed_triggers_can_fail() -> void:
	var raw: Dictionary = MHDataJson.load_file(MHTournamentFixture.DATA_PATH)["value"]
	MHTestEdit.put(raw, ["levels", 0, "failure", "triggers"], ["slow_pace"])
	var d: MHTournamentDefs = MHTournamentDefs.new()
	assert_bool(d.load_from_dict(raw)).is_true()
	var ctx: Dictionary = MHTournamentFixture.golden_ctx(_seed(0))
	ctx["snapshot_score"] = 0
	ctx["maintenance_tier"] = 0
	var r: Dictionary = MHTournamentSim.evaluate(d, "local", ctx)
	assert_bool(bool(r["success"])).is_true()


func test_unknown_level_gives_empty_result() -> void:
	var r: Dictionary = MHTournamentSim.evaluate(MHTournamentFixture.defs(), "world_cup", MHTournamentFixture.golden_ctx(1))
	assert_bool(r.is_empty()).is_true()


func test_pars_fallback_and_validation() -> void:
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	var def10: Array = MHTournamentSim.pars_for(d, "local", [])
	assert_int(def10.size()).is_equal(10)
	assert_int(int(def10[3])).is_equal(5)
	assert_int(MHTournamentSim.pars_for(d, "regional", []).size()).is_equal(14)
	var own: Array = MHTournamentSim.pars_for(d, "local", [3, 4, 5, 4])
	assert_int(own.size()).is_equal(4)
	# an invalid par (6) falls back to the defaults
	assert_int(MHTournamentSim.pars_for(d, "local", [3, 6]).size()).is_equal(10)
	var too_many: Array = []
	for _i: int in range(19):
		too_many.append(4)
	assert_int(MHTournamentSim.pars_for(d, "local", too_many).size()).is_equal(10)


func test_stronger_skill_scores_lower_on_average() -> void:
	# a major field (skill 800 to 1000) beats a local field (450 to 800) on the same course and seed
	var d: MHTournamentDefs = MHTournamentFixture.defs()
	var pars: Array = d.default_pars().slice(0, 18)
	var cond: Dictionary = d.condition_by_id("calm")
	var local_f: Dictionary = MHTournamentSim.run_field(d, "local", 99, pars, 6000, cond)
	var major_f: Dictionary = MHTournamentSim.run_field(d, "major", 99, pars, 6000, cond)
	var local_sum: int = 0
	for t: Variant in (local_f["totals"] as Array):
		local_sum += int(t)
	var major_sum: int = 0
	for t2: Variant in (major_f["totals"] as Array):
		major_sum += int(t2)
	assert_int(major_sum * (local_f["totals"] as Array).size()).is_less(local_sum * (major_f["totals"] as Array).size())


func test_countback_and_hash_break_ties() -> void:
	# two players level on 8 strokes over two holes: the one better over the last hole wins the countback
	var strokes: Array = [[4, 4], [3, 5], [5, 3]]
	var totals: Array = [8, 8, 8]
	assert_bool(MHTournamentSim._better(1, 0, strokes, totals, 5)).is_false()
	assert_bool(MHTournamentSim._better(2, 0, strokes, totals, 5)).is_true()
	assert_bool(MHTournamentSim._better(0, 2, strokes, totals, 5)).is_false()
	# identical cards: lower H32(seed, id) wins, never a coin flip
	var same: Array = [[4, 4], [4, 4]]
	var tot2: Array = [8, 8]
	var ha: int = MHRMath.h32b(5, 0)
	var hb: int = MHRMath.h32b(5, 1)
	assert_bool(MHTournamentSim._better(0, 1, same, tot2, 5)).is_equal(ha < hb)
	assert_bool(MHTournamentSim._better(1, 0, same, tot2, 5)).is_equal(hb < ha)

extends GdUnitTestSuite
## MHProgressBridge: rows, intents and save blocks over the real progression, tournament and daily modules.
## NOT YET RUN (Godot is not available where this was written). Costs and rewards are read from the data, never
## hard-coded, because the economy is being rebalanced.

const UTC_DAY: int = 20730
const UNIX: int = UTC_DAY * 86400 + 36000
const GAME_DAY: int = 20
const SCORES: Array = [40, 41, 43, 44, 44, 45, 46, 46, 47, 46]


func _bridge(cash: int = 100000, view: Dictionary = {}, switches: Dictionary = {}) -> MHProgressBridge:
	var b: MHProgressBridge = MHProgressBridge.create()
	var v: Dictionary = view
	if v.is_empty():
		v = MHTournamentFixture.local_view()
	b.update_inputs(GAME_DAY, UNIX, cash, v, SCORES, switches, "Test Club")
	return b


func _entry(ch: Dictionary) -> Dictionary:
	var axes: Dictionary = {"accuracy": 50, "imagination": 50, "length": 50, "beauty": 50, "fairness": 50}
	var amin: Dictionary = ch.get("axis_min", {}) as Dictionary
	for k: Variant in amin.keys():
		axes[str(k)] = int(amin[k])
	var amax: Dictionary = ch.get("axis_max", {}) as Dictionary
	for k2: Variant in amax.keys():
		axes[str(k2)] = int(amax[k2])
	var length_yd: int = 350
	if ch.has("max_length_yd"):
		length_yd = int(ch["max_length_yd"])
	if ch.has("min_length_yd"):
		length_yd = int(ch["min_length_yd"])
	return {
		"valid": true, "par": int(ch.get("par", 4)), "length_yd": length_yd,
		"score": maxi(int(ch.get("min_score", 0)), int(ch.get("target_score", 0))), "axes": axes,
	}


func test_bridge_loads() -> void:
	var b: MHProgressBridge = MHProgressBridge.create()
	assert_str(b.load_error).is_empty()
	assert_bool(b.is_ready()).is_true()


func test_daily_row_enabled() -> void:
	var b: MHProgressBridge = _bridge()
	var d: Dictionary = b.daily_row()
	assert_bool(bool(d["enabled"])).is_true()
	assert_bool(MHStrings.has_key(str(d["title_key"]))).is_true()
	assert_bool(MHStrings.has_key(str(d["desc_key"]))).is_true()
	assert_int(int(d["attempts_left"])).is_equal(int(d["attempts_total"]))
	assert_int(int(d["ends_in_minutes"])).is_equal(MHDailyChallenge.minutes_until_rollover(UNIX))
	assert_bool(bool(d["completed_today"])).is_false()


func test_daily_row_kill_switch() -> void:
	var b: MHProgressBridge = _bridge(100000, {}, {"daily_challenge": false})
	assert_bool(bool(b.daily_row()["enabled"])).is_false()
	var r: Dictionary = b.start_daily()
	assert_bool(bool(r["ok"])).is_false()
	assert_str(str(r["reason"])).is_equal("disabled")


func test_start_daily_does_not_use_an_attempt() -> void:
	var b: MHProgressBridge = _bridge()
	var before: int = int(b.daily_row()["attempts_left"])
	var r: Dictionary = b.start_daily()
	assert_bool(bool(r["ok"])).is_true()
	assert_bool(not (r["challenge"] as Dictionary).is_empty()).is_true()
	assert_int(int(b.daily_row()["attempts_left"])).is_equal(before)


func test_attempts_run_out() -> void:
	var b: MHProgressBridge = _bridge()
	var total: int = int(b.daily_row()["attempts_total"])
	var bad: Dictionary = {"valid": false, "par": 4, "length_yd": 300, "score": 0, "axes": {}}
	for i: int in range(total):
		var f: Dictionary = b.finish_daily_attempt(bad)
		assert_bool(bool(f["ok"])).is_true()
		assert_bool(bool(f["completed"])).is_false()
	var r: Dictionary = b.start_daily()
	assert_bool(bool(r["ok"])).is_false()
	assert_str(str(r["reason"])).is_equal("no_attempts")
	assert_str(str(r["message_key"])).is_equal("toast.daily.no_attempts")
	var f2: Dictionary = b.finish_daily_attempt(bad)
	assert_bool(bool(f2["ok"])).is_false()


func test_finish_attempt_completes_and_registers_streak_once() -> void:
	var b: MHProgressBridge = _bridge()
	var ch: Dictionary = b.start_daily()["challenge"]
	var f: Dictionary = b.finish_daily_attempt(_entry(ch))
	assert_bool(bool(f["ok"])).is_true()
	assert_bool(bool(f["first_attempt"])).is_true()
	assert_bool(bool(f["completed"])).is_true()
	assert_bool(bool(f["newly_completed"])).is_true()
	assert_str(str(f["message_key"])).is_equal("toast.daily.done")
	assert_int(b.progression.streak.display_streak(UTC_DAY)).is_equal(1)
	var f2: Dictionary = b.finish_daily_attempt(_entry(ch))
	assert_bool(bool(f2["first_attempt"])).is_false()
	assert_bool(bool(f2["newly_completed"])).is_false()
	assert_int(b.progression.streak.display_streak(UTC_DAY)).is_equal(1)
	var d: Dictionary = b.daily_row()
	assert_bool(bool(d["completed_today"])).is_true()
	assert_bool(int(d["best_score"]) > 0).is_true()
	assert_int((d["board"] as Array).size()).is_equal(1)
	assert_str(str((d["board"] as Array)[0]["name"])).is_equal("Test Club")


func test_invalid_attempt_is_not_complete() -> void:
	var b: MHProgressBridge = _bridge()
	var f: Dictionary = b.finish_daily_attempt({"valid": false, "par": 4, "length_yd": 300, "score": 90, "axes": {}})
	assert_bool(bool(f["ok"])).is_true()
	assert_bool(bool(f["completed"])).is_false()
	assert_str(str(f["message_key"])).is_equal("toast.daily.tried")
	assert_bool(bool(b.daily_row()["completed_today"])).is_false()


func test_tournament_rows_shape_and_local_available() -> void:
	var b: MHProgressBridge = _bridge()
	var rows: Array = b.tournament_rows()
	assert_int(rows.size()).is_equal(4)
	for t: Variant in rows:
		var td: Dictionary = t
		for key: String in ["level", "status", "host_cost", "reward_cash", "reward_reputation", "cooldown_days", "rows", "can_host", "block_reason"]:
			assert_bool(td.has(key)).override_failure_message("missing " + key).is_true()
	var local: Dictionary = rows[0]
	assert_str(str(local["level"])).is_equal("local")
	assert_str(str(local["status"])).is_equal("available")
	assert_bool(bool(local["can_host"])).is_true()
	assert_str(str(local["block_reason"])).is_empty()


func test_tournament_rows_cash_short() -> void:
	var b: MHProgressBridge = _bridge(0)
	var local: Dictionary = b.tournament_rows()[0]
	assert_bool(bool(local["can_host"])).is_false()
	assert_str(str(local["block_reason"])).is_equal("cash")


func test_host_tournament_takes_cost_and_locks_others() -> void:
	var b: MHProgressBridge = _bridge()
	var cost: int = int(b.tournament_rows()[0]["host_cost"])
	var r: Dictionary = b.host_tournament("local")
	assert_bool(bool(r["ok"])).is_true()
	assert_int(int(r["cost"])).is_equal(cost)
	assert_str(str(r["message_key"])).is_equal("toast.tournament.started")
	assert_bool(b.tournaments.is_active()).is_true()
	assert_int(int(b.tournaments.active["snapshot_score"])).is_equal(MHTournamentRules.snapshot_score(b.tournament_defs, SCORES))
	var rows: Array = b.tournament_rows()
	assert_str(str(rows[0]["status"])).is_equal("active")
	for i: int in range(1, rows.size()):
		assert_str(str(rows[i]["status"])).is_equal("locked")
		assert_bool(bool(rows[i]["can_host"])).is_false()
	var again: Dictionary = b.host_tournament("local")
	assert_bool(bool(again["ok"])).is_false()
	assert_str(str(again["reason"])).is_equal("busy")
	assert_str(str(again["message_key"])).is_equal("tournament.blocked.busy")
	assert_bool(not b.tournament_event().is_empty()).is_true()


func test_host_tournament_refusals() -> void:
	var poor: Dictionary = _bridge(0).host_tournament("local")
	assert_bool(bool(poor["ok"])).is_false()
	assert_str(str(poor["reason"])).is_equal("cash")
	assert_int(int(poor["cost"])).is_equal(0)
	var off: Dictionary = _bridge(100000, {}, {"tournaments": false}).host_tournament("local")
	assert_bool(bool(off["ok"])).is_false()
	assert_str(str(off["reason"])).is_equal("disabled")
	var unk: Dictionary = _bridge().host_tournament("nope")
	assert_str(str(unk["reason"])).is_equal("unknown_level")
	assert_str(str(unk["message_key"])).is_equal("tournament.blocked.unknown_level")


func test_resolve_tournament() -> void:
	var b: MHProgressBridge = _bridge()
	var none: Dictionary = b.resolve_tournament({})
	assert_str(str(none["reason"])).is_equal("none_active")
	assert_bool(bool(b.host_tournament("local")["ok"])).is_true()
	var early: Dictionary = b.resolve_tournament(MHTournamentFixture.golden_ctx(1))
	assert_str(str(early["reason"])).is_equal("not_ready_yet")
	var resolve_day: int = b.tournaments.resolve_day(b.tournament_defs)
	b.update_inputs(resolve_day, UNIX, 100000, MHTournamentFixture.local_view(), SCORES, {}, "Test Club")
	var r: Dictionary = b.resolve_tournament(MHTournamentFixture.golden_ctx(1))
	assert_bool(bool(r["ok"])).override_failure_message(str(r["reason"])).is_true()
	assert_bool(not (r["result"] as Dictionary).is_empty()).is_true()
	assert_bool(not b.tournaments.is_active()).is_true()
	assert_bool(b.tournaments.hosted_count >= 1).is_true()
	assert_bool(b.tournament_event().is_empty()).is_true()


func test_handle_intent_routing() -> void:
	var b: MHProgressBridge = _bridge()
	var unk: Dictionary = b.handle_intent(&"something_else", {})
	assert_bool(bool(unk["handled"])).is_false()
	var daily: Dictionary = b.handle_intent(&"daily_play", {})
	assert_bool(bool(daily["handled"])).is_true()
	assert_bool(bool(daily["ok"])).is_true()
	var host: Dictionary = b.handle_intent(&"tournament_host", {"level": "local"})
	assert_bool(bool(host["handled"])).is_true()
	assert_bool(bool(host["ok"])).is_true()
	var bad: Dictionary = _bridge().handle_intent(&"tournament_host", {})
	assert_bool(bool(bad["handled"])).is_true()
	assert_bool(bool(bad["ok"])).is_false()


func test_save_round_trip() -> void:
	var b: MHProgressBridge = _bridge()
	b.host_tournament("local")
	b.finish_daily_attempt(_entry(b.start_daily()["challenge"]))
	var blocks: Dictionary = b.to_save_progress()
	for key: String in ["achievements", "stats", "streak", "tournaments", "daily"]:
		assert_bool(blocks.has(key)).override_failure_message("missing " + key).is_true()
	var b2: MHProgressBridge = _bridge()
	assert_bool(b2.load_save_progress(blocks)).is_true()
	assert_str(JSON.stringify(b2.to_save_progress(), "", true)).is_equal(JSON.stringify(blocks, "", true))
	assert_bool(b2.tournaments.is_active()).is_true()


func test_bad_block_changes_nothing() -> void:
	var b: MHProgressBridge = _bridge()
	b.host_tournament("local")
	var before: String = JSON.stringify(b.to_save_progress(), "", true)
	assert_bool(b.load_save_progress({"daily": "nope"})).is_false()
	assert_bool(b.load_save_progress({"tournaments": 5})).is_false()
	assert_str(JSON.stringify(b.to_save_progress(), "", true)).is_equal(before)
	assert_bool(b.load_save_progress({})).is_true()


func test_achievement_rows_and_levels() -> void:
	var b: MHProgressBridge = _bridge()
	var rows: Array = b.achievement_rows()
	assert_bool(rows.size() > 0).is_true()
	for a: Variant in rows:
		var ad: Dictionary = a
		for key: String in ["id", "category", "tier", "points", "hidden", "earned", "progress", "target"]:
			assert_bool(ad.has(key)).is_true()
	assert_bool(b.club_level() >= 1).is_true()
	assert_bool(b.club_points() >= 0).is_true()
	assert_bool(MHStrings.has_key(b.level_title_key())).is_true()


func test_new_strings_exist() -> void:
	for key: String in [
		"build.req.pace", "build.req.staff", "build.req.spectators", "tournament.blocked.busy", "tournament.blocked.cash",
		"tournament.blocked.cooldown", "tournament.blocked.disabled", "tournament.blocked.locked", "tournament.blocked.unknown_level",
		"toast.tournament.started", "toast.daily.done", "toast.daily.tried", "toast.daily.off", "toast.daily.no_attempts",
		"daily.completed", "gallery.tournament_ready",
	]:
		assert_bool(MHStrings.has_key(key)).override_failure_message("missing string " + key).is_true()

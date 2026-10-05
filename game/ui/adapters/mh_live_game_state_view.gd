class_name MHLiveGameStateView
extends MHGameStateView
## Read-only adapter over the running session. It never manufactures cash, ratings or progression.
@warning_ignore_start("integer_division")

var editor: MHTerrainEditor

var _session: MHGameSession


func _init(session: MHGameSession) -> void:
	_session = session
	_session.changed.connect(_on_session_changed)


func _on_session_changed() -> void:
	changed.emit()


func is_demo() -> bool:
	return _session.demo


func club_name() -> String:
	return _session.club_name


func cash() -> int:
	return _session.economy.cash / 100


func day() -> int:
	return _session.clock.day()


func minute_of_day() -> int:
	return _session.clock.minute_of_day()


func speed() -> int:
	return _session.clock.speed()


func is_paused() -> bool:
	return _session.clock.is_paused()


func tokens_earned() -> int:
	return _session.ledger.earned


func tokens_paid() -> int:
	return 0 # DEC-064: no paid tokens in v1.


func course_score_x10() -> int:
	return int(_session.course_result().get("course_x10", 0))


func members() -> int:
	return _session.economy.members()


func income_per_day() -> int:
	return int(_session.economy.estimate_day()["revenue"]) / 100


func upkeep_per_day() -> int:
	return _session.economy.daily_upkeep() / 100


func hole_scores() -> Array:
	return _session.hole_scores()


func hole_rating(hole_no: int) -> Dictionary:
	var ratings: Array = _session.hole_results()
	if hole_no < 1 or hole_no > ratings.size():
		return {}
	var r: Dictionary = ratings[hole_no - 1]
	var reasons: Array = []
	for v: Variant in MHRatingEngine.explain(r):
		var row: Dictionary = v
		reasons.append({"code": str(row["code"]).substr(2).to_int(),
			"severity": MHAdvisor.SEV_INFO - int(row["severity"]), "a": 0, "b": 0})
	return {"hole_no": hole_no, "par": int(r.get("par", 0)), "length_yd": int(r.get("L", 0)),
		"valid": bool(r.get("valid", false)), "dead": bool(r.get("dead", false)),
		"score_pm": int(r.get("score_pm", 0)), "accuracy_pm": int(r.get("A", 0)),
		"imagination_pm": int(r.get("I", 0)), "length_pm": int(r.get("Len", 0)),
		"beauty_pm": int(r.get("B", 0)), "fairness_pm": int(r.get("F", 0)), "reasons": reasons}


func building_defs() -> MHBuildingDefs:
	return _session.defs


func gate_view() -> MHGateView:
	return _session.gate_view()


func added_daily_income(building_id: String, tier: int) -> int:
	var index: int = _session.economy.params.building_index(building_id)
	if index < 0 or tier < 1 or tier > MHEconomyParams.TIERS:
		return 0
	return _session.economy.params.added_dollars[index * MHEconomyParams.TIERS + tier - 1]


func land() -> MHLandModel:
	return _session.land


func daily_challenge() -> Dictionary:
	return _session.bridge.daily_row()


func tournaments() -> Array:
	return _session.bridge.tournament_rows()


func tournament_event() -> Dictionary:
	return _session.bridge.tournament_event()


func club_level() -> int:
	return _session.bridge.club_level()


func club_points() -> int:
	return _session.bridge.club_points()


func points_for_next_level() -> int:
	return _session.bridge.points_for_next_level()


func level_title_key() -> String:
	return _session.bridge.level_title_key()


func achievements() -> Array:
	return _session.bridge.achievement_rows()


func recovery_offer() -> Dictionary:
	var e: MHEconomy = _session.economy
	return {"active": e.is_bankrupt(), "shortfall": e.arrears / 100,
		"loan_amount": e.loan_amount_cents() / 100,
		"reputation_penalty": e.params.c("loan_rep_penalty_permille") / 10,
		"token_cost": e.params.c("recovery_token_cost")}


func can_undo() -> bool:
	return editor != null and not editor.is_stroke_open() and editor.undo_stack.undo_count() > 0


func can_redo() -> bool:
	return editor != null and not editor.is_stroke_open() and editor.undo_stack.redo_count() > 0

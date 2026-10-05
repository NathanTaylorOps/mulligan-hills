class_name MHScoreScreen
extends MHScreen
## Course score: the 0..100.0 course score, band, per-hole bars, the weakest hole, dead holes (score under the
## dead-hole line, DEC-063: they count in the average but not toward hole-count gates) and the next score gate.


func screen_id() -> String:
	return MHScreenIds.SCORE


func title_key() -> String:
	return "score.title"


func _fill() -> void:
	var scores: Array = view.hole_scores()
	var x10: int = view.course_score_x10()
	var defs: MHBuildingDefs = view.building_defs()
	var card: PanelContainer = MHUIKit.card(8)
	var box: VBoxContainer = MHUIKit.card_box(card)
	_body.add_child(card)
	box.add_child(MHUIKit.label(MHFormat.score_x10(x10), &"BigNumberLabel", false))
	box.add_child(MHUIKit.label(MHStrings.t(MHScoreModel.band_key(x10)), &"H2Label"))
	box.add_child(MHUIKit.label(MHStrings.t("score.holes_line", {"count": scores.size(), "members": view.members()}), &"MutedLabel"))
	if scores.is_empty():
		box.add_child(MHUIKit.label(MHStrings.t("score.no_holes"), &"WarnLabel"))
		return
	var dead_below: int = 25
	if defs != null and defs.is_loaded():
		dead_below = defs.dead_hole_score_below()
	var dead: int = MHScoreModel.count_dead(scores, dead_below)
	var weak: Dictionary = MHScoreModel.weakest(scores)
	box.add_child(MHUIKit.label(MHStrings.t("score.weakest", {"hole": int(weak["hole_no"]), "score": int(weak["score"])}), &"Label"))
	if dead > 0:
		box.add_child(MHUIKit.label(MHStrings.t("score.dead", {"count": dead, "line": dead_below}), &"AccentLabel"))
	var gate: Dictionary = MHScoreModel.next_gate(defs, int(x10 / 10))
	if gate.is_empty():
		box.add_child(MHUIKit.label(MHStrings.t("score.gates_clear"), &"GoodLabel"))
	else:
		box.add_child(MHUIKit.label(MHStrings.t("score.next_gate", {"tier": int(gate["tier"]), "need": int(gate["need"])}), &"Label"))

	var list: PanelContainer = MHUIKit.card(6)
	var lb: VBoxContainer = MHUIKit.card_box(list)
	_body.add_child(list)
	lb.add_child(MHUIKit.label(MHStrings.t("score.per_hole"), &"H2Label"))
	for i: int in range(scores.size()):
		var sc: int = int(scores[i])
		var h: HBoxContainer = MHUIKit.hbox(10)
		var n: Label = MHUIKit.label(MHStrings.t("score.hole_n", {"hole": i + 1}), &"Label", false)
		n.custom_minimum_size = Vector2(110.0, 0.0)
		h.add_child(n)
		h.add_child(MHUIKit.progress(sc, 100, sc < dead_below))
		var v: Label = MHUIKit.label(str(sc), &"Label", false)
		v.custom_minimum_size = Vector2(48.0, 0.0)
		h.add_child(v)
		var open: MHTapButton = MHUIKit.button(ctx, MHStrings.t("score.open"), &"GhostButton", 90.0)
		open.pressed.connect(_on_open.bind(i + 1))
		h.add_child(open)
		lb.add_child(h)


func _on_open(hole: int) -> void:
	send(&"nav", {"screen": MHScreenIds.RATING, "args": {"hole": hole}})

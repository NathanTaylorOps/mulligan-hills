class_name MHDailyScreen
extends MHScreen
## Daily challenge: today's brief, attempts left, target score, best score, streak, local board. A remote kill
## switch can turn the feature off (DEC-059); then only a notice shows. Intent: daily_play.


func screen_id() -> String:
	return MHScreenIds.DAILY


func title_key() -> String:
	return "daily.title"


func _fill() -> void:
	var d: Dictionary = view.daily_challenge()
	if not bool(d.get("enabled", false)):
		_body.add_child(MHUIKit.label(MHStrings.t("daily.paused"), &"WarnLabel"))
		return
	var card: PanelContainer = MHUIKit.card(8)
	var box: VBoxContainer = MHUIKit.card_box(card)
	_body.add_child(card)
	box.add_child(MHUIKit.label(MHStrings.t(str(d["title_key"])), &"H2Label"))
	box.add_child(MHUIKit.label(MHStrings.t(str(d["desc_key"])), &"Label"))
	box.add_child(MHUIKit.label(MHStrings.t("daily.target", {"score": int(d["target_score"]), "best": int(d["best_score"])}), &"Label"))
	box.add_child(MHUIKit.label(MHStrings.t("daily.attempts", {"left": int(d["attempts_left"]), "total": int(d["attempts_total"])}), &"MutedLabel"))
	box.add_child(MHUIKit.label(MHStrings.t("daily.streak", {"days": int(d["streak_days"])}), &"MutedLabel"))
	box.add_child(MHUIKit.label(MHStrings.t("daily.ends", {"time": MHFormat.duration_minutes(int(d["ends_in_minutes"]))}), &"MutedLabel"))
	var play: MHTapButton = MHUIKit.button(ctx, MHStrings.t("daily.play"), &"PrimaryButton")
	play.disabled = int(d["attempts_left"]) <= 0
	play.pressed.connect(send.bind(&"daily_play", {}))
	box.add_child(play)

	var board: PanelContainer = MHUIKit.card(6)
	var bb: VBoxContainer = MHUIKit.card_box(board)
	_body.add_child(board)
	bb.add_child(MHUIKit.label(MHStrings.t("daily.board"), &"H2Label"))
	var rows: Array = d.get("board", [])
	var rank: int = 1
	for r: Variant in rows:
		var rd: Dictionary = r
		bb.add_child(MHUIKit.label(MHStrings.t("daily.board_row", {"rank": rank, "name": str(rd["name"]), "score": int(rd["score"])}), &"Label"))
		rank += 1

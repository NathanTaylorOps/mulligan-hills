class_name MHRatingScreen
extends MHScreen
## Hole rating panel: the 0..100 hole score, the four axes (Accuracy, Imagination, Length, Beauty), the Fairness
## modifier, and advisor notes from rating reason codes (at most 3 shown, worst first, praise last; "More notes"
## shows all). Hole picker is a strip of numbered buttons. Axis values arrive in permille and show as 0..100.
## Intent: opened {hole} when a hole is picked (the game may highlight it in the world).

const AXES: Array = [
	["accuracy_pm", "rating.axis.accuracy"],
	["imagination_pm", "rating.axis.imagination"],
	["length_pm", "rating.axis.length"],
	["beauty_pm", "rating.axis.beauty"],
]

var _hole: int = 1
var _show_all: bool = false


func screen_id() -> String:
	return MHScreenIds.RATING


func title_key() -> String:
	return "rating.title"


func _fill() -> void:
	var n: int = view.hole_count()
	if n <= 0:
		_body.add_child(MHUIKit.label(MHStrings.t("rating.no_holes"), &"WarnLabel"))
		return
	_hole = clampi(int(args.get("hole", _hole)), 1, n)
	args["hole"] = _hole
	var strip: HFlowContainer = MHUIKit.flow(6)
	_body.add_child(strip)
	for i: int in range(1, n + 1):
		var b: MHTapButton = MHUIKit.button(ctx, str(i), &"SelectedButton" if i == _hole else &"ChipButton", 56.0)
		b.pressed.connect(_on_pick.bind(i))
		strip.add_child(b)
	var r: Dictionary = view.hole_rating(_hole)
	if r.is_empty():
		_body.add_child(MHUIKit.label(MHStrings.t("rating.no_holes"), &"WarnLabel"))
		return

	var card: PanelContainer = MHUIKit.card(8)
	var box: VBoxContainer = MHUIKit.card_box(card)
	_body.add_child(card)
	box.add_child(MHUIKit.label(MHStrings.t("rating.hole_line", {"hole": _hole, "par": int(r["par"]), "length": MHFormat.distance(int(r["length_yd"]), ctx.metric())}), &"H2Label"))
	var score: int = MHFormat.score_from_pm(int(r["score_pm"]))
	var big: Label = MHUIKit.label(str(score), &"BigNumberLabel", false)
	box.add_child(big)
	if not bool(r["valid"]):
		box.add_child(MHUIKit.label(MHStrings.t("rating.invalid"), &"AccentLabel"))
	elif bool(r["dead"]):
		box.add_child(MHUIKit.label(MHStrings.t("rating.dead"), &"AccentLabel"))
	else:
		box.add_child(MHUIKit.label(MHStrings.t(MHScoreModel.band_key(int(r["score_pm"]))), &"MutedLabel"))
	for a: Variant in AXES:
		var pair: Array = a
		box.add_child(_axis_row(str(pair[1]), int(r[str(pair[0])])))
	box.add_child(MHUIKit.label(MHStrings.t("rating.fairness", {"percent": MHFormat.percent_pm(int(r["fairness_pm"]))}), &"MutedLabel"))

	var notes: PanelContainer = MHUIKit.card(8)
	var nb: VBoxContainer = MHUIKit.card_box(notes)
	_body.add_child(notes)
	nb.add_child(MHUIKit.label(MHStrings.t("rating.advisor"), &"H2Label"))
	var reasons: Array = r["reasons"]
	var sorted: Array = MHAdvisor.sorted_reasons(reasons)
	var shown: Array = sorted if _show_all else MHAdvisor.top_reasons(reasons)
	if shown.is_empty():
		nb.add_child(MHUIKit.label(MHStrings.t("rating.no_notes"), &"MutedLabel"))
	for row: Variant in shown:
		nb.add_child(_reason_row(row, r))
	if sorted.size() > MHAdvisor.MAX_SHOWN:
		var more: MHTapButton = MHUIKit.button(ctx, MHStrings.t("rating.fewer" if _show_all else "rating.more", {"count": sorted.size()}), &"GhostButton")
		more.pressed.connect(_on_more)
		nb.add_child(more)


func _axis_row(label_k: String, pm: int) -> Control:
	var h: HBoxContainer = MHUIKit.hbox(10)
	var name_label: Label = MHUIKit.label(MHStrings.t(label_k), &"Label", false)
	name_label.custom_minimum_size = Vector2(150.0, 0.0)
	h.add_child(name_label)
	h.add_child(MHUIKit.progress(pm, 1000, pm < 300))
	var val: Label = MHUIKit.label(str(MHFormat.score_from_pm(pm)), &"Label", false)
	val.custom_minimum_size = Vector2(48.0, 0.0)
	h.add_child(val)
	return h


func _reason_row(row: Variant, rating: Dictionary) -> Control:
	var d: Dictionary = row
	var code: int = int(d.get("code", 0))
	var sev: int = int(d.get("severity", MHAdvisor.SEV_INFO))
	var h: HBoxContainer = MHUIKit.hbox(10)
	var variant: StringName = &"WarnLabel"
	if MHAdvisor.is_praise(sev):
		variant = &"GoodLabel"
	elif sev <= MHAdvisor.SEV_SEVERE:
		variant = &"AccentLabel"
	var tag: Label = MHUIKit.label(MHStrings.t(MHAdvisor.severity_key(sev)), variant, false)
	tag.custom_minimum_size = Vector2(110.0, 0.0)
	h.add_child(tag)
	var key: String = MHAdvisor.string_key(code)
	var params: Dictionary = {"a": int(d.get("a", 0)), "b": int(d.get("b", 0)), "hole_no": int(rating["hole_no"]), "par": int(rating["par"]), "code": MHAdvisor.code_label(code)}
	var text_value: String = MHStrings.t(key, params) if MHStrings.has_key(key) else MHStrings.t("advisor.unknown", params)
	h.add_child(MHUIKit.label(text_value, &"Label"))
	return h


func _on_pick(i: int) -> void:
	args["hole"] = i
	_hole = i
	_show_all = false
	send(&"opened", {"hole": i})
	refresh()


func _on_more() -> void:
	_show_all = not _show_all
	refresh()

class_name MHAchievementsScreen
extends MHScreen
## Achievements: category filter, points total, earned and locked rows with progress. Hidden achievements show as
## "Hidden" until earned. Names and descriptions come from keys achievement.<id>.name and .desc.

const CATEGORIES: Array = ["all", "design", "buildings", "growth", "tournaments", "commissions", "daily", "misc"]

var _filter: String = "all"


func screen_id() -> String:
	return MHScreenIds.ACHIEVEMENTS


func title_key() -> String:
	return "ach.title"


func _fill() -> void:
	var list: Array = view.achievements()
	var points: int = 0
	var earned_n: int = 0
	for a: Variant in list:
		var d: Dictionary = a
		if bool(d["earned"]):
			points += int(d["points"])
			earned_n += 1
	_body.add_child(MHUIKit.label(MHStrings.t("ach.summary", {"earned": earned_n, "total": list.size(), "points": points}), &"H2Label"))
	var tabs: HFlowContainer = MHUIKit.flow(6)
	_body.add_child(tabs)
	for c: Variant in CATEGORIES:
		var cs: String = str(c)
		var tb: MHTapButton = MHUIKit.button(ctx, MHStrings.t("ach.cat." + cs), &"SelectedButton" if cs == _filter else &"ChipButton", 96.0)
		tb.pressed.connect(_on_filter.bind(cs))
		tabs.add_child(tb)
	var g: GridContainer = MHUIKit.grid(ctx.columns(2), 10)
	_body.add_child(g)
	for a2: Variant in filtered(list, _filter):
		g.add_child(_row(a2))


## Pure: rows of one category ("all" keeps everything), earned first, then by data order.
static func filtered(list: Array, category: String) -> Array:
	var earned: Array = []
	var open: Array = []
	for a: Variant in list:
		var d: Dictionary = a
		if category != "all" and str(d["category"]) != category:
			continue
		if bool(d["earned"]):
			earned.append(d)
		else:
			open.append(d)
	return earned + open


func _row(a: Variant) -> Control:
	var d: Dictionary = a
	var id: String = str(d["id"])
	var earned: bool = bool(d["earned"])
	var card: PanelContainer = MHUIKit.card(4)
	var box: VBoxContainer = MHUIKit.card_box(card)
	if bool(d["hidden"]) and not earned:
		box.add_child(MHUIKit.label(MHStrings.t("ach.hidden"), &"MutedLabel"))
		return card
	box.add_child(MHUIKit.label(MHStrings.t("achievement." + id + ".name"), &"GoodLabel" if earned else &"Label"))
	box.add_child(MHUIKit.label(MHStrings.t("achievement." + id + ".desc"), &"MutedLabel"))
	if earned:
		box.add_child(MHUIKit.label(MHStrings.t("ach.earned", {"points": int(d["points"])}), &"GoodLabel"))
	else:
		box.add_child(MHUIKit.progress(int(d["progress"]), int(d["target"])))
		box.add_child(MHUIKit.label(MHStrings.t("ach.progress", {"have": int(d["progress"]), "need": int(d["target"]), "points": int(d["points"])}), &"MutedLabel"))
	return card


func _on_filter(c: String) -> void:
	_filter = c
	refresh()

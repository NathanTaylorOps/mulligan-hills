class_name MHLandScreen
extends MHScreen
## Land purchase: the 4x4 parcel map (golf, facility, homes), ownership, price of the next parcel, capacity.
## A parcel can be bought only when it touches land you own (MHLandModel.check_buy). Intent: buy_parcel {parcel, price}.

var _selected: int = -1


func screen_id() -> String:
	return MHScreenIds.LAND


func title_key() -> String:
	return "land.title"


func _fill() -> void:
	var land: MHLandModel = view.land()
	var defs: MHBuildingDefs = view.building_defs()
	if land == null or defs == null or not defs.is_loaded():
		_body.add_child(MHUIKit.label(MHStrings.t("land.unavailable"), &"WarnLabel"))
		return
	var cfg: Dictionary = defs.land_config()
	var grid_cfg: Dictionary = cfg["grid"]
	var cols: int = maxi(1, int(grid_cfg["cols"]))
	var buyable: PackedInt32Array = land.buyable_parcels()
	var recommended: int = land.recommended_next()
	var price: int = land.next_price()

	var info: PanelContainer = MHUIKit.card(6)
	var ib: VBoxContainer = MHUIKit.card_box(info)
	ib.add_child(MHUIKit.label(MHStrings.t("land.summary", {"owned": land.owned_count(), "total": land.parcel_count(), "holes": land.hole_capacity(), "homes": land.home_slot_capacity()}), &"Label"))
	if price > 0:
		ib.add_child(MHUIKit.label(MHStrings.t("land.next_price", {"price": MHFormat.money(price), "cash": MHFormat.money(view.cash())}), &"MutedLabel"))
	else:
		ib.add_child(MHUIKit.label(MHStrings.t("land.all_owned"), &"GoodLabel"))
	if recommended >= 0:
		ib.add_child(MHUIKit.label(MHStrings.t("land.suggested", {"kind_key": "land.kind." + land.kind_of(recommended)}), &"MutedLabel"))
	_body.add_child(info)

	var g: GridContainer = MHUIKit.grid(cols, 8)
	g.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_body.add_child(g)
	for id: int in range(land.parcel_count()):
		g.add_child(_cell(land, id, buyable, recommended, price))

	_body.add_child(MHUIKit.label(MHStrings.t("land.legend"), &"MutedLabel"))
	if _selected >= 0 and land.check_buy(_selected) == "":
		_body.add_child(_buy_card(land, price))


func _cell(land: MHLandModel, id: int, buyable: PackedInt32Array, _recommended: int, price: int) -> Control:
	var kind: String = land.kind_of(id)
	var owned: bool = land.is_owned(id)
	var can_buy: bool = buyable.has(id)
	var label_text: String = MHStrings.t("land.kind." + kind)
	if owned:
		label_text += "\n" + MHStrings.t("land.owned")
	elif can_buy:
		label_text += "\n" + MHFormat.money_compact(price)
	else:
		label_text += "\n" + MHStrings.t("land.far")
	var variant: StringName = &"ChipButton"
	if owned:
		variant = &"GreenButton"
	elif id == _selected:
		variant = &"PrimaryButton"
	var b: MHTapButton = MHUIKit.button(ctx, label_text, variant, 104.0)
	b.custom_minimum_size = Vector2(104.0, maxf(ctx.touch_min(), 84.0))
	if owned or not can_buy:
		b.disabled = true
	else:
		b.pressed.connect(_on_cell.bind(id))
	return b


func _on_cell(id: int) -> void:
	_selected = id
	refresh()


func _buy_card(land: MHLandModel, price: int) -> Control:
	var card: PanelContainer = MHUIKit.card(8)
	var box: VBoxContainer = MHUIKit.card_box(card)
	box.add_child(MHUIKit.label(MHStrings.t("land.selected", {"kind_key": "land.kind." + land.kind_of(_selected), "price": MHFormat.money(price)}), &"H2Label"))
	var b: MHTapButton = MHUIKit.button(ctx, "", &"PrimaryButton")
	if view.cash() >= price:
		b.text = MHStrings.t("land.buy", {"price": MHFormat.money(price)})
		b.pressed.connect(_on_buy.bind(_selected, price))
	else:
		b.text = MHStrings.t("land.need_cash", {"amount": MHFormat.money(price - view.cash())})
		b.disabled = true
	box.add_child(b)
	return card


func _on_buy(id: int, price: int) -> void:
	send(&"buy_parcel", {"parcel": id, "price": price})
	_selected = -1

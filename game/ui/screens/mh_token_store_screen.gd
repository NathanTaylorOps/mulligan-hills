class_name MHTokenStoreScreen
extends MHScreen
## Token store: PLACEHOLDERS ONLY. It shows the two balances, what tokens do and do not do (DEC-053: time
## speed-ups and bankruptcy recovery only, never cash or progress) and sample packs with disabled buttons.
## There is no purchase code here and no intent that starts a purchase. Real purchases need server-side receipt
## validation, restore and refund handling (platform workstream) before any button here is enabled.


func screen_id() -> String:
	return MHScreenIds.TOKENS


func title_key() -> String:
	return "tokens.title"


func _fill() -> void:
	var bal: PanelContainer = MHUIKit.card(6)
	var bb: VBoxContainer = MHUIKit.card_box(bal)
	_body.add_child(bal)
	bb.add_child(MHUIKit.label(MHStrings.t("tokens.balance", {"total": view.tokens_total()}), &"H2Label"))
	bb.add_child(MHUIKit.label(MHStrings.t("tokens.split", {"earned": view.tokens_earned(), "paid": view.tokens_paid()}), &"MutedLabel"))
	bb.add_child(MHUIKit.label(MHStrings.t("tokens.uses"), &"Label"))
	bb.add_child(MHUIKit.label(MHStrings.t("tokens.never"), &"Label"))
	bb.add_child(MHUIKit.label(MHStrings.t("tokens.earn"), &"MutedLabel"))
	var g: GridContainer = MHUIKit.grid(ctx.columns(3), 12)
	_body.add_child(g)
	for p: Variant in view.store_products():
		var d: Dictionary = p
		var card: PanelContainer = MHUIKit.card(6)
		var box: VBoxContainer = MHUIKit.card_box(card)
		box.add_child(MHUIKit.label(MHStrings.t("tokens.pack", {"count": int(d["tokens"])}), &"H2Label"))
		box.add_child(MHUIKit.label(MHStrings.t("tokens.pack_price", {"price": str(d["price_text"])}), &"MutedLabel"))
		var b: MHTapButton = MHUIKit.button(ctx, MHStrings.t("tokens.unavailable"), &"PrimaryButton")
		b.disabled = true
		box.add_child(b)
		g.add_child(card)
	_body.add_child(MHUIKit.label(MHStrings.t("tokens.placeholder_note"), &"MutedLabel"))

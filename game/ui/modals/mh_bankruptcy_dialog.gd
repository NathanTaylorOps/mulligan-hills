class_name MHBankruptcyDialog
extends MHModalScreen
## Bankruptcy recovery (DEC-024, DEC-053): cash and income cannot cover upkeep. Options: a free bank loan with a
## reputation penalty, a token-paid recovery plan (earned and paid tokens both count), or carry on.
## Intents: recovery_loan, recovery_tokens, recovery_later. The economy decides what each really does.


func screen_id() -> String:
	return MHScreenIds.BANKRUPTCY


func _fill_modal() -> void:
	var offer: Dictionary = view.recovery_offer()
	var tokens: int = view.tokens_total()
	_box.add_child(MHUIKit.label(MHStrings.t("bankrupt.title"), &"H1Label"))
	_box.add_child(MHUIKit.label(MHStrings.t("bankrupt.body", {"shortfall": MHFormat.money(int(offer.get("shortfall", 0)))}), &"Label"))
	for o: Variant in MHRecoveryModel.options(offer, tokens):
		var row: Dictionary = o
		var id: String = str(row["id"])
		if id == MHRecoveryModel.OPT_LOAN:
			var b: MHTapButton = MHUIKit.button(ctx, MHStrings.t("bankrupt.loan", {"amount": MHFormat.money(int(row["amount"]))}), &"GreenButton")
			b.disabled = not bool(row["enabled"])
			b.pressed.connect(send.bind(&"recovery_loan", {}))
			_box.add_child(b)
			_box.add_child(MHUIKit.label(MHStrings.t("bankrupt.loan_note", {"penalty": int(row["penalty"])}), &"MutedLabel"))
		elif id == MHRecoveryModel.OPT_TOKENS:
			var t: MHTapButton = MHUIKit.button(ctx, MHStrings.t("bankrupt.tokens", {"cost": int(row["tokens"])}), &"PrimaryButton")
			t.disabled = not bool(row["enabled"])
			t.pressed.connect(send.bind(&"recovery_tokens", {}))
			_box.add_child(t)
			if not bool(row["enabled"]):
				_box.add_child(MHUIKit.label(MHStrings.t("bankrupt.tokens_short", {"short": MHRecoveryModel.tokens_short(offer, tokens)}), &"MutedLabel"))
			else:
				_box.add_child(MHUIKit.label(MHStrings.t("bankrupt.tokens_note", {"have": tokens}), &"MutedLabel"))
		else:
			var l: MHTapButton = MHUIKit.button(ctx, MHStrings.t("bankrupt.later"), &"GhostButton")
			l.pressed.connect(send.bind(&"recovery_later", {}))
			_box.add_child(l)

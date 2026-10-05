class_name MHConfirmDeleteDialog
extends MHModalScreen
## Account deletion confirmation (store policy, DEC-031). Two buttons: Delete (intent delete_account) and Keep
## (back). The platform account service performs the deletion; this dialog only asks.


func screen_id() -> String:
	return MHScreenIds.CONFIRM_DELETE


func _fill_modal() -> void:
	_box.add_child(MHUIKit.label(MHStrings.t("delete.title"), &"H1Label"))
	_box.add_child(MHUIKit.label(MHStrings.t("delete.body"), &"Label"))
	var del: MHTapButton = MHUIKit.button(ctx, MHStrings.t("delete.confirm"), &"PrimaryButton")
	del.pressed.connect(send.bind(&"delete_account", {}))
	_box.add_child(del)
	var keep: MHTapButton = MHUIKit.button(ctx, MHStrings.t("delete.keep"), &"GreenButton")
	keep.pressed.connect(request_back)
	_box.add_child(keep)

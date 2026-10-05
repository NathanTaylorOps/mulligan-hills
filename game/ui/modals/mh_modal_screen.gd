class_name MHModalScreen
extends MHScreen
## Base for dialogs: a dimmed full-screen layer that swallows touches plus a centred panel. Subclasses fill the
## VBox returned by _modal_box(). The shell restricts taps to the open modal (MHTouchBridge.scope).

var _box: VBoxContainer


func _build() -> void:
	var dim: ColorRect = MHUIKit.color_rect(MHTheme.DIM)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card: PanelContainer = MHUIKit.panel(&"ModalPanel")
	card.custom_minimum_size = Vector2(minf(640.0, maxf(300.0, ctx.viewport_units.x - 64.0)), 0.0)
	center.add_child(card)
	_box = MHUIKit.vbox(12)
	card.add_child(_box)
	_fill_modal()


## Override: add content to _box.
func _fill_modal() -> void:
	pass


func refresh() -> void:
	if _box == null:
		return
	MHUIKit.clear(_box)
	_fill_modal()

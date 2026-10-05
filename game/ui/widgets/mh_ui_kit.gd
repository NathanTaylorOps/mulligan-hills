class_name MHUIKit
extends RefCounted
## Small static builders so screens stay short. Everything is made in code (no scene files, no imported art).
## Visible text must come from MHStrings keys: callers pass MHStrings.t("key", params).


static func label(text_value: String, variant: StringName = &"", wrap: bool = true) -> Label:
	var l: Label = Label.new()
	l.text = text_value
	if variant != &"":
		l.theme_type_variation = variant
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func vbox(sep: int = 10) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


static func hbox(sep: int = 10) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


static func flow(sep: int = 10) -> HFlowContainer:
	var f: HFlowContainer = HFlowContainer.new()
	f.add_theme_constant_override("h_separation", sep)
	f.add_theme_constant_override("v_separation", sep)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f


static func grid(cols: int, sep: int = 10) -> GridContainer:
	var g: GridContainer = GridContainer.new()
	g.columns = maxi(1, cols)
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


static func spacer() -> Control:
	var c: Control = Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## A panel with the theme variation (CardPanel, HudChip, ModalPanel, CoachPanel, ToastPanel).
static func panel(variation: StringName = &"CardPanel") -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.theme_type_variation = variation
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Card holding a VBox; returns the card, the box is card.get_child(0).
static func card(sep: int = 8) -> PanelContainer:
	var p: PanelContainer = panel(&"CardPanel")
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(vbox(sep))
	return p


static func card_box(c: PanelContainer) -> VBoxContainer:
	return c.get_child(0) as VBoxContainer


static func button(ctx: MHUIContext, text_value: String, variant: StringName = &"", min_w: float = 0.0) -> MHTapButton:
	var tm: float = ctx.touch_min()
	return MHTapButton.make(text_value, variant, maxf(min_w, tm), tm)


static func progress(value: int, max_value: int, accent: bool = false) -> ProgressBar:
	var b: ProgressBar = ProgressBar.new()
	b.min_value = 0.0
	b.max_value = float(maxi(1, max_value))
	b.value = float(clampi(value, 0, maxi(1, max_value)))
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0.0, 14.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if accent:
		b.theme_type_variation = &"AccentBar"
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func clear(node: Node) -> void:
	for c: Node in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func color_rect(c: Color) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Plain horizontal rule.
static func rule() -> Control:
	var r: ColorRect = color_rect(MHTheme.LINE)
	r.custom_minimum_size = Vector2(0.0, 2.0)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r

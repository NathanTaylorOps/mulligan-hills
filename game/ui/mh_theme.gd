class_name MHTheme
extends RefCounted
## Colours, sizes, text scaling and the Godot Theme for the whole UI. Palette from Nathan's concept
## screens (warm cream and green). Fonts: the concepts use Baloo 2 (headings) and Nunito (body). No font
## file ships yet; drop the files listed in FONT_PATHS into game/ui/fonts/ and they are picked up
## automatically. Until then the engine default font is used.
##
## Sizes are UI units (project viewport 1280x720, stretch canvas_items). One dp is `units_per_dp` units.

const BG: Color = Color("#FBF7EC")
const CARD: Color = Color("#FFFDF6")
const INK: Color = Color("#17342A")
const MUTED: Color = Color("#5A6F62")
const LINE: Color = Color("#E4DCC6")
const GREEN: Color = Color("#2F6B4F")
const GREEN_DARK: Color = Color("#245640")
const ACCENT: Color = Color("#C8431F")
const ACCENT_DARK: Color = Color("#A63716")
const WARN_TEXT: Color = Color("#8A5A0B")
const DISABLED_BG: Color = Color("#E9E3D0")
const DISABLED_TEXT: Color = Color("#7C8479")
const WHITE: Color = Color("#FFFFFF")
const DIM: Color = Color(0.09, 0.20, 0.16, 0.55)
const HUD_CHIP: Color = Color(0.984, 0.969, 0.925, 0.92)

const TOUCH_MIN_DP: float = 48.0
const TOUCH_MIN_UNITS_FLOOR: float = 48.0
const TEXT_SCALE_MIN: int = 80
const TEXT_SCALE_MAX: int = 160
const TEXT_SCALE_STEP: int = 10

const FONT_BODY: int = 22
const FONT_SMALL: int = 18
const FONT_H2: int = 30
const FONT_H1: int = 40
const FONT_HUD: int = 26

const RADIUS: int = 14
const GUTTER: int = 12

const FONT_PATHS: Dictionary = {
	"body": "res://ui/fonts/Nunito-Regular.ttf",
	"heading": "res://ui/fonts/Baloo2-Bold.ttf",
}


static func clamp_text_scale(pct: int) -> int:
	return clampi(pct, TEXT_SCALE_MIN, TEXT_SCALE_MAX)


## Base font size (UI units) scaled by the accessibility percentage, never below 8.
static func scaled(base_px: int, pct: int) -> int:
	return maxi(8, (base_px * clamp_text_scale(pct) + 50) / 100)


## Next value when stepping the text size up (+1) or down (-1); clamps at the bounds.
static func step_text_scale(pct: int, direction: int) -> int:
	var d: int = 1 if direction >= 0 else -1
	return clamp_text_scale(clamp_text_scale(pct) + d * TEXT_SCALE_STEP)


## Window pixels per UI unit. Uniform (aspect expand). Falls back to 1.0 on bad input.
static func content_scale(window_px: Vector2, viewport_units: Vector2) -> float:
	if window_px.x <= 0.0 or window_px.y <= 0.0 or viewport_units.x <= 0.0 or viewport_units.y <= 0.0:
		return 1.0
	return minf(window_px.x / viewport_units.x, window_px.y / viewport_units.y)


## UI units in one dp. dpi below 120 (desktop reports 96) is treated as 160, which is 1 dp per physical pixel.
static func units_per_dp(dpi: float, content_scale_value: float) -> float:
	var d: float = dpi if dpi >= 120.0 else 160.0
	var cs: float = content_scale_value if content_scale_value > 0.0 else 1.0
	return (d / 160.0) / cs


## Minimum touch target edge in UI units: 48 dp, and never below 48 units so desktop testing still works.
static func touch_min(units_per_dp_value: float) -> float:
	return maxf(TOUCH_MIN_UNITS_FLOOR, TOUCH_MIN_DP * maxf(0.1, units_per_dp_value))


## WCAG contrast ratio of two colours (1..21).
static func contrast_ratio(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	var hi: float = maxf(la, lb)
	var lo: float = minf(la, lb)
	return (hi + 0.05) / (lo + 0.05)


static func _luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


static func _lin(v: float) -> float:
	if v <= 0.03928:
		return v / 12.92
	return pow((v + 0.055) / 1.055, 2.4)


## Optional fonts. Returns {"body": Font or null, "heading": Font or null}. Missing files give null.
static func load_fonts() -> Dictionary:
	var out: Dictionary = {"body": null, "heading": null}
	for key: String in FONT_PATHS.keys():
		var path: String = str(FONT_PATHS[key])
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res is Font:
				out[key] = res
	return out


static func flat(bg: Color, radius: int = RADIUS, border: Color = Color(0, 0, 0, 0), border_w: int = 0, pad_h: int = 16, pad_v: int = 10) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	sb.content_margin_left = float(pad_h)
	sb.content_margin_right = float(pad_h)
	sb.content_margin_top = float(pad_v)
	sb.content_margin_bottom = float(pad_v)
	return sb


static func _button_variant(t: Theme, type_name: String, bg: Color, fg: Color, pressed_bg: Color, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> void:
	if type_name != "Button":
		t.set_type_variation(type_name, "Button")
	t.set_stylebox("normal", type_name, flat(bg, RADIUS, border, border_w))
	t.set_stylebox("hover", type_name, flat(bg, RADIUS, border, border_w))
	t.set_stylebox("pressed", type_name, flat(pressed_bg, RADIUS, border, border_w))
	t.set_stylebox("focus", type_name, flat(Color(0, 0, 0, 0), RADIUS, GREEN, 3))
	t.set_stylebox("disabled", type_name, flat(DISABLED_BG, RADIUS, Color(0, 0, 0, 0), 0))
	t.set_color("font_color", type_name, fg)
	t.set_color("font_hover_color", type_name, fg)
	t.set_color("font_pressed_color", type_name, fg)
	t.set_color("font_focus_color", type_name, fg)
	t.set_color("font_disabled_color", type_name, DISABLED_TEXT)


static func _label_variant(t: Theme, type_name: String, color: Color, size_px: int) -> void:
	t.set_type_variation(type_name, "Label")
	t.set_color("font_color", type_name, color)
	t.set_font_size("font_size", type_name, size_px)


## Builds the full Theme. text_scale_pct 80..160. Fonts may be null (engine default).
static func build(text_scale_pct: int, body_font: Font = null, heading_font: Font = null) -> Theme:
	var pct: int = clamp_text_scale(text_scale_pct)
	var t: Theme = Theme.new()
	t.default_font_size = scaled(FONT_BODY, pct)
	if body_font != null:
		t.default_font = body_font

	t.set_color("font_color", "Label", INK)
	t.set_font_size("font_size", "Label", scaled(FONT_BODY, pct))
	_label_variant(t, "H1Label", INK, scaled(FONT_H1, pct))
	_label_variant(t, "H2Label", INK, scaled(FONT_H2, pct))
	_label_variant(t, "SmallLabel", INK, scaled(FONT_SMALL, pct))
	_label_variant(t, "MutedLabel", MUTED, scaled(FONT_SMALL, pct))
	_label_variant(t, "HudLabel", INK, scaled(FONT_HUD, pct))
	_label_variant(t, "AccentLabel", ACCENT, scaled(FONT_BODY, pct))
	_label_variant(t, "GoodLabel", GREEN, scaled(FONT_BODY, pct))
	_label_variant(t, "WarnLabel", WARN_TEXT, scaled(FONT_BODY, pct))
	_label_variant(t, "BigNumberLabel", GREEN, scaled(72, pct))
	if heading_font != null:
		for v: String in ["H1Label", "H2Label", "HudLabel", "BigNumberLabel"]:
			t.set_font("font", v, heading_font)

	t.set_font_size("font_size", "Button", scaled(FONT_BODY, pct))
	_button_variant(t, "Button", CARD, INK, LINE, LINE, 2)
	_button_variant(t, "PrimaryButton", ACCENT, WHITE, ACCENT_DARK)
	_button_variant(t, "GreenButton", GREEN, WHITE, GREEN_DARK)
	_button_variant(t, "SelectedButton", GREEN, WHITE, GREEN_DARK)
	_button_variant(t, "GhostButton", Color(0, 0, 0, 0), GREEN, LINE)
	_button_variant(t, "ChipButton", HUD_CHIP, INK, LINE, LINE, 2)
	for v: String in ["PrimaryButton", "GreenButton", "SelectedButton", "GhostButton", "ChipButton"]:
		t.set_font_size("font_size", v, scaled(FONT_BODY, pct))

	t.set_stylebox("panel", "PanelContainer", flat(CARD, RADIUS, LINE, 2, 16, 14))
	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", flat(CARD, RADIUS, LINE, 2, 16, 14))
	t.set_type_variation("HudChip", "PanelContainer")
	t.set_stylebox("panel", "HudChip", flat(HUD_CHIP, 12, LINE, 2, 12, 6))
	t.set_type_variation("ModalPanel", "PanelContainer")
	t.set_stylebox("panel", "ModalPanel", flat(BG, 20, GREEN, 3, 24, 20))
	t.set_type_variation("ToastPanel", "PanelContainer")
	t.set_stylebox("panel", "ToastPanel", flat(INK, 12, Color(0, 0, 0, 0), 0, 18, 10))
	t.set_type_variation("CoachPanel", "PanelContainer")
	t.set_stylebox("panel", "CoachPanel", flat(HUD_CHIP, 16, ACCENT, 3, 18, 12))

	t.set_stylebox("background", "ProgressBar", flat(DISABLED_BG, 8, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("fill", "ProgressBar", flat(GREEN, 8, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_type_variation("AccentBar", "ProgressBar")
	t.set_stylebox("background", "AccentBar", flat(DISABLED_BG, 8, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("fill", "AccentBar", flat(ACCENT, 8, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	return t

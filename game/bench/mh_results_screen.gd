class_name MHResultsScreen
extends CanvasLayer
## Full-screen results page. Shows the summary as pretty JSON in large text so it can be photographed.

const FONT_SIZE: int = 30
const SHOW_KEYS: Array = [
	"verdict", "tier", "renderer_active", "mode", "duration_s", "frames", "avg_fps", "p50_ms",
	"p95_ms", "p99_ms", "min_fps", "pct_over_33ms", "draw_calls_avg", "draw_calls_max",
	"primitives_avg", "static_mem_max_mb", "video_mem_max_mb", "render_scale", "throttle_ratio",
	"battery_start_pct", "battery_pct", "device", "gpu", "thermal",
]

var _label: Label
var _json_text: String = ""


func _init() -> void:
	layer = 100
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 24.0
	box.offset_top = 24.0
	box.offset_right = -24.0
	box.offset_bottom = -24.0
	add_child(box)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_label)
	var row: HBoxContainer = HBoxContainer.new()
	box.add_child(row)
	var copy_btn: Button = Button.new()
	copy_btn.text = "Copy JSON"
	copy_btn.custom_minimum_size = Vector2(260.0, 90.0)
	copy_btn.add_theme_font_size_override("font_size", FONT_SIZE)
	copy_btn.pressed.connect(_on_copy)
	row.add_child(copy_btn)
	var close_btn: Button = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(260.0, 90.0)
	close_btn.add_theme_font_size_override("font_size", FONT_SIZE)
	close_btn.pressed.connect(_on_close)
	row.add_child(close_btn)
	visible = false


static func build_text(summary: Dictionary) -> String:
	var compact: Dictionary = {}
	for k in SHOW_KEYS:
		if summary.has(k):
			compact[k] = summary[k]
	return JSON.stringify(compact, "  ")


func show_summary(summary: Dictionary) -> void:
	_json_text = JSON.stringify(summary, "  ")
	_label.text = build_text(summary)
	visible = true


func _on_copy() -> void:
	DisplayServer.clipboard_set(_json_text)


func _on_close() -> void:
	visible = false

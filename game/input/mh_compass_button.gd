class_name MHCompassButton
extends Control
## Compass drawn top-right. The red needle points to north on screen. Taps are
## detected by MHInputRouter via get_global_rect(), not by this Control.

var _yaw: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120.0, 120.0)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)


func set_yaw(yaw: float) -> void:
	if is_equal_approx(_yaw, yaw):
		return
	_yaw = yaw
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 4.0
	draw_circle(c, r, Color(0, 0, 0, 0.5))
	draw_arc(c, r, 0.0, TAU, 32, Color.WHITE, 3.0)
	# Camera yawed clockwise-positive: north appears rotated by +yaw on screen.
	var dir: Vector2 = Vector2(sin(_yaw), -cos(_yaw))
	draw_line(c - dir * r * 0.6, c, Color.WHITE, 6.0)
	draw_line(c, c + dir * r * 0.8, Color(0.9, 0.15, 0.15), 6.0)
	draw_string(ThemeDB.fallback_font, c + dir * r * 0.55 - Vector2(8.0, -8.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)

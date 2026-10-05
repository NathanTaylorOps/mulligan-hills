class_name MHUIContext
extends RefCounted
## What every screen needs to size itself: settings, dp conversion, layout class, safe-area insets.
## recompute() is pure given its inputs, so it is testable without a window.

var settings: MHUISettings = MHUISettings.new()
var units_per_dp: float = 1.0
var layout_kind: int = MHLayout.Kind.PHONE_LANDSCAPE
var safe_insets: Vector4 = MHSafeArea.zero()
var viewport_units: Vector2 = Vector2(1280.0, 720.0)


func recompute(window_px: Vector2, viewport_size_units: Vector2, dpi: float, safe_rect_px: Rect2) -> void:
	viewport_units = viewport_size_units
	var cs: float = MHTheme.content_scale(window_px, viewport_size_units)
	units_per_dp = MHTheme.units_per_dp(dpi, cs)
	layout_kind = MHLayout.classify(viewport_size_units, units_per_dp)
	safe_insets = MHSafeArea.insets(window_px, safe_rect_px, viewport_size_units)


## Smallest touch target edge in UI units.
func touch_min() -> float:
	return MHTheme.touch_min(units_per_dp)


func text_scale() -> int:
	return MHTheme.clamp_text_scale(settings.text_scale_pct)


func scaled(base_px: int) -> int:
	return MHTheme.scaled(base_px, settings.text_scale_pct)


func metric() -> bool:
	return settings.is_metric()


func columns(max_cols: int = 3) -> int:
	return MHLayout.columns(layout_kind, max_cols)


func is_portrait() -> bool:
	return layout_kind == MHLayout.Kind.PHONE_PORTRAIT


func left_handed() -> bool:
	return settings.left_handed

class_name MHSafeArea
extends RefCounted
## Pure safe-area (notch, rounded corners, gesture bar) math.
## Insets are returned as Vector4(left, top, right, bottom) in UI (viewport) units.
## DisplayServer.get_display_safe_area() reports a Rect2i in screen pixels; the UI lives in viewport
## units (stretch mode canvas_items), so insets are scaled by viewport_size / screen_size.

## No inset may exceed this fraction of the viewport dimension (guards against bogus values).
const MAX_FRACTION: float = 0.30


static func zero() -> Vector4:
	return Vector4(0.0, 0.0, 0.0, 0.0)


static func is_zero(v: Vector4) -> bool:
	return v.x <= 0.0 and v.y <= 0.0 and v.z <= 0.0 and v.w <= 0.0


## screen_size: physical pixels of the display. safe_rect: safe area in the same pixels.
## viewport_size: UI units. An empty or covering safe rect, or a zero size, gives zero insets.
static func insets(screen_size: Vector2, safe_rect: Rect2, viewport_size: Vector2) -> Vector4:
	if screen_size.x <= 0.0 or screen_size.y <= 0.0 or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return zero()
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return zero()
	var sx: float = viewport_size.x / screen_size.x
	var sy: float = viewport_size.y / screen_size.y
	var left: float = maxf(0.0, safe_rect.position.x) * sx
	var top: float = maxf(0.0, safe_rect.position.y) * sy
	var right: float = maxf(0.0, screen_size.x - (safe_rect.position.x + safe_rect.size.x)) * sx
	var bottom: float = maxf(0.0, screen_size.y - (safe_rect.position.y + safe_rect.size.y)) * sy
	var max_x: float = viewport_size.x * MAX_FRACTION
	var max_y: float = viewport_size.y * MAX_FRACTION
	return Vector4(minf(left, max_x), minf(top, max_y), minf(right, max_x), minf(bottom, max_y))


## Adds a uniform breathing gutter (UI units) on every side.
static func with_gutter(v: Vector4, gutter: float) -> Vector4:
	var g: float = maxf(0.0, gutter)
	return Vector4(v.x + g, v.y + g, v.z + g, v.w + g)


## Swaps left and right (left-handed layouts mirror the whole screen frame only when asked).
static func mirrored(v: Vector4) -> Vector4:
	return Vector4(v.z, v.y, v.x, v.w)


## The rect left for content after removing insets from a viewport of the given size.
static func content_rect(viewport_size: Vector2, v: Vector4) -> Rect2:
	var w: float = maxf(0.0, viewport_size.x - v.x - v.z)
	var h: float = maxf(0.0, viewport_size.y - v.y - v.w)
	return Rect2(v.x, v.y, w, h)

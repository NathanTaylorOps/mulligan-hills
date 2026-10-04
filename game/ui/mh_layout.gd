class_name MHLayout
extends RefCounted
## Pure layout classification: phone portrait, phone landscape, tablet.

enum Kind { PHONE_PORTRAIT = 0, PHONE_LANDSCAPE = 1, TABLET = 2 }

## Android's own convention: shortest side of at least 600 dp is a tablet.
const TABLET_MIN_DP: float = 600.0


## viewport: UI units. units_per_dp: UI units in one dp (see MHTheme.units_per_dp).
static func classify(viewport: Vector2, units_per_dp: float) -> int:
	var upd: float = units_per_dp if units_per_dp > 0.0 else 1.0
	var short_dp: float = minf(viewport.x, viewport.y) / upd
	if short_dp >= TABLET_MIN_DP:
		return Kind.TABLET
	if viewport.x >= viewport.y:
		return Kind.PHONE_LANDSCAPE
	return Kind.PHONE_PORTRAIT


## Card grids: columns for a layout kind (never below 1, never above max_cols).
static func columns(kind: int, max_cols: int = 3) -> int:
	var c: int = 1
	if kind == Kind.TABLET:
		c = 3
	elif kind == Kind.PHONE_LANDSCAPE:
		c = 2
	return clampi(c, 1, maxi(1, max_cols))


static func kind_name(kind: int) -> String:
	if kind == Kind.TABLET:
		return "tablet"
	if kind == Kind.PHONE_LANDSCAPE:
		return "phone_landscape"
	return "phone_portrait"

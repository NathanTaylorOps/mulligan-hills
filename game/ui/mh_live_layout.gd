class_name MHLiveLayout
extends RefCounted
## Pure zone maths for the live construction scene (no nodes, no engine state, testable without a window).
##
## The HUD (or editor toolbar) owns the top band and the bottom nav bar and reports the rectangle left between
## them (`MHUIShell.overlay_free_rect()`). Everything the live scene adds lives INSIDE that free rectangle, split
## into three zones that never intersect:
##   actions  Save / Save & launcher / Build-play buttons (wrapping flow, touch_min high rows)
##   status   short status line (fixed height, `STATUS_LINES` lines, clipped, never zero width)
##   panel    one-hole practice panel: HIDDEN, COLLAPSED (header only) or OPEN
## Landscape (free rect wider than tall): the panel is a side column (right, or left when `mirror`), actions and
## status stack in the remaining column. Portrait: actions, then status, stacked at the top; the panel is a bottom
## sheet that always leaves `WORLD_MIN_FRACTION` of the free height to the 3D view when it can.
## All sizes are UI units (project viewport units), like MHTheme.

enum PanelState { HIDDEN = 0, COLLAPSED = 1, OPEN = 2 }

const GAP: float = 8.0
## Content margins of the panel frame (MHTheme CardPanel: 16 horizontal, 14 vertical).
const PANEL_PAD_H: float = 16.0
const PANEL_PAD_V: float = 14.0
## Content margins of the status chip (MHTheme HudChip: 12 horizontal, 6 vertical).
const STATUS_PAD_V: float = 6.0
const STATUS_LINES: int = 2
const PANEL_SIDE_FRACTION: float = 0.40
const PANEL_SIDE_MIN: float = 320.0
const PANEL_SIDE_MAX: float = 560.0
## The side column never takes more than this fraction of the free width.
const PANEL_SIDE_CAP_FRACTION: float = 0.5
const PANEL_SHEET_FRACTION: float = 0.5
const WORLD_MIN_FRACTION: float = 0.25


static func is_landscape(free: Rect2) -> bool:
	return free.size.x >= free.size.y


## Rows a wrapping flow needs for children of the given min widths in `avail` width (0 children, 0 rows).
static func flow_rows(widths: Array, sep: float, avail: float) -> int:
	if widths.is_empty():
		return 0
	var rows: int = 1
	var used: float = 0.0
	var first: bool = true
	for w: Variant in widths:
		var wf: float = maxf(0.0, float(w))
		if first:
			used = wf
			first = false
		elif used + sep + wf > avail:
			rows += 1
			used = wf
		else:
			used += sep + wf
	return rows


static func flow_height(rows: int, row_h: float, sep: float) -> float:
	if rows <= 0:
		return 0.0
	return float(rows) * row_h + float(rows - 1) * sep


## Collapsed panel height: one touch target plus the frame padding.
static func panel_header_height(touch_min: float) -> float:
	return maxf(1.0, touch_min) + 2.0 * PANEL_PAD_V


static func status_height(line_h: float) -> float:
	return float(STATUS_LINES) * maxf(1.0, line_h) + 2.0 * STATUS_PAD_V


## Zone rectangles inside `free`. Keys: "actions", "status", "panel" (Rect2, empty size when the zone is not shown),
## "landscape" (bool), "fits" (false when the free rect is too small to show everything; zones still never overlap).
## touch_min: MHUIContext.touch_min(). line_h: height of one status text line. action_widths: min width of each
## action button. mirror: left-handed (panel column on the left).
static func compute(free: Rect2, touch_min: float, line_h: float, panel_state: int, action_widths: Array, mirror: bool = false) -> Dictionary:
	var out: Dictionary = {"actions": Rect2(), "status": Rect2(), "panel": Rect2(), "landscape": is_landscape(free), "fits": true}
	if free.size.x <= 0.0 or free.size.y <= 0.0:
		out["fits"] = false
		return out
	var tm: float = maxf(1.0, touch_min)
	var land: bool = is_landscape(free)
	var header_h: float = panel_header_height(tm)
	var has_panel: bool = panel_state != PanelState.HIDDEN
	var col_x: float = free.position.x
	var col_w: float = free.size.x
	var panel: Rect2 = Rect2()
	if has_panel and land:
		var pw: float = clampf(free.size.x * PANEL_SIDE_FRACTION, PANEL_SIDE_MIN, PANEL_SIDE_MAX)
		pw = minf(pw, free.size.x * PANEL_SIDE_CAP_FRACTION)
		var ph: float = free.size.y if panel_state == PanelState.OPEN else minf(header_h, free.size.y)
		var px: float = free.position.x if mirror else free.end.x - pw
		panel = Rect2(px, free.position.y, pw, ph)
		col_w = free.size.x - pw - GAP
		if mirror:
			col_x = free.position.x + pw + GAP
		if ph < header_h:
			out["fits"] = false
	# Actions: wrapping row(s) at the top of the column.
	var rows: int = flow_rows(action_widths, GAP, col_w)
	var actions_h: float = minf(flow_height(rows, tm, GAP), free.size.y)
	if actions_h < flow_height(rows, tm, GAP):
		out["fits"] = false
	if rows > 0:
		out["actions"] = Rect2(col_x, free.position.y, col_w, actions_h)
	# Status: directly under the actions, fixed height, clipped to what is left.
	var status_y: float = free.position.y + (actions_h + GAP if rows > 0 else 0.0)
	var status_h: float = status_height(line_h)
	var left: float = free.end.y - status_y
	if left < status_h:
		out["fits"] = false
		status_h = left if left >= maxf(1.0, line_h) else 0.0
	if status_h > 0.0:
		out["status"] = Rect2(col_x, status_y, col_w, status_h)
	# Portrait: bottom sheet under the status zone.
	if has_panel and not land:
		var top_end: float = status_y + (status_h + GAP if status_h > 0.0 else 0.0)
		var remaining: float = free.end.y - top_end
		var ph2: float = header_h
		if panel_state == PanelState.OPEN:
			var max_open: float = maxf(header_h, remaining - free.size.y * WORLD_MIN_FRACTION)
			ph2 = clampf(free.size.y * PANEL_SHEET_FRACTION, header_h, max_open)
		if ph2 > remaining:
			ph2 = maxf(0.0, remaining)
			out["fits"] = false
		if ph2 > 0.0:
			panel = Rect2(free.position.x, free.end.y - ph2, free.size.x, ph2)
	out["panel"] = panel
	return out


## True when the two rectangles share interior area (touching edges do not count).
static func overlaps(a: Rect2, b: Rect2) -> bool:
	if a.size.x <= 0.0 or a.size.y <= 0.0 or b.size.x <= 0.0 or b.size.y <= 0.0:
		return false
	return a.intersects(b, false)

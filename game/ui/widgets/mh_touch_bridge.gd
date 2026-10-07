class_name MHTouchBridge
extends Node
## Turns raw touches into taps on MHTapButton (the same approach as MHGate0Panel, shared by every screen),
## and into drag scrolling for MHScrollBox. One bridge per MHUIShell.
## A tap = press and release on the same button without moving more than TAP_SLOP units.
## `scope`: when set (a modal is open), only buttons inside that node can be tapped.

const TAP_SLOP: float = 18.0

var scope: Control = null
## True: this bridge scrolls MHScrollBox on touch drags. Set false if the engine scrolls them itself.
var manual_scroll: bool = true

var _down: Dictionary = {}


## Pure. Index of the LAST rect containing pos (later siblings draw on top), or -1.
static func pick(rects: Array, pos: Vector2) -> int:
	var found: int = -1
	for i: int in range(rects.size()):
		var r: Rect2 = rects[i]
		if r.has_point(pos):
			found = i
	return found


## Pure. True while a touch that began at `start` is still a tap at `pos`.
static func within_slop(start: Vector2, pos: Vector2) -> bool:
	return start.distance_to(pos) <= TAP_SLOP


## Pure. The part of `rect` that is inside every clip rect; an empty Rect2 when nothing is left.
static func clipped(rect: Rect2, clips: Array) -> Rect2:
	var r: Rect2 = rect
	for c: Variant in clips:
		var cr: Rect2 = c
		r = r.intersection(cr)
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			return Rect2()
	return r


## A button's tappable rectangle: its global rect minus whatever a scroll container above it clips away, so a
## button scrolled out of view can never swallow a tap meant for the control drawn there.
static func visible_rect(b: Control) -> Rect2:
	var clips: Array = []
	var p: Node = b.get_parent()
	while p != null:
		var sc: ScrollContainer = p as ScrollContainer
		if sc != null:
			clips.append(sc.get_global_rect())
		p = p.get_parent()
	return clipped(b.get_global_rect(), clips)


func _candidates() -> Array:
	var out: Array = []
	for n: Node in get_tree().get_nodes_in_group(MHTapButton.GROUP):
		var b: Button = n as Button
		if b == null or not is_instance_valid(b) or b.disabled or not b.is_visible_in_tree():
			continue
		if scope != null and scope != b and not scope.is_ancestor_of(b):
			continue
		out.append(b)
	return out


func _button_at(pos: Vector2) -> Button:
	var cands: Array = _candidates()
	var rects: Array = []
	for c: Variant in cands:
		var b: Button = c
		rects.append(visible_rect(b))
	var i: int = pick(rects, pos)
	if i < 0:
		return null
	return cands[i] as Button


func _scroll_at(pos: Vector2) -> ScrollContainer:
	var found: ScrollContainer = null
	for n: Node in get_tree().get_nodes_in_group(MHScrollBox.GROUP):
		var s: ScrollContainer = n as ScrollContainer
		if s == null or not s.is_visible_in_tree():
			continue
		if scope != null and scope != s and not scope.is_ancestor_of(s):
			continue
		if s.get_global_rect().has_point(pos):
			found = s
	return found


static func _live_button(v: Variant) -> Button:
	if v == null or not is_instance_valid(v):
		return null
	return v as Button


static func _live_scroll(v: Variant) -> ScrollContainer:
	if v == null or not is_instance_valid(v):
		return null
	return v as ScrollContainer


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			var b: Button = _button_at(t.position)
			var sc: ScrollContainer = _scroll_at(t.position)
			_down[t.index] = {"button": b, "start": t.position, "moved": false, "scroll": sc}
			if b != null:
				b.modulate = Color(0.86, 0.86, 0.86, 1.0)
				get_viewport().set_input_as_handled()
		elif _down.has(t.index):
			var d: Dictionary = _down[t.index]
			_down.erase(t.index)
			var btn: Button = _live_button(d["button"])
			if btn != null and is_instance_valid(btn):
				btn.modulate = Color(1, 1, 1, 1)
				var still_tap: bool = not bool(d["moved"]) and not t.canceled
				if still_tap and visible_rect(btn).has_point(t.position) and not btn.disabled:
					btn.pressed.emit()
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var g: InputEventScreenDrag = event
		if not _down.has(g.index):
			return
		var d2: Dictionary = _down[g.index]
		var start: Vector2 = d2["start"]
		if not bool(d2["moved"]) and not within_slop(start, g.position):
			d2["moved"] = true
			var b2: Button = _live_button(d2["button"])
			if b2 != null and is_instance_valid(b2):
				b2.modulate = Color(1, 1, 1, 1)
		if bool(d2["moved"]) and manual_scroll:
			var sc2: ScrollContainer = _live_scroll(d2["scroll"])
			if sc2 != null and is_instance_valid(sc2):
				sc2.scroll_vertical = sc2.scroll_vertical - int(g.relative.y)
				sc2.scroll_horizontal = sc2.scroll_horizontal - int(g.relative.x)


func _clear_contacts() -> void:
	for value: Variant in _down.values():
		var row: Dictionary = value as Dictionary
		var b: Button = _live_button(row.get("button", null))
		if b != null:
			b.modulate = Color(1, 1, 1, 1)
	_down.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_clear_contacts()

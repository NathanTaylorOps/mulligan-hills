class_name MHSliceBar
extends RefCounted
## The slice's bottom mode bar (pattern from docs/phase1/simgolf_reference.md): one bar, a few tabs, each tab shows its own
## row of buttons, and a hole readout (label and shot analysis) sits beside it. Pure data and text, no nodes.
## NOT YET RUN in Godot.

## [tab id, tab title, [button ids]]. Button ids are wired in MHVerticalSlice.
const TABS: Array = [
	["course", "Course", ["build_hole", "buy_land", "buildings"]],
	["club", "Club", ["pause", "speed", "fee_down", "fee_up"]],
	["view", "View", ["zoom_in", "zoom_out", "turn_left", "turn_right"]],
	["more", "More", ["quality", "back"]],
]

## Upper distance limit in yards and the club used up to it.
const CLUBS: Array = [
	[10, "Putter"], [30, "Lob wedge"], [60, "Sand wedge"], [100, "Pitching wedge"], [130, "9 iron"],
	[150, "7 iron"], [170, "5 iron"], [200, "3 iron"], [240, "Fairway wood"], [100000, "Driver"],
]


static func tab_ids() -> Array:
	var out: Array = []
	for t: Variant in TABS:
		out.append(str((t as Array)[0]))
	return out


static func buttons_for(tab_id: String) -> Array:
	for t: Variant in TABS:
		if str((t as Array)[0]) == tab_id:
			return ((t as Array)[2] as Array).duplicate()
	return []


static func par_for_yards(yards: int) -> int:
	if yards <= 260:
		return 3
	if yards <= 470:
		return 4
	return 5


static func club_for_yards(yards: int) -> String:
	for c: Variant in CLUBS:
		if yards <= int((c as Array)[0]):
			return str((c as Array)[1])
	return "Driver"


## "Hole 2  66 yd  Par 3" for a hole slot (zero based) with its length in yards.
static func hole_label(slot: int, yards: int) -> String:
	return "Hole %d  %d yd  Par %d" % [slot + 1, yards, par_for_yards(yards)]


## Suggested arc: high when the hole has water or trees to clear, else normal.
static func arc_for(has_water: bool, has_trees: bool) -> String:
	return "High" if (has_water or has_trees) else "Normal"


## Two lines for the readout: the hole label and the tee shot analysis.
static func readout(slot: int, yards: int, has_water: bool, has_trees: bool) -> String:
	return "%s\nTee shot: %s, %d yd, lie: tee\nSuggested arc: %s" % [hole_label(slot, yards), club_for_yards(yards),
		yards, arc_for(has_water, has_trees)]

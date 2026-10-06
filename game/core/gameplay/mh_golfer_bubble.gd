class_name MHGolferBubble
extends RefCounted
## Short presentation text derived from persistent identity + actual round outcome.

static func after_round(golfer: Dictionary, customer: Dictionary) -> String:
	var sat: int = int(customer.get("satisfaction", 50))
	var name: String = str(golfer.get("name", "Golfer"))
	var facility: String = str(golfer.get("favorite_facility", "clubhouse")).replace("_", " ")
	var visits: int = int(golfer.get("visits", 0))
	if bool(golfer.get("member", false)):
		return "%s: I'm joining. This place feels like my club now." % name
	if sat >= 85:
		return "%s: Loved that. %s next, then I'm coming back." % [name, facility.capitalize()]
	if sat <= 35:
		return "%s: That hole got under my skin. I need a better reason to return." % name
	if visits > 1:
		return "%s: I remember this place. Still a good challenge." % name
	return "%s: Not bad. I'd give that another round." % name


static func memory_summary(golfer: Dictionary) -> String:
	var memories: Array = golfer.get("memories", []) as Array
	if memories.is_empty():
		return "No memorable rounds yet."
	var last: Dictionary = memories.back() as Dictionary
	return "Last memory: day %d, hole %d, %d/100 — %s" % [int(last["day"]), int(last["hole_slot"]) + 1,
		int(last["satisfaction"]), str(last["text"])]

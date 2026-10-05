class_name MHStreak
extends RefCounted
## Daily activity streak with grace days and a soft resume (res://data/progression.json "streak"). No punishing
## mechanic: a broken streak resumes at a reduced value, never at zero. Pure logic, no clock: the caller passes
## the UTC day number of each "active" day (recommended: the first daily-challenge attempt of the day).
##
## Rules (the data gives the numbers, the interpretation is documented in docs/phase1/progression.md):
##  - Same day again: nothing changes.
##  - Next day (no missed day): streak + 1.
##  - Gap of 1..max_bridge_days missed days AND a grace available: one grace is spent, the streak continues + 1.
##  - Any other gap (too long, or no grace): the streak resumes at floor(streak x resume_percent / 100) + 1.
##  - A grace is regained when the streak reaches a multiple of grace_regain_every_days on an extending day, up to
##    grace_max. The player starts with grace_start.
##  - Each milestone (days -> points) pays once per save, even if the streak later falls and climbs again.
##  - A day earlier than the last active day (clock set back) is ignored.
@warning_ignore_start("integer_division")

const SAVE_VERSION: int = 1

var current: int = 0
var best: int = 0
var grace: int = 1
var active_days: int = 0
var last_day: int = -1

var grace_start: int = 1
var grace_max: int = 2
var regain_every_days: int = 7
var max_bridge_days: int = 2
var resume_percent: int = 50
## Array of {"days", "points"} ascending by days
var milestones: Array = []

var _claimed: Array = []


## Applies the "streak" block of progression.json (already normalized to ints). Returns false when malformed.
func configure(streak_data: Dictionary) -> bool:
	for k: String in ["grace_start", "grace_max", "grace_regain_every_days", "max_bridge_days", "resume_percent"]:
		if not MHDataJson.is_int_in(streak_data.get(k, null), 0, 365):
			return false
	if int(streak_data["grace_regain_every_days"]) < 1 or int(streak_data["resume_percent"]) > 100:
		return false
	var ms: Variant = streak_data.get("milestones", null)
	if typeof(ms) != TYPE_ARRAY:
		return false
	var list: Array = []
	var prev: int = 0
	for m: Variant in (ms as Array):
		if typeof(m) != TYPE_DICTIONARY:
			return false
		var md: Dictionary = m
		if not MHDataJson.is_int_in(md.get("days", null), 1, 10000) or not MHDataJson.is_int_in(md.get("points", null), 0, 100000):
			return false
		if int(md["days"]) <= prev:
			return false
		prev = int(md["days"])
		list.append({"days": int(md["days"]), "points": int(md["points"])})
	grace_start = int(streak_data["grace_start"])
	grace_max = int(streak_data["grace_max"])
	regain_every_days = int(streak_data["grace_regain_every_days"])
	max_bridge_days = int(streak_data["max_bridge_days"])
	resume_percent = int(streak_data["resume_percent"])
	milestones = list
	grace = mini(grace, grace_max) if last_day >= 0 else mini(grace_start, grace_max)
	return true


func claimed_milestones() -> Array:
	return _claimed.duplicate()


## Total points of all milestones claimed so far.
func milestone_points_total() -> int:
	var sum: int = 0
	for m: Variant in milestones:
		var md: Dictionary = m
		if _claimed.has(int(md["days"])):
			sum += int(md["points"])
	return sum


## Registers an active day. Returns {"changed", "streak", "used_grace", "resumed", "milestone_points",
## "milestone_days" (Array of int newly claimed)}.
func record_active(day: int) -> Dictionary:
	var out: Dictionary = {"changed": false, "streak": current, "used_grace": false, "resumed": false, "milestone_points": 0, "milestone_days": []}
	if day < 0 or day <= last_day:
		return out
	var used_grace: bool = false
	var resumed: bool = false
	var extended: bool = true
	if last_day < 0:
		current = 1
	else:
		var missed: int = day - last_day - 1
		if missed == 0:
			current += 1
		elif missed <= max_bridge_days and grace > 0:
			grace -= 1
			current += 1
			used_grace = true
		else:
			current = current * resume_percent / 100 + 1
			resumed = true
			extended = false
	last_day = day
	active_days += 1
	if extended and current % regain_every_days == 0 and grace < grace_max:
		grace += 1
	best = maxi(best, current)
	var claimed_now: Array = []
	var pts: int = 0
	for m: Variant in milestones:
		var md: Dictionary = m
		var d: int = int(md["days"])
		if current >= d and not _claimed.has(d):
			_claimed.append(d)
			claimed_now.append(d)
			pts += int(md["points"])
	out["changed"] = true
	out["streak"] = current
	out["used_grace"] = used_grace
	out["resumed"] = resumed
	out["milestone_points"] = pts
	out["milestone_days"] = claimed_now
	return out


## The streak the player sees on a given day: the current value while it is still alive (last active day is today
## or yesterday, or a grace and bridge could still cover the gap), otherwise the value it would resume at.
func display_streak(day: int) -> int:
	if last_day < 0:
		return 0
	var missed: int = day - last_day - 1
	if missed <= 0:
		return current
	if missed <= max_bridge_days and grace > 0:
		return current
	return current * resume_percent / 100


func to_dict() -> Dictionary:
	return {
		"v": SAVE_VERSION,
		"current": current,
		"best": best,
		"grace": grace,
		"active_days": active_days,
		"last_day": last_day,
		"claimed": _claimed.duplicate(),
	}


## The block for save.schema.json progress.streak: to_dict() without the version tag.
func to_save_block() -> Dictionary:
	var out: Dictionary = to_dict()
	out.erase("v")
	return out


## Loads a progress.streak block. Returns false and changes nothing when malformed.
func from_save_block(block: Dictionary) -> bool:
	var d: Dictionary = block.duplicate(true)
	d["v"] = SAVE_VERSION
	return from_dict(d)


## Returns false and changes nothing when malformed.
func from_dict(d: Dictionary) -> bool:
	var errs: Array = []
	var norm: Variant = MHDataJson.normalize(d, errs, "$")
	if not errs.is_empty() or typeof(norm) != TYPE_DICTIONARY:
		return false
	var n: Dictionary = norm
	if int(n.get("v", 0)) != SAVE_VERSION:
		return false
	for k: String in ["current", "best", "grace", "active_days"]:
		if not MHDataJson.is_int_in(n.get(k, null), 0, 1000000):
			return false
	if not MHDataJson.is_int_in(n.get("last_day", null), -1, 1000000):
		return false
	var cl: Variant = n.get("claimed", null)
	if typeof(cl) != TYPE_ARRAY or (cl as Array).size() > 64:
		return false
	var claimed: Array = []
	for c: Variant in (cl as Array):
		if not MHDataJson.is_int_in(c, 1, 10000):
			return false
		claimed.append(int(c))
	current = int(n["current"])
	best = maxi(int(n["best"]), current)
	grace = mini(int(n["grace"]), grace_max)
	active_days = int(n["active_days"])
	last_day = int(n["last_day"])
	_claimed = claimed
	return true

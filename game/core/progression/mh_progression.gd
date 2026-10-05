class_name MHProgression
extends RefCounted
## Club level, club prestige points and achievements (res://data/progression.json + MHAchievements). Pure logic.
##
## Club prestige points are computed, never stored, from monotone stats, so they only ever go up:
##   holes       = per_hole x holes_max
##   tiers       = per_building_tier_step x tier_sum
##   course      = per_course_score_point x best_course_score
##   members     = min(members_max / members_div, members_cap)
##   challenges  = challenge_completed x challenges_completed + challenge_attempted x (attempted - completed)
##   commissions = commission_done_base x commissions_done
##   achievements= sum of points of unlocked achievements
##   streak      = sum of claimed streak milestone points
##   bonus       = bonus_prestige stat (tournament prestige awards, event card add_prestige effects)
## Level = highest row of the levels table whose prestige_needed is at most the points. Levels list unlock ids
## (cosmetics and features); this class only reports them.
## refresh() is the one call that moves things forward: it raises the level stat, unlocks achievements and
## repeats until stable (an achievement can lift the level, a level can satisfy "level" achievements).
@warning_ignore_start("integer_division")

const DEFAULT_PATH: String = "res://data/progression.json"
const SAVE_VERSION: int = 1
const MAX_REFRESH_PASSES: int = 12

var load_error: String = ""
var stats: MHProgressStats = MHProgressStats.new()
var streak: MHStreak = MHStreak.new()
var achievements: MHAchievements = MHAchievements.new()

var _levels: Array = []
var _ms: Dictionary = {}
var _unlocked: Array = []
var _loaded: bool = false


func is_loaded() -> bool:
	return _loaded


## Loads progression.json and achievements.json from res://data.
func load_defaults() -> bool:
	return load_files(DEFAULT_PATH, MHAchievements.DEFAULT_PATH)


func load_files(progression_path: String, achievements_path: String) -> bool:
	var r: Dictionary = MHDataJson.load_file(progression_path)
	if not bool(r["ok"]):
		return _fail(str(r["error"]))
	if not achievements.load_from_file(achievements_path):
		return _fail("achievements: " + achievements.load_error)
	return load_from_dict(r["value"] as Dictionary)


## d is the normalized progression.json content; `achievements` must already be loaded.
func load_from_dict(d: Dictionary) -> bool:
	_loaded = false
	load_error = ""
	if not achievements.is_loaded():
		return _fail("achievements not loaded")
	if str(d.get("schema", "")) != "mh.progression" or int(d.get("schema_version", 0)) != 1:
		return _fail("wrong schema or schema_version")
	var lv: Variant = d.get("levels", null)
	if typeof(lv) != TYPE_ARRAY or (lv as Array).size() < 2 or (lv as Array).size() > 50:
		return _fail("levels must have 2 to 50 rows")
	var rows: Array = []
	var prev_needed: int = -1
	var expect_level: int = 1
	for l: Variant in (lv as Array):
		if typeof(l) != TYPE_DICTIONARY:
			return _fail("level row is not an object")
		var ld: Dictionary = l
		if int(ld.get("level", 0)) != expect_level:
			return _fail("levels must be numbered 1, 2, 3 ... in order")
		if not MHDataJson.is_int_in(ld.get("prestige_needed", null), 0, 100000000):
			return _fail("bad prestige_needed")
		if int(ld["prestige_needed"]) <= prev_needed:
			return _fail("prestige_needed must rise (level 1 must need 0)")
		if expect_level == 1 and int(ld["prestige_needed"]) != 0:
			return _fail("level 1 must need 0 prestige")
		if str(ld.get("title_key", "")).is_empty() or typeof(ld.get("unlocks", null)) != TYPE_ARRAY:
			return _fail("level title_key or unlocks missing")
		prev_needed = int(ld["prestige_needed"])
		expect_level += 1
		rows.append(ld)
	if typeof(d.get("milestones", null)) != TYPE_DICTIONARY:
		return _fail("milestones missing")
	var ms: Dictionary = d["milestones"]
	for k: String in ["per_hole", "per_building_tier_step", "per_course_score_point", "members_div", "members_cap", "challenge_completed", "challenge_attempted", "commission_done_base"]:
		if not MHDataJson.is_int_in(ms.get(k, null), 0, 100000):
			return _fail("bad milestones." + k)
	if typeof(d.get("streak", null)) != TYPE_DICTIONARY:
		return _fail("streak missing")
	if not streak.configure(d["streak"] as Dictionary):
		return _fail("bad streak block")
	_levels = rows
	_ms = ms.duplicate()
	_loaded = true
	return true


func _fail(msg: String) -> bool:
	load_error = msg
	_loaded = false
	return false


# ------------------------------------------------------------------ prestige and level

## Points per source plus "total".
func points_breakdown() -> Dictionary:
	var out: Dictionary = {}
	if not _loaded:
		out["total"] = 0
		return out
	var completed: int = stats.value_of("challenges_completed")
	var attempted: int = stats.value_of("challenges_attempted")
	var members: int = 0
	if int(_ms["members_div"]) > 0:
		members = mini(stats.value_of("members_max") / int(_ms["members_div"]), int(_ms["members_cap"]))
	out["holes"] = int(_ms["per_hole"]) * stats.value_of("holes_max")
	out["tiers"] = int(_ms["per_building_tier_step"]) * stats.value_of("tier_sum")
	out["course"] = int(_ms["per_course_score_point"]) * stats.value_of("best_course_score")
	out["members"] = members
	out["challenges"] = int(_ms["challenge_completed"]) * completed + int(_ms["challenge_attempted"]) * maxi(0, attempted - completed)
	out["commissions"] = int(_ms["commission_done_base"]) * stats.value_of("commissions_done")
	out["achievements"] = achievements.total_points(_unlocked)
	out["streak"] = streak.milestone_points_total()
	out["bonus"] = stats.value_of("bonus_prestige")
	var total: int = 0
	for key: String in ["holes", "tiers", "course", "members", "challenges", "commissions", "achievements", "streak", "bonus"]:
		total += int(out[key])
	out["total"] = total
	return out


func club_points() -> int:
	return int(points_breakdown()["total"])


func level_count() -> int:
	return _levels.size()


## Level (1..level_count) reached with `points`.
func level_for_points(points: int) -> int:
	var lvl: int = 1
	for r: Variant in _levels:
		var rd: Dictionary = r
		if points >= int(rd["prestige_needed"]):
			lvl = int(rd["level"])
	return lvl


func level() -> int:
	return maxi(1, level_for_points(club_points()))


## Points needed for the next level, or -1 at the top level.
func points_for_next_level() -> int:
	var cur: int = level()
	if cur >= _levels.size():
		return -1
	return int((_levels[cur] as Dictionary)["prestige_needed"])


func level_row(lvl: int) -> Dictionary:
	if lvl < 1 or lvl > _levels.size():
		return {}
	return (_levels[lvl - 1] as Dictionary).duplicate(true)


## All unlock ids of levels 1..lvl in level order.
func unlocks_up_to_level(lvl: int) -> Array:
	var out: Array = []
	for r: Variant in _levels:
		var rd: Dictionary = r
		if int(rd["level"]) <= lvl:
			for u: Variant in (rd["unlocks"] as Array):
				out.append(str(u))
	return out


func is_unlocked(unlock_id: String) -> bool:
	return unlocks_up_to_level(level()).has(unlock_id)


# ------------------------------------------------------------------ feeding and refreshing

## Adds tournament or event-card prestige to the bonus stat (ignores zero and negatives).
func add_bonus_prestige(points: int) -> void:
	if points > 0:
		stats.raise_to("bonus_prestige", stats.value_of("bonus_prestige") + points)


## Registers an active day on the streak and mirrors streak_best and active_days into the stats.
func record_active_day(day: int) -> Dictionary:
	var r: Dictionary = streak.record_active(day)
	stats.observe({"streak_best": streak.best, "active_days": streak.active_days})
	return r


func observe_tournaments(ts: MHTournamentState) -> void:
	stats.observe_hosted(ts.hosted_levels, ts.hosted_count, ts.attempted_count)


func observe_daily(ds: MHDailyState) -> void:
	stats.observe({"challenges_attempted": ds.attempted_days, "challenges_completed": ds.completed_days})


## Raises the level stat and unlocks achievements until nothing changes (at most MAX_REFRESH_PASSES passes).
## Returns {"new_achievements": [ids in unlock order], "level_before", "level", "level_up", "new_unlocks": [ids]}.
func refresh() -> Dictionary:
	var before: int = maxi(1, stats.value_of("level"))
	var fresh: Array = []
	for pass_no: int in range(MAX_REFRESH_PASSES):
		stats.raise_to("level", level())
		var more: Array = achievements.newly_unlocked(stats, _unlocked)
		if more.is_empty():
			break
		for a: Variant in more:
			_unlocked.append(str(a))
			fresh.append(str(a))
	var after: int = level()
	stats.raise_to("level", after)
	var new_unlocks: Array = []
	if after > before:
		var old_list: Array = unlocks_up_to_level(before)
		for u: Variant in unlocks_up_to_level(after):
			if not old_list.has(u):
				new_unlocks.append(str(u))
	return {
		"new_achievements": fresh,
		"level_before": before,
		"level": after,
		"level_up": after > before,
		"new_unlocks": new_unlocks,
	}


func unlocked_ids() -> Array:
	return _unlocked.duplicate()


func is_achievement_unlocked(achievement_id: String) -> bool:
	return _unlocked.has(achievement_id)


## UI rows for the achievements screen (see MHAchievements.progress_rows).
func achievement_rows() -> Array:
	return achievements.progress_rows(stats, _unlocked)


# ------------------------------------------------------------------ persistence

## Ids for save.schema.json progress.achievements.
func to_save_ids() -> Array:
	return _unlocked.duplicate()


## Restores unlocked ids from the save. Unknown ids are dropped and duplicates ignored (a catalogue change must not
## break a save). Returns the number dropped.
func load_save_ids(ids: Array) -> int:
	var dropped: int = 0
	var fresh: Array = []
	for i: Variant in ids:
		var aid: String = str(i)
		if achievements.has_id(aid) and not fresh.has(aid):
			fresh.append(aid)
		else:
			dropped += 1
	_unlocked = fresh
	return dropped


## The progression part of a save document's `progress` object (save.schema.json): achievements (unlocked ids),
## stats (flat map of high-water marks) and streak. Merge it into the progress dictionary the save builds.
func to_save_progress() -> Dictionary:
	return {
		"achievements": to_save_ids(),
		"stats": stats.to_save_block(),
		"streak": streak.to_save_block(),
	}


## Reads achievements, stats and streak from a save's `progress` object. A missing "stats" or "streak" block (a v1
## save written before they existed) leaves the current values, so the streak starts fresh and the stats rebuild
## from the next observe calls. A malformed block returns false and changes nothing. Call refresh() afterwards.
func load_save_progress(progress: Dictionary) -> bool:
	var new_stats: MHProgressStats = null
	if progress.has("stats"):
		if typeof(progress["stats"]) != TYPE_DICTIONARY:
			return false
		new_stats = MHProgressStats.new()
		if not new_stats.from_save_block(progress["stats"] as Dictionary):
			return false
	var new_streak: MHStreak = null
	if progress.has("streak"):
		if typeof(progress["streak"]) != TYPE_DICTIONARY:
			return false
		new_streak = _blank_streak()
		if not new_streak.from_save_block(progress["streak"] as Dictionary):
			return false
	if progress.has("achievements") and typeof(progress["achievements"]) != TYPE_ARRAY:
		return false
	if new_stats != null:
		stats = new_stats
	if new_streak != null:
		streak = new_streak
	if progress.has("achievements"):
		load_save_ids(progress["achievements"] as Array)
	return true


## A streak with the configured rules (from progression.json) and no history.
func _blank_streak() -> MHStreak:
	var s: MHStreak = MHStreak.new()
	s.grace_start = streak.grace_start
	s.grace_max = streak.grace_max
	s.regain_every_days = streak.regain_every_days
	s.max_bridge_days = streak.max_bridge_days
	s.resume_percent = streak.resume_percent
	s.milestones = streak.milestones.duplicate(true)
	s.grace = mini(s.grace_start, s.grace_max)
	return s


## Stats, unlocked ids and streak in one Dictionary (a self-contained snapshot; saves use to_save_progress).
func to_dict() -> Dictionary:
	return {
		"v": SAVE_VERSION,
		"stats": stats.to_dict(),
		"unlocked": _unlocked.duplicate(),
		"streak": streak.to_dict(),
	}


func from_dict(d: Dictionary) -> bool:
	var errs: Array = []
	var norm: Variant = MHDataJson.normalize(d, errs, "$")
	if not errs.is_empty() or typeof(norm) != TYPE_DICTIONARY:
		return false
	var n: Dictionary = norm
	if int(n.get("v", 0)) != SAVE_VERSION:
		return false
	if typeof(n.get("stats", null)) != TYPE_DICTIONARY or typeof(n.get("streak", null)) != TYPE_DICTIONARY or typeof(n.get("unlocked", null)) != TYPE_ARRAY:
		return false
	var new_stats: MHProgressStats = MHProgressStats.new()
	if not new_stats.from_dict(n["stats"] as Dictionary):
		return false
	var new_streak: MHStreak = MHStreak.new()
	new_streak.grace_max = streak.grace_max
	new_streak.regain_every_days = streak.regain_every_days
	new_streak.max_bridge_days = streak.max_bridge_days
	new_streak.resume_percent = streak.resume_percent
	new_streak.milestones = streak.milestones.duplicate(true)
	if not new_streak.from_dict(n["streak"] as Dictionary):
		return false
	stats = new_stats
	streak = new_streak
	load_save_ids(n["unlocked"] as Array)
	return true

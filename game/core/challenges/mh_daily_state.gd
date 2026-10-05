class_name MHDailyState
extends RefCounted
## Per-player daily challenge record: attempts used today, a short history, a local board, and the two counters the
## achievements read (challenges attempted and completed, counted once per day). Pure logic, no clock: the caller
## passes the UTC day number (MHDailyChallenge.day_number_from_unix). It does NOT touch the streak: the caller calls
## MHStreak.record_active(day) on the first attempt of a day (result["first_attempt"]).
## Scores are permille (0..1000) as the rating engine returns them (score_pm, F).
## Not part of save.schema.json yet (no field for it), see docs/phase1/challenges.md; to_dict is JSON safe.
@warning_ignore_start("integer_division")

const SAVE_VERSION: int = 1
const DEFAULT_ATTEMPTS: int = 3
const DEFAULT_HISTORY_DAYS: int = 30
const DEFAULT_BOARD_CAP: int = 90

var attempts_per_day: int = DEFAULT_ATTEMPTS
var history_days: int = DEFAULT_HISTORY_DAYS
var board_cap: int = DEFAULT_BOARD_CAP

var attempted_days: int = 0
var completed_days: int = 0

var _day: int = -1
var _used: int = 0
var _completed_today: bool = false
var _best_pm: int = 0
var _best_f: int = 0
## [{"day", "attempts", "completed" (0/1), "best_pm"}], oldest first
var _history: Array = []
## [{"day", "score_pm", "fairness_pm"}], best first
var _board: Array = []


func configure(ch: MHDailyChallenge) -> void:
	attempts_per_day = ch.attempts_per_day()
	history_days = ch.history_days()
	board_cap = ch.local_board_cap()


func current_day() -> int:
	return _day


func attempts_used(day: int) -> int:
	if day != _day:
		return 0
	return _used


func attempts_left(day: int) -> int:
	return maxi(0, attempts_per_day - attempts_used(day))


func completed_on(day: int) -> bool:
	return day == _day and _completed_today


## Best score of that day as whole 0..100 (0 when no attempt).
func best_score(day: int) -> int:
	if day != _day:
		return 0
	return MHRMath.rdiv(_best_pm, 10)


func history() -> Array:
	return _history.duplicate(true)


func board() -> Array:
	return _board.duplicate(true)


## Records one attempt. Returns {"ok", "reason", "first_attempt", "newly_completed", "attempts_left", "best_pm"}.
## Reasons: past_day (day is before the stored day, clock went back), no_attempts, bad_day.
func record_attempt(day: int, completed: bool, score_pm: int, fairness_pm: int) -> Dictionary:
	if day < 0:
		return _refuse("bad_day")
	if day < _day:
		return _refuse("past_day")
	if day != _day:
		_roll_to(day)
	if _used >= attempts_per_day:
		return _refuse("no_attempts")
	_used += 1
	var first: bool = _used == 1
	if first:
		attempted_days += 1
	var newly: bool = false
	if completed and not _completed_today:
		_completed_today = true
		completed_days += 1
		newly = true
	var spm: int = clampi(score_pm, 0, 1000)
	var fpm: int = clampi(fairness_pm, 0, 1000)
	if spm > _best_pm or (spm == _best_pm and fpm > _best_f):
		_best_pm = spm
		_best_f = fpm
	_board_insert({"day": day, "score_pm": spm, "fairness_pm": fpm})
	return {
		"ok": true,
		"reason": "",
		"first_attempt": first,
		"newly_completed": newly,
		"attempts_left": attempts_left(day),
		"best_pm": _best_pm,
	}


func _refuse(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "first_attempt": false, "newly_completed": false, "attempts_left": 0, "best_pm": 0}


func _roll_to(day: int) -> void:
	if _day >= 0 and _used > 0:
		_history.append({"day": _day, "attempts": _used, "completed": 1 if _completed_today else 0, "best_pm": _best_pm})
		while _history.size() > history_days:
			_history.pop_front()
	_day = day
	_used = 0
	_completed_today = false
	_best_pm = 0
	_best_f = 0


## Board order: score desc, fairness desc, day asc (earlier first), then insertion order (stable).
func _board_insert(row: Dictionary) -> void:
	var pos: int = _board.size()
	while pos > 0 and _row_before(row, _board[pos - 1] as Dictionary):
		pos -= 1
	_board.insert(pos, row)
	while _board.size() > board_cap:
		_board.pop_back()


static func _row_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["score_pm"]) != int(b["score_pm"]):
		return int(a["score_pm"]) > int(b["score_pm"])
	if int(a["fairness_pm"]) != int(b["fairness_pm"]):
		return int(a["fairness_pm"]) > int(b["fairness_pm"])
	return int(a["day"]) < int(b["day"])


# ------------------------------------------------------------------ persistence

func to_dict() -> Dictionary:
	return {
		"v": SAVE_VERSION,
		"day": _day,
		"used": _used,
		"completed_today": 1 if _completed_today else 0,
		"best_pm": _best_pm,
		"best_f": _best_f,
		"attempted_days": attempted_days,
		"completed_days": completed_days,
		"history": _history.duplicate(true),
		"board": _board.duplicate(true),
	}


## Returns false and changes nothing when the data is malformed.
func from_dict(d: Dictionary) -> bool:
	var errs: Array = []
	var norm: Variant = MHDataJson.normalize(d, errs, "$")
	if not errs.is_empty() or typeof(norm) != TYPE_DICTIONARY:
		return false
	var n: Dictionary = norm
	if int(n.get("v", 0)) != SAVE_VERSION:
		return false
	var day: int = int(n.get("day", -2))
	if day < -1 or day > 1000000:
		return false
	for k: String in ["used", "best_pm", "best_f", "attempted_days", "completed_days"]:
		if not MHDataJson.is_int_in(n.get(k, null), 0, 1000000):
			return false
	if int(n["best_pm"]) > 1000 or int(n["best_f"]) > 1000 or int(n["used"]) > 10:
		return false
	if not MHDataJson.is_int_in(n.get("completed_today", null), 0, 1):
		return false
	var hv: Variant = n.get("history", null)
	var bv: Variant = n.get("board", null)
	if typeof(hv) != TYPE_ARRAY or typeof(bv) != TYPE_ARRAY:
		return false
	var hist: Array = []
	for h: Variant in (hv as Array):
		if typeof(h) != TYPE_DICTIONARY:
			return false
		var hd: Dictionary = h
		for k2: String in ["day", "attempts", "completed", "best_pm"]:
			if not MHDataJson.is_int_in(hd.get(k2, null), 0, 1000000):
				return false
		hist.append({"day": int(hd["day"]), "attempts": int(hd["attempts"]), "completed": int(hd["completed"]), "best_pm": int(hd["best_pm"])})
	var brd: Array = []
	for b: Variant in (bv as Array):
		if typeof(b) != TYPE_DICTIONARY:
			return false
		var bd: Dictionary = b
		for k3: String in ["day", "score_pm", "fairness_pm"]:
			if not MHDataJson.is_int_in(bd.get(k3, null), 0, 1000000):
				return false
		brd.append({"day": int(bd["day"]), "score_pm": int(bd["score_pm"]), "fairness_pm": int(bd["fairness_pm"])})
	_day = day
	_used = int(n["used"])
	_completed_today = int(n["completed_today"]) == 1
	_best_pm = int(n["best_pm"])
	_best_f = int(n["best_f"])
	attempted_days = int(n["attempted_days"])
	completed_days = int(n["completed_days"])
	_history = hist
	_board = brd
	while _history.size() > history_days:
		_history.pop_front()
	while _board.size() > board_cap:
		_board.pop_back()
	return true

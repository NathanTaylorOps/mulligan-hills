class_name MHProgressBridge
extends RefCounted
## Connects the progression, tournament and daily challenge modules to the UI (MHGameStateView rows) and to the two
## UI intents that act on them: `tournament_host {level}` and `daily_play`. It owns the module instances, builds the
## read-only rows the screens show, and runs the intents. It does NOT own cash, the clock, the economy, the rating
## engine or the save file: the game feeds those numbers in with update_inputs() and applies what the intents return
## (host cost to take, tournament cash and reputation to apply, tokens to award).
##
## Read side (used by MHGameStateView implementations): daily_row, tournament_rows, tournament_event,
## achievement_rows, club_level, club_points, points_for_next_level, level_title_key.
## Intent side (called by the game when MHUIShell.intent fires): handle_intent, host_tournament, start_daily,
## finish_daily_attempt, resolve_tournament. Every result Dictionary has "handled", "ok", "reason" and "message_key"
## (a MHStrings key for a toast, "" when there is nothing to say). Nothing here touches the clock or the system time.
##
## Units: money is whole DOLLARS (the tournament data's unit; the economy keeps cents, multiply by 100 there).
## Days: the game day counter (MHGameClock.day()) for tournaments, the UTC day number for the daily challenge.

const DAILY_BOARD_ROWS: int = 10
const SWITCH_TOURNAMENTS: String = "tournaments"

var progression: MHProgression = MHProgression.new()
var tournament_defs: MHTournamentDefs = MHTournamentDefs.new()
var tournaments: MHTournamentState = MHTournamentState.new()
var challenge: MHDailyChallenge = MHDailyChallenge.new()
var daily: MHDailyState = MHDailyState.new()
var load_error: String = ""

var _ready_ok: bool = false
var _game_day: int = 0
var _utc_day: int = 0
var _unix_now: int = 0
var _cash: int = 0
var _club: Dictionary = {}
var _recent_scores: Array = []
var _switches: Dictionary = {}
var _club_name: String = ""


static func create() -> MHProgressBridge:
	var b: MHProgressBridge = MHProgressBridge.new()
	b.load_defaults()
	return b


## Loads the four data files from res://data. Returns false and sets load_error when one is bad.
func load_defaults() -> bool:
	_ready_ok = false
	load_error = ""
	if not progression.load_defaults():
		load_error = "progression: " + progression.load_error
		return false
	if not tournament_defs.load_from_file():
		load_error = "tournaments: " + tournament_defs.load_error
		return false
	if not challenge.load_from_file():
		load_error = "daily challenges: " + challenge.load_error
		return false
	daily.configure(challenge)
	_ready_ok = true
	return true


func is_ready() -> bool:
	return _ready_ok


## Numbers the game owns. game_day = MHGameClock.day(); unix_now from the platform clock (server time when known);
## cash in whole dollars; club_view is the Dictionary of MHTournamentRules (holes, avg_hole_score, pace_score,
## staff, tiers); recent_course_scores = daily course scores 0..100, oldest first (ratings.daily_snapshots);
## kill_switches = the last good remote config's kill_switches object ({} when none).
func update_inputs(game_day: int, unix_now: int, cash: int, club_view: Dictionary, recent_course_scores: Array, kill_switches: Dictionary, club_name: String) -> void:
	_game_day = maxi(0, game_day)
	_utc_day = MHDailyChallenge.day_number_from_unix(maxi(0, unix_now))
	_unix_now = maxi(0, unix_now)
	_cash = maxi(0, cash)
	_club = club_view.duplicate(true)
	_recent_scores = recent_course_scores.duplicate()
	_switches = kill_switches.duplicate(true)
	_club_name = club_name


# ------------------------------------------------------------------ read side

func club_level() -> int:
	return progression.level()


func club_points() -> int:
	return progression.club_points()


## Points needed for the next level, -1 at the top level.
func points_for_next_level() -> int:
	return progression.points_for_next_level()


func level_title_key() -> String:
	var row: Dictionary = progression.level_row(progression.level())
	return str(row.get("title_key", ""))


func achievement_rows() -> Array:
	return progression.achievement_rows()


## Row shape documented in MHGameStateView (daily). Extra key: completed_today. When the feature is off, or the
## data is missing, "enabled" is false and the other keys are zero values.
func daily_row() -> Dictionary:
	var row: Dictionary = {
		"enabled": false, "title_key": "", "desc_key": "", "attempts_left": 0, "attempts_total": daily.attempts_per_day,
		"target_score": 0, "best_score": 0, "streak_days": 0, "ends_in_minutes": 0, "board": [], "completed_today": false,
	}
	if not _ready_ok:
		return row
	var ch: Dictionary = challenge.today(_utc_day, _switches)
	if ch.is_empty():
		return row
	row["enabled"] = true
	row["title_key"] = str(ch["title_key"])
	row["desc_key"] = str(ch["desc_key"])
	row["target_score"] = int(ch["target_score"])
	row["attempts_left"] = daily.attempts_left(_utc_day)
	row["best_score"] = daily.best_score(_utc_day)
	row["streak_days"] = progression.streak.display_streak(_utc_day)
	row["ends_in_minutes"] = MHDailyChallenge.minutes_until_rollover(_unix_now)
	row["completed_today"] = daily.completed_on(_utc_day)
	var board: Array = []
	var src: Array = daily.board()
	for i: int in range(mini(src.size(), DAILY_BOARD_ROWS)):
		var r: Dictionary = src[i]
		board.append({"name": _club_name, "score": MHRMath.rdiv(int(r["score_pm"]), 10)})
	row["board"] = board
	return row


## One row per level, in ladder order. Row shape documented in MHGameStateView (tournament). Extra keys:
## can_host (bool, every condition of MHTournamentState.can_start incl. cash and the kill switch) and block_reason
## ("" or the refusal reason: unknown_level, disabled, busy, cooldown, locked, cash).
func tournament_rows() -> Array:
	var out: Array = []
	if not _ready_ok:
		return out
	var feature_on: bool = MHKillSwitch.is_on(_switches, SWITCH_TOURNAMENTS)
	for lid: Variant in tournament_defs.level_ids():
		var level: String = str(lid)
		var ld: Dictionary = tournament_defs.level_data(level)
		var reward: Dictionary = ld["reward"]
		var status: String = tournaments.status_for(tournament_defs, level, _game_day, _club)
		var chk: Dictionary = tournaments.can_start(tournament_defs, level, _game_day, _club, _cash, feature_on)
		var rep: MHGateReport = MHTournamentRules.entry_report(tournament_defs, level, _club)
		var cooldown_left: int = 0
		if status == "cooldown":
			cooldown_left = tournaments.cooldown_days_left(_game_day)
		out.append({
			"level": level,
			"status": status,
			"host_cost": int(ld["host_cost"]),
			"reward_cash": int(reward["cash"]),
			"reward_reputation": int(reward["reputation"]),
			"cooldown_days": cooldown_left,
			"rows": rep.rows.duplicate(true),
			"can_host": bool(chk["ok"]),
			"block_reason": str(chk["reason"]),
		})
	return out


## The running event, {} when none: level, status, start_day, resolve_day, days_left.
func tournament_event() -> Dictionary:
	if not _ready_ok or not tournaments.is_active():
		return {}
	var act: Dictionary = tournaments.active
	var resolve: int = tournaments.resolve_day(tournament_defs)
	return {
		"level": str(act["level"]),
		"status": str(act["status"]),
		"start_day": int(act["start_day"]),
		"resolve_day": resolve,
		"days_left": maxi(0, resolve - _game_day),
	}


# ------------------------------------------------------------------ feeding progression

## Raises stats from a snapshot (see MHProgressStats.observe), the purchased tiers, the tournament and daily
## counters, then runs refresh(). Returns refresh()'s result: {new_achievements, level_before, level, level_up,
## new_unlocks}. The caller awards one earned token per new achievement (MHTokenLedger rule "achievement").
func observe_club(snapshot: Dictionary, purchased_tiers: Dictionary) -> Dictionary:
	progression.stats.observe(snapshot)
	progression.stats.observe_tiers(purchased_tiers)
	progression.observe_tournaments(tournaments)
	progression.observe_daily(daily)
	return progression.refresh()


# ------------------------------------------------------------------ intents

## Routes the two UI intents this bridge owns. Anything else returns handled = false.
func handle_intent(id: StringName, args: Dictionary) -> Dictionary:
	if id == &"tournament_host":
		return host_tournament(str(args.get("level", "")))
	if id == &"daily_play":
		return start_daily()
	return _result(false)


## Intent tournament_host. On success the event is recorded (course locked, snapshot score stored) and "cost" is the
## host cost in whole dollars the caller MUST now take from the economy. The game must also update cash through
## update_inputs. Refusal reasons: not_ready, unknown_level, disabled, busy, cooldown, locked, cash.
func host_tournament(level_id: String) -> Dictionary:
	var out: Dictionary = _result(true)
	out["cost"] = 0
	out["event_id"] = -1
	if not _ready_ok:
		out["reason"] = "not_ready"
		return out
	var feature_on: bool = MHKillSwitch.is_on(_switches, SWITCH_TOURNAMENTS)
	var snap: int = MHTournamentRules.snapshot_score(tournament_defs, _recent_scores)
	var r: Dictionary = tournaments.start(tournament_defs, level_id, _game_day, _club, _cash, feature_on, snap)
	out["reason"] = str(r["reason"])
	if bool(r["ok"]):
		out["ok"] = true
		out["cost"] = int(r["cost"])
		out["event_id"] = int(r["event_id"])
		out["message_key"] = "toast.tournament.started"
	else:
		out["message_key"] = "tournament.blocked." + str(r["reason"])
	return out


## Intent daily_play. Checks the kill switch and the attempts left and returns today's challenge for the game to
## open the editor with ("challenge" has sim_seed, par, thresholds). It does not use up an attempt: that happens in
## finish_daily_attempt. Refusal reasons: not_ready, disabled, no_attempts.
func start_daily() -> Dictionary:
	var out: Dictionary = _result(true)
	out["challenge"] = {}
	out["attempts_left"] = 0
	if not _ready_ok:
		out["reason"] = "not_ready"
		return out
	var ch: Dictionary = challenge.today(_utc_day, _switches)
	if ch.is_empty():
		out["reason"] = "disabled"
		out["message_key"] = "toast.daily.off"
		return out
	var left: int = daily.attempts_left(_utc_day)
	out["attempts_left"] = left
	if left <= 0:
		out["reason"] = "no_attempts"
		out["message_key"] = "toast.daily.no_attempts"
		return out
	out["ok"] = true
	out["challenge"] = ch
	return out


## Records one finished attempt. entry = {valid, par, length_yd, score (0..100), axes {accuracy, imagination, length,
## beauty, fairness} (0..100)} as MHDailyChallenge.evaluate documents. Uses up an attempt, registers the active day on
## the first attempt of the day (streak), feeds the counters and runs refresh(). Result keys: completed, rows,
## first_attempt, newly_completed, attempts_left, refresh (see observe_club), message_params {left}. The caller
## awards tokens (challenge_complete once per day, achievement per new achievement) and uploads the score.
## Refusal reasons: not_ready, disabled, no_attempts, past_day, bad_day.
func finish_daily_attempt(entry: Dictionary) -> Dictionary:
	var out: Dictionary = _result(true)
	out["completed"] = false
	out["rows"] = []
	out["first_attempt"] = false
	out["newly_completed"] = false
	out["attempts_left"] = 0
	out["refresh"] = {}
	out["message_params"] = {}
	if not _ready_ok:
		out["reason"] = "not_ready"
		return out
	var ch: Dictionary = challenge.today(_utc_day, _switches)
	if ch.is_empty():
		out["reason"] = "disabled"
		out["message_key"] = "toast.daily.off"
		return out
	var judged: Dictionary = MHDailyChallenge.evaluate(ch, entry)
	var axes: Dictionary = entry.get("axes", {}) as Dictionary
	var score_pm: int = clampi(int(entry.get("score", 0)), 0, 100) * 10
	var fair_pm: int = clampi(int(axes.get("fairness", 0)), 0, 100) * 10
	var rec: Dictionary = daily.record_attempt(_utc_day, bool(judged["completed"]), score_pm, fair_pm)
	out["completed"] = bool(judged["completed"])
	out["rows"] = judged["rows"]
	if not bool(rec["ok"]):
		out["reason"] = str(rec["reason"])
		if out["reason"] == "no_attempts":
			out["message_key"] = "toast.daily.no_attempts"
		return out
	out["ok"] = true
	out["first_attempt"] = bool(rec["first_attempt"])
	out["newly_completed"] = bool(rec["newly_completed"])
	out["attempts_left"] = int(rec["attempts_left"])
	if bool(rec["first_attempt"]):
		progression.record_active_day(_utc_day)
	progression.observe_daily(daily)
	out["refresh"] = progression.refresh()
	out["message_params"] = {"left": int(rec["attempts_left"])}
	out["message_key"] = "toast.daily.done" if bool(rec["newly_completed"]) else "toast.daily.tried"
	return out


## Resolves the running tournament when its last day has come (call on each new game day, or after update_inputs).
## ctx is the MHTournamentSim.evaluate context (event_seed from MHTournamentSim.event_seed(secret, event id, slot),
## pace_score, fairness per hole, maintenance_tier, tiers, pars, total_yards; the stored snapshot score is filled in
## here). On success: "result" is the evaluate Dictionary (the caller applies cash_delta and reputation_delta),
## prestige_points go to the progression bonus, counters are fed and refresh() runs ("refresh" key).
## Refusal reasons: not_ready, none_active, not_ready_yet, finish_refused.
func resolve_tournament(ctx: Dictionary) -> Dictionary:
	var out: Dictionary = _result(true)
	out["result"] = {}
	out["refresh"] = {}
	if not _ready_ok:
		out["reason"] = "not_ready"
		return out
	if not tournaments.is_active():
		out["reason"] = "none_active"
		return out
	if not tournaments.advance(tournament_defs, _game_day):
		out["reason"] = "not_ready_yet"
		return out
	var level: String = str(tournaments.active["level"])
	var full_ctx: Dictionary = ctx.duplicate(true)
	full_ctx["snapshot_score"] = int(tournaments.active["snapshot_score"])
	var res: Dictionary = MHTournamentSim.evaluate(tournament_defs, level, full_ctx)
	if res.is_empty() or not tournaments.finish(tournament_defs, _game_day, res):
		out["reason"] = "finish_refused"
		return out
	progression.add_bonus_prestige(int(res.get("prestige_points", 0)))
	progression.observe_tournaments(tournaments)
	out["ok"] = true
	out["result"] = res
	out["refresh"] = progression.refresh()
	return out


# ------------------------------------------------------------------ save

## The parts of a save document's `progress` object this bridge owns: achievements, stats, streak, tournaments
## (with counters) and daily. Merge into the progress Dictionary of the save.
func to_save_progress() -> Dictionary:
	var out: Dictionary = progression.to_save_progress()
	out["tournaments"] = tournaments.to_save_block()
	out["daily"] = daily.to_save_block()
	return out


## Reads them back from a save's `progress` object. A missing block (a save from before it existed) leaves that part
## fresh. Returns false and changes nothing when any present block is malformed. Call observe_club afterwards.
func load_save_progress(progress: Dictionary) -> bool:
	var new_tournaments: MHTournamentState = MHTournamentState.new()
	if progress.has("tournaments"):
		if typeof(progress["tournaments"]) != TYPE_DICTIONARY:
			return false
		if not new_tournaments.from_save_block(progress["tournaments"] as Dictionary):
			return false
	var new_daily: MHDailyState = MHDailyState.new()
	if challenge.is_loaded():
		new_daily.configure(challenge)
	if progress.has("daily"):
		if typeof(progress["daily"]) != TYPE_DICTIONARY:
			return false
		if not new_daily.from_save_block(progress["daily"] as Dictionary):
			return false
	if not progression.load_save_progress(progress):
		return false
	tournaments = new_tournaments
	daily = new_daily
	return true


func _result(handled: bool) -> Dictionary:
	return {"handled": handled, "ok": false, "reason": "not_mine" if not handled else "", "message_key": ""}

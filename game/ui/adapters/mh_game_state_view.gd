class_name MHGameStateView
extends RefCounted
## READ-ONLY view of the game that every UI screen reads. Screens never touch the simulation, economy,
## buildings or save modules directly: the shell hands each screen one of these, and a screen reports what
## the player wants through its `intent` signal. The real implementation (a later task) wraps MHGameClock,
## the economy, MHBuildingDefs, MHLandModel, MHTokenLedger and the rating engine. MHFakeGameStateView
## (this folder) has sample data for the gallery and the tests.
##
## Rules for implementers:
## - No method here changes game state. There are deliberately no setters, no buy, no spend.
## - Money is whole dollars, scores are permille (0..1000) or whole 0..100 as named, time is game minutes.
## - Dictionaries returned are copies. Never hand out the live object of a game module.
## - Emit `changed` after anything a screen shows has changed (the shell refreshes the open screen).
##
## Row shapes (Dictionary keys):
##   hole rating:  hole_no, par, length_yd, valid(bool), dead(bool), score_pm, accuracy_pm, imagination_pm,
##                 length_pm, beauty_pm, fairness_pm, reasons(Array of {code, severity, a, b})
##   daily:        enabled(bool), title_key, desc_key, attempts_left, attempts_total, target_score,
##                 best_score, streak_days, ends_in_minutes, board(Array of {name, score})
##   tournament:   level, status ("locked","available","cooldown","active"), host_cost, reward_cash,
##                 reward_reputation, cooldown_days, rows(Array of [key, met, have, need])
##   achievement:  id, category, tier, points, hidden(bool), earned(bool), progress, target
##   recovery:     active(bool), shortfall, loan_amount, reputation_penalty, token_cost
##   product:      id, tokens, price_text   (placeholders; no store code exists)

signal changed()

const SPEEDS: Array = [1, 2, 4, 8]


func is_demo() -> bool:
	return false


func club_name() -> String:
	return ""


## Whole dollars. Never negative outside sandbox.
func cash() -> int:
	return 0


## Clock day counter, 0 based (the player sees day + 1, see MHFormat.day_number).
func day() -> int:
	return 0


## Minute inside the game day, 0..659 (see MHFormat.game_clock).
func minute_of_day() -> int:
	return 0


func speed() -> int:
	return 1


func is_paused() -> bool:
	return false


func tokens_earned() -> int:
	return 0


func tokens_paid() -> int:
	return 0


func tokens_total() -> int:
	return maxi(0, tokens_earned()) + maxi(0, tokens_paid())


## Course score in tenths, 0..1000 (shown as 0.0 to 100.0).
func course_score_x10() -> int:
	return 0


func members() -> int:
	return 0


func income_per_day() -> int:
	return 0


func upkeep_per_day() -> int:
	return 0


## Per-hole scores 0..100 (valid holes only, dead ones included). Empty array when no holes exist.
func hole_scores() -> Array:
	return []


func hole_count() -> int:
	return hole_scores().size()


## Rating row for a hole (1 based), see the shape above. Empty dictionary for an unknown hole.
func hole_rating(_hole_no: int) -> Dictionary:
	return {}


## The loaded catalogue (shared, read only by convention). May be an unloaded MHBuildingDefs.
func building_defs() -> MHBuildingDefs:
	return null


## Snapshot for gate checks (copy).
func gate_view() -> MHGateView:
	return MHGateView.new()


func tier_of(building_id: String) -> int:
	return gate_view().tier_of(building_id)


## Extra income per day this tier would add right now, from the economy. Price = payback days x this (DEC-050).
func added_daily_income(_building_id: String, _tier: int) -> int:
	return 0


## Land state (shared, read only by convention). May be null before a course exists.
func land() -> MHLandModel:
	return null


func daily_challenge() -> Dictionary:
	return {"enabled": false}


func tournaments() -> Array:
	return []


func achievements() -> Array:
	return []


func recovery_offer() -> Dictionary:
	return {"active": false, "shortfall": 0, "loan_amount": 0, "reputation_penalty": 0, "token_cost": 0}


## Token pack placeholders for the store screen. Prices are text only; nothing can be bought.
func store_products() -> Array:
	return []


## Whether the course has unsaved or undoable editor work (drives the undo and redo buttons).
func can_undo() -> bool:
	return false


func can_redo() -> bool:
	return false

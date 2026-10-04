class_name MHAutosavePolicy
extends RefCounted
## Pure autosave rule (DEC-052): save at every game hour boundary.
## current_game_minute is the absolute game minute counter (60 game minutes = 1 game hour).
## last_saved_hour is the game-hour index of the last successful save, or -1 if none since the session started.
## The rule is "the hour index has advanced past the last saved one". Fast-forward across several hours saves once.
## If the clock goes backwards (an older save was loaded), nothing is due until the hour passes last_saved_hour;
## after loading, callers should call hour_of(minute) to seed last_saved_hour.

const MINUTES_PER_HOUR: int = 60


@warning_ignore("integer_division")
static func hour_of(current_game_minute: int) -> int:
	if current_game_minute < 0:
		return -1
	return current_game_minute / MINUTES_PER_HOUR


static func should_autosave(current_game_minute: int, last_saved_hour: int) -> bool:
	if current_game_minute < 0:
		return false
	return hour_of(current_game_minute) > last_saved_hour

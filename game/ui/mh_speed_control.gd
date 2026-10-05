class_name MHSpeedControl
extends RefCounted
## Pure logic behind the HUD speed control (DEC-052, DEC-053). 1x is always free. 2x, 4x and 8x spend tokens
## (earned first, then paid, see MHTokenLedger) at 1, 2 and 4 tokens per real minute, so they are locked
## while the player holds no token. The clock itself enforces this too; the UI only mirrors the rule.

const SPEEDS: Array = [1, 2, 4, 8]


static func tokens_per_minute(speed: int) -> int:
	return MHGameClock.tokens_per_real_minute(speed)


static func is_locked(speed: int, tokens_total: int) -> bool:
	return speed > 1 and tokens_total < 1


static func can_select(speed: int, tokens_total: int) -> bool:
	return MHGameClock.is_valid_speed(speed) and not is_locked(speed, tokens_total)


## Speed the clock will really run at: a boosted speed with no tokens left falls back to 1x.
static func effective_speed(current: int, tokens_total: int) -> int:
	if not MHGameClock.is_valid_speed(current):
		return 1
	if is_locked(current, tokens_total):
		return 1
	return current


## Whole real minutes the balance lasts at a speed. -1 for 1x (it costs nothing).
@warning_ignore("integer_division")
static func minutes_left(tokens_total: int, speed: int) -> int:
	var rate: int = tokens_per_minute(speed)
	if rate <= 0:
		return -1
	return maxi(0, tokens_total) / rate


## One row per speed: {speed, locked, selected, tokens_per_min}.
static func options(tokens_total: int, current: int) -> Array:
	var out: Array = []
	var eff: int = effective_speed(current, tokens_total)
	for s: Variant in SPEEDS:
		var sp: int = int(s)
		out.append({
			"speed": sp,
			"locked": is_locked(sp, tokens_total),
			"selected": sp == eff,
			"tokens_per_min": tokens_per_minute(sp),
		})
	return out

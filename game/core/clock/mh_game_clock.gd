class_name MHGameClock
extends RefCounted
## Deterministic game clock (DEC-052, DEC-053). Pure logic: it never reads the system clock; the caller passes a
## real-time delta in integer microseconds.
##
## Time model: one game day is 660 game minutes (11 hours, day only). At 1x a game day lasts 15 real minutes
## (900,000,000 us), which is 44 game seconds per real second. Speeds 2x, 4x, 8x consume token time.
## Fractions are kept exactly with an integer accumulator measured in (real us * game minutes), so stepping
## is exact and independent of how the real time is sliced into frames.
##
## step() returns events as flat ints, EVENT_STRIDE per event: [type, day, value].
##   EV_HOUR (1):  an in-game hour ended. day = the day it belongs to, value = hour of day 1..11.
##   EV_DAY (2):   a day ended and the next began. day = the NEW day number, value = 0.
##   EV_SPEED_DROPPED (3): tokens ran out, speed fell back to 1x. day = current day, value = old speed.
## When hour 11 ends, EV_HOUR (day d, value 11) comes first, then EV_DAY (day d+1).
##
## Backgrounding: a single delta above SPIKE_US (2 s) is treated as "the app was suspended": it is clamped to
## CATCHUP_CAP_US (120 s) at 1x with no token drain, and the rest is discarded (see last_discarded_us).
## So at most 88 game minutes (about 1.5 game hours) pass per suspension. There is no offline progress beyond it.
## Paused clocks ignore step() entirely.

const MINUTES_PER_HOUR: int = 60
const HOURS_PER_DAY: int = 11
const MINUTES_PER_DAY: int = 660
const REAL_US_PER_DAY_1X: int = 900000000
const SPIKE_US: int = 2000000
const CATCHUP_CAP_US: int = 120000000
## Token accounting unit: rate (tokens per real minute) * real microseconds. One token = 60,000,000 units per
## (token per real minute), i.e. one token buys 60 real seconds of 2x, 30 s of 4x or 15 s of 8x.
const TOKEN_UNITS: int = 60000000

const EVENT_STRIDE: int = 3
const EV_HOUR: int = 1
const EV_DAY: int = 2
const EV_SPEED_DROPPED: int = 3

const SPEED_OK: int = 0
const SPEED_DENIED_TOKENS: int = 1
const SPEED_DENIED_INVALID: int = 2

const SAVE_VERSION: int = 1

var _total_minutes: int = 0
var _acc: int = 0
var _speed: int = 1
var _paused: bool = false
var _credit: int = 0
var last_discarded_us: int = 0
var last_was_catchup: bool = false


static func is_valid_speed(speed: int) -> bool:
	return speed == 1 or speed == 2 or speed == 4 or speed == 8


## Tokens consumed per real minute at a speed (0 at 1x).
static func tokens_per_real_minute(speed: int) -> int:
	if speed == 2:
		return 1
	if speed == 4:
		return 2
	if speed == 8:
		return 4
	return 0


func set_time(day: int, minute_of_day: int) -> void:
	_total_minutes = maxi(0, day) * MINUTES_PER_DAY + clampi(minute_of_day, 0, MINUTES_PER_DAY - 1)
	_acc = 0


func total_minutes() -> int:
	return _total_minutes


@warning_ignore("integer_division")
func day() -> int:
	return _total_minutes / MINUTES_PER_DAY


func minute_of_day() -> int:
	return _total_minutes % MINUTES_PER_DAY


## Completed hours in the current day, 0..10.
@warning_ignore("integer_division")
func hour_of_day() -> int:
	return minute_of_day() / MINUTES_PER_HOUR


func speed() -> int:
	return _speed


func is_paused() -> bool:
	return _paused


func pause() -> void:
	_paused = true


func resume() -> void:
	_paused = false


func prepaid_credit() -> int:
	return _credit


## Ask for a speed. 1x is always allowed. Above 1x needs at least one whole token in `token_balance` or
## leftover prepaid credit. Returns SPEED_OK (speed changed), SPEED_DENIED_TOKENS or SPEED_DENIED_INVALID
## (speed unchanged). Nothing is spent here; step() drains tokens per real second.
func request_speed(new_speed: int, token_balance: int) -> int:
	if not is_valid_speed(new_speed):
		return SPEED_DENIED_INVALID
	if new_speed == 1:
		_speed = 1
		return SPEED_OK
	if _credit <= 0 and token_balance < 1:
		return SPEED_DENIED_TOKENS
	_speed = new_speed
	return SPEED_OK


## Advance by delta_us real microseconds. `ledger` may be null (then speeds above 1x drop to 1x at once).
## Returns event rows, EVENT_STRIDE ints each.
func step(delta_us: int, ledger: MHTokenLedger = null) -> PackedInt32Array:
	var events: PackedInt32Array = PackedInt32Array()
	last_discarded_us = 0
	last_was_catchup = false
	if delta_us <= 0 or _paused:
		return events
	var delta: int = delta_us
	var catchup: bool = delta > SPIKE_US
	if delta > CATCHUP_CAP_US:
		last_discarded_us = delta - CATCHUP_CAP_US
		delta = CATCHUP_CAP_US
	last_was_catchup = catchup
	var boosted_us: int = 0
	var boost_speed: int = _speed
	var dropped_from: int = 0
	if not catchup and _speed > 1:
		var rate: int = tokens_per_real_minute(_speed)
		var need: int = rate * delta
		if _credit < need and ledger != null:
			var short: int = need - _credit
			@warning_ignore("integer_division")
			var want: int = (short + TOKEN_UNITS - 1) / TOKEN_UNITS
			var got: int = ledger.spend_up_to(want)
			_credit += got * TOKEN_UNITS
		if _credit >= need:
			boosted_us = delta
			_credit -= need
		else:
			@warning_ignore("integer_division")
			boosted_us = _credit / rate
			_credit = 0 # the remainder is under one microsecond of boost: not worth a speed request
			dropped_from = _speed
			_speed = 1
	var slow_us: int = delta - boosted_us
	var effective_us: int = boosted_us * boost_speed + slow_us
	_advance(effective_us, events)
	if dropped_from > 0:
		events.append(EV_SPEED_DROPPED)
		events.append(day())
		events.append(dropped_from)
	return events


func _advance(effective_us: int, events: PackedInt32Array) -> void:
	_acc += effective_us * MINUTES_PER_DAY
	@warning_ignore("integer_division")
	var new_minutes: int = _acc / REAL_US_PER_DAY_1X
	_acc = _acc % REAL_US_PER_DAY_1X
	if new_minutes <= 0:
		return
	var old_total: int = _total_minutes
	_total_minutes += new_minutes
	@warning_ignore("integer_division")
	var first_hour: int = old_total / MINUTES_PER_HOUR + 1
	@warning_ignore("integer_division")
	var last_hour: int = _total_minutes / MINUTES_PER_HOUR
	for h in range(first_hour, last_hour + 1):
		@warning_ignore("integer_division")
		var hour_day: int = (h - 1) / HOURS_PER_DAY
		events.append(EV_HOUR)
		events.append(hour_day)
		events.append((h - 1) % HOURS_PER_DAY + 1)
		if h % HOURS_PER_DAY == 0:
			events.append(EV_DAY)
			events.append(hour_day + 1)
			events.append(0)


func to_dict() -> Dictionary:
	return {
		"v": SAVE_VERSION,
		"total_minutes": _total_minutes,
		"acc": _acc,
		"speed": _speed,
		"paused": _paused,
		"credit": _credit,
	}


## Returns false and changes nothing if the data is invalid.
func from_dict(d: Dictionary) -> bool:
	if not d.has("total_minutes"):
		return false
	var tm: int = int(d["total_minutes"])
	var acc: int = int(d.get("acc", 0))
	var sp: int = int(d.get("speed", 1))
	var cr: int = int(d.get("credit", 0))
	if tm < 0 or acc < 0 or acc >= REAL_US_PER_DAY_1X or cr < 0 or not is_valid_speed(sp):
		return false
	_total_minutes = tm
	_acc = acc
	_speed = sp
	_credit = cr
	_paused = bool(d.get("paused", false))
	return true

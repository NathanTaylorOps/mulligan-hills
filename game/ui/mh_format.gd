class_name MHFormat
extends RefCounted
## Pure formatting helpers for the UI: money, clock time, distances, durations, multipliers.
## Integer math only (no float rounding surprises). Every function is static and side-effect free.


## 1234567 -> "1,234,567". Negative numbers keep their sign.
static func group_thousands(n: int) -> String:
	var neg: bool = n < 0
	var s: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i: int in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	if neg:
		out = "-" + out
	return out


## 1234 -> "$1,234", -50 -> "-$50".
static func money(amount: int) -> String:
	if amount < 0:
		return "-$" + group_thousands(-amount)
	return "$" + group_thousands(amount)


## Short money for tight HUD chips. Under 10,000 the full amount; then $12.3K; then $1.25M. Truncates, never rounds up.
static func money_compact(amount: int) -> String:
	var a: int = absi(amount)
	var sign: String = "-" if amount < 0 else ""
	if a < 10000:
		return sign + "$" + group_thousands(a)
	if a < 1000000:
		return "%s$%d.%dK" % [sign, a / 1000, (a % 1000) / 100]
	return "%s$%d.%02dM" % [sign, a / 1000000, (a % 1000000) / 10000]


## Minute of the game day (0..1439, wraps) -> "9:30 AM" (or "09:30" when use_24h).
static func clock(minute_of_day: int, use_24h: bool = false) -> String:
	var m: int = posmod(minute_of_day, 1440)
	var h: int = m / 60
	var mm: int = m % 60
	if use_24h:
		return "%02d:%02d" % [h, mm]
	var suffix: String = "AM" if h < 12 else "PM"
	var h12: int = h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, mm, suffix]


## 75 -> "1h 15m", 45 -> "45m", 120 -> "2h", 0 -> "0m". Negative counts as 0.
static func duration_minutes(minutes: int) -> String:
	var m: int = maxi(0, minutes)
	var h: int = m / 60
	var r: int = m % 60
	if h == 0:
		return "%dm" % r
	if r == 0:
		return "%dh" % h
	return "%dh %02dm" % [h, r]


## Yards to metres, integer rounding half up. 100 yd -> 91 m.
static func yards_to_metres(yards: int) -> int:
	return (yards * 914 + 500) / 1000


## Hole lengths are stored in yards. metric=true shows metres.
static func distance(yards: int, metric: bool) -> String:
	if metric:
		return "%d m" % yards_to_metres(yards)
	return "%d yd" % yards


## Terrain height in millimetres: metric "1.2 m", imperial "3.9 ft". Truncates toward zero.
static func height_mm(mm: int, metric: bool) -> String:
	var neg: bool = mm < 0
	var a: int = absi(mm)
	var sign: String = "-" if neg else ""
	if metric:
		return "%s%d.%d m" % [sign, a / 1000, (a % 1000) / 100]
	var tenths_ft: int = (a * 100) / 3048
	return "%s%d.%d ft" % [sign, tenths_ft / 10, tenths_ft % 10]


## Permille multiplier: 1000 -> "x1.00", 940 -> "x0.94", 1250 -> "x1.25".
static func multiplier_pm(pm: int) -> String:
	var p: int = maxi(0, pm)
	return "x%d.%02d" % [p / 1000, (p % 1000) / 10]


## 0..1000 permille to a whole percent string, 875 -> "87%".
static func percent_pm(pm: int) -> String:
	return "%d%%" % (clampi(pm, 0, 1000) / 10)


## Integer ratio as whole percent, safe for max <= 0 (gives 0).
static func ratio_percent(value: int, max_value: int) -> int:
	if max_value <= 0:
		return 0
	return clampi((value * 100) / max_value, 0, 100)


## Payback in whole days, rounded up. Zero or negative income returns -1 (never pays back).
static func payback_days(cost: int, added_income_per_day: int) -> int:
	if added_income_per_day <= 0 or cost <= 0:
		return -1
	return (cost + added_income_per_day - 1) / added_income_per_day

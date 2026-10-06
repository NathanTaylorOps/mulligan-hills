class_name MHStaffMath
extends RefCounted
## Integer helpers for the staff module. Mirror of the helpers in tools/reference/staff/mh_staff.py.
## GDScript int / int truncates toward zero and Python // floors. idiv is only called with non-negative operands (where
## the two agree); fdiv is the floor division used where a numerator can be negative. No floats anywhere. NOT YET RUN.

const HOURS_PER_DAY: int = 11


@warning_ignore("integer_division")
static func idiv(a: int, b: int) -> int:
	return a / b


## Floor division, b > 0 (same as Python //).
@warning_ignore("integer_division")
static func fdiv(a: int, b: int) -> int:
	var q: int = a / b
	if a < 0 and (a % b) != 0:
		q -= 1
	return q


## Exact split of a daily amount over the 11 game hours (hour_index 0..10): the parts sum to daily.
## Same rule as MHEconomyModel.split_hour (a test checks they agree).
static func split_hour(daily: int, hour_index: int) -> int:
	if daily <= 0:
		return 0
	var h: int = clampi(hour_index, 0, HOURS_PER_DAY - 1)
	return idiv(daily * (h + 1), HOURS_PER_DAY) - idiv(daily * h, HOURS_PER_DAY)

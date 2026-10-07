class_name MHSliceSchedule
extends RefCounted
## Visual golfer arrivals and tee times for the vertical slice. Integer only, deterministic, pure logic.
## It READS economy numbers (hour_golfers_expected_milli) and never writes the session.
##
## Flow: once per game hour the scene calls add_hour(milli). Whole golfers (with a carried remainder, like the
## economy) are cut into groups. release(now_minute) hands out one group per tee slot; a tee slot comes every
## `interval_min` game minutes (60 / tee_groups_per_hour). Groups wait in a queue when slots are taken.
## The visual count tracks the economy count because both use the same formula and inputs; the carry phase
## can differ by one golfer, so this is a picture of the club, not an accounting record.
## NOT YET RUN in Godot.
@warning_ignore_start("integer_division")

const DEFAULT_GROUP_SIZE: int = 3
const DEFAULT_INTERVAL_MIN: int = 12
const MAX_QUEUE: int = 16
const MAX_GROUP_SIZE: int = 4

var group_size: int = DEFAULT_GROUP_SIZE
var interval_min: int = DEFAULT_INTERVAL_MIN
var carry_milli: int = 0
var next_serial: int = 0
var next_tee_minute: int = 0
## Waiting groups, oldest first. Each {"serial": int, "size": int}.
var queue: Array = []
var dropped_groups: int = 0


static func from_economy(e: MHEconomy) -> MHSliceSchedule:
	var s: MHSliceSchedule = MHSliceSchedule.new()
	var per_hour: int = maxi(1, e.params.c("tee_groups_per_hour"))
	s.interval_min = clampi(60 / per_hour, 1, 60)
	s.group_size = clampi(e.params.c("tee_group_size_x10") / 10, 1, MAX_GROUP_SIZE)
	return s


## Golfers the economy would accept in game hour `hour_index` (0..10), x1000, from the CURRENT economy state.
## Same formula as MHEconomy.tick_hour before the carried remainder. Read only.
static func hour_golfers_expected_milli(e: MHEconomy, hour_index: int) -> int:
	var dem: int = MHEconomyModel.effect_sum(e.params.eff_dem, e.tiers) + MHEconomyModel.renovation_dem_milli(e.params, e.renovation)
	var arr: int = MHEconomyModel.arrivals_milli(e.params, e.holes, e.rating, dem, e.reputation, e.ext_permille)
	var acc: int = MHEconomyModel.acceptance_permille(e.fee, MHEconomyModel.wtp_cents(e.params, e.rating, e.holes))
	return MHEconomyModel.hour_golfers_milli(e.params, arr, acc, clampi(hour_index, 0, MHEconomyParams.HOURS_PER_DAY - 1))


## Sizes of the groups for `n` golfers: ceil(n / group_size) groups, as even as possible, larger groups first.
static func split_groups(n: int, size_limit: int) -> Array:
	var out: Array = []
	if n <= 0:
		return out
	var lim: int = clampi(size_limit, 1, MAX_GROUP_SIZE)
	var groups: int = (n + lim - 1) / lim
	var base: int = n / groups
	var extra: int = n % groups
	for i: int in range(groups):
		out.append(base + (1 if i < extra else 0))
	return out


## Queues an authoritative whole-golfer count already booked by MHEconomy.
## No demand, acceptance or money is recomputed here.
func add_booked_golfers(count: int, customer_ids: Array = [], booked_minute: int = -1) -> int:
	var whole: int = maxi(0, count)
	var cursor: int = 0
	var booked_at: int = next_tee_minute if booked_minute < 0 else booked_minute
	for size_value: Variant in split_groups(whole, group_size):
		var size: int = int(size_value)
		var ids: Array = []
		for j: int in range(size):
			if cursor + j < customer_ids.size():
				ids.append(int(customer_ids[cursor + j]))
		cursor += size
		# Booked groups are authoritative business traffic: never discard them because a visual queue is busy.
		# MHSliceGolfers has its own rendering caps, so retaining this tiny dictionary queue is cheap.
		queue.append({"serial": next_serial, "size": size, "customer_ids": ids,
			"booked_minute": booked_at})
		next_serial += 1
	return whole


## Legacy milli helper retained for isolated schedule tests/tools. Live play uses add_booked_golfers().
## Adds one game hour of arrivals. Returns the number of whole golfers queued (before queue limits).
func add_hour(milli: int) -> int:
	var total: int = carry_milli + maxi(0, milli)
	var whole: int = total / 1000
	carry_milli = total - whole * 1000
	for size: Variant in split_groups(whole, group_size):
		if queue.size() >= MAX_QUEUE:
			dropped_groups += 1
			continue
		queue.append({"serial": next_serial, "size": int(size)})
		next_serial += 1
	return whole


## Opening groups, picture only: queues the first hour's expected arrivals and, when that is fewer than
## `min_golfers`, enough extra golfers to make up the number, so the first tee is busy in the first real minute.
## Nothing here touches the economy, whose first golfers are booked when the first game hour ends. Returns the
## number of golfers queued.
func prime(first_hour_milli: int, min_golfers: int) -> int:
	var whole: int = add_hour(first_hour_milli)
	var extra: int = min_golfers - whole
	if extra <= 0:
		return whole
	for size: Variant in split_groups(extra, group_size):
		queue.append({"serial": next_serial, "size": int(size)})
		next_serial += 1
	return whole + extra


## Groups that tee off up to `now_minute` (game minutes, MHGameClock.total_minutes()), oldest first.
## Each result is {"serial", "size", "tee_minute"}. Unused tee slots are skipped, never banked.
func release(now_minute: int) -> Array:
	var out: Array = []
	while next_tee_minute <= now_minute:
		if queue.is_empty():
			next_tee_minute = (now_minute / interval_min + 1) * interval_min
			break
		var g: Dictionary = (queue.pop_front() as Dictionary).duplicate()
		g["tee_minute"] = next_tee_minute
		g["wait_minutes"] = maxi(0, next_tee_minute - int(g.get("booked_minute", next_tee_minute)))
		out.append(g)
		next_tee_minute += interval_min
	return out


func waiting_golfers() -> int:
	var n: int = 0
	for g: Variant in queue:
		n += int((g as Dictionary)["size"])
	return n


## Look index (0..pool-1) of golfer `member` in group `serial`. Stateless and deterministic.
static func look_index(serial: int, member: int, pool: int) -> int:
	return MHArtRng.hash2(serial * 131 + 7, member + 1) % maxi(1, pool)

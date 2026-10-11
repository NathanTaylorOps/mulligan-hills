class_name MHGolferPreference
extends RefCounted
## Deterministic customer taste layer over existing rating evidence. No RNG and no economy mutation.

const CASUAL: int = 0
const STRATEGIST: int = 1
const THRILL_SEEKER: int = 2
const PURIST: int = 3
const COUNT: int = 4


static func archetype(serial: int) -> int:
	return posmod(serial, COUNT)


static func name_of(kind: int) -> String:
	match kind:
		CASUAL: return "Casual"
		STRATEGIST: return "Strategist"
		THRILL_SEEKER: return "Thrill-seeker"
		PURIST: return "Purist"
	return "Golfer"


## Preference bonus in satisfaction points, deliberately bounded to +/-12.
## rating is the authoritative MHRatingEngine hole result.
static func bonus(kind: int, rating: Dictionary, round: Dictionary) -> int:
	var beauty: int = int(rating.get("B", 500)) / 10
	var fairness: int = int(rating.get("F", 500)) / 10
	var imagination: int = int(rating.get("I", 500)) / 10
	var elevation: int = int(rating.get("elev", 0)) / 10
	var flags: int = int(round.get("flags", 0))
	var out: int = 0
	match kind:
		CASUAL:
			out = (beauty - 50) / 8 + (fairness - 50) / 6
		STRATEGIST:
			out = (imagination - 50) / 5 + (fairness - 50) / 10
		THRILL_SEEKER:
			out = (imagination - 45) / 6 + elevation / 12
			if flags & 16:
				out += 3
		PURIST:
			out = (fairness - 50) / 5 + (beauty - 50) / 10
			if flags & (1 | 2 | 32):
				out -= 4
	return clampi(out, -12, 12)


static func describe(kind: int, bonus_points: int) -> String:
	var who: String = name_of(kind)
	if bonus_points >= 6:
		return "%s loved how this hole suited their game." % who
	if bonus_points <= -6:
		return "%s disliked this hole's style." % who
	return "%s found the design acceptable." % who

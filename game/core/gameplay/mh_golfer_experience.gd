class_name MHGolferExperience
extends RefCounted
## Deterministic customer-experience score. Integer 0..100; no RNG and no rendering dependency.

static func evaluate(course_rating: int, fee_cents: int, suggested_fee_cents: int,
		amenity_tiers: PackedInt32Array, holes_played: int, wait_minutes: int) -> Dictionary:
	var quality: int = clampi(course_rating, 0, 100)
	var target: int = maxi(100, suggested_fee_cents)
	var price_ratio: int = fee_cents * 100 / target
	var value: int = clampi(120 - maxi(0, price_ratio - 70), 20, 100)
	var amenity_sum: int = 0
	for tier: int in amenity_tiers:
		amenity_sum += tier
	var amenities: int = clampi(45 + amenity_sum * 3, 35, 100)
	var pace: int = clampi(100 - maxi(0, wait_minutes - 5) * 2, 30, 100)
	var completeness: int = clampi(45 + holes_played * 4, 45, 100)
	var score: int = (quality * 35 + value * 25 + amenities * 15 + pace * 15 + completeness * 10) / 100
	score = clampi(score, 0, 100)
	var best_key: String = "course"
	var best: int = quality
	for pair: Array in [["value", value], ["amenities", amenities], ["pace", pace]]:
		if int(pair[1]) > best:
			best_key = str(pair[0]); best = int(pair[1])
	var worst_key: String = "course"
	var worst: int = quality
	for pair: Array in [["value", value], ["amenities", amenities], ["pace", pace]]:
		if int(pair[1]) < worst:
			worst_key = str(pair[0]); worst = int(pair[1])
	return {"score": score, "course": quality, "value": value, "amenities": amenities, "pace": pace,
		"completeness": completeness, "best": best_key, "worst": worst_key, "reaction": reaction(score, best_key, worst_key)}

static func reaction(score: int, best: String, worst: String) -> String:
	if score >= 85:
		return "Loved the course — especially the %s." % best
	if score >= 70:
		return "Good round. The %s stood out." % best
	if score >= 55:
		return "Decent visit, but the %s could be better." % worst
	return "Disappointing round — the %s needs attention." % worst

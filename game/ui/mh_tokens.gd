class_name MHTokens
extends RefCounted
## Pure token arithmetic for the UI. Two balances: earned (from play) and paid (bought).
## Tokens only buy time speed-ups and bankruptcy recovery, never cash or progress (DEC-053).
## ASSUMPTION for the lead to confirm: earned tokens are spent before paid tokens.


static func total(earned: int, paid: int) -> int:
	return maxi(0, earned) + maxi(0, paid)


static func can_afford(earned: int, paid: int, cost: int) -> bool:
	return cost >= 0 and total(earned, paid) >= cost


## Returns {"ok": bool, "earned_used": int, "paid_used": int}. Never spends more than owned.
static func split_spend(earned: int, paid: int, cost: int) -> Dictionary:
	var e: int = maxi(0, earned)
	var p: int = maxi(0, paid)
	if cost < 0 or e + p < cost:
		return {"ok": false, "earned_used": 0, "paid_used": 0}
	var from_earned: int = mini(e, cost)
	return {"ok": true, "earned_used": from_earned, "paid_used": cost - from_earned}

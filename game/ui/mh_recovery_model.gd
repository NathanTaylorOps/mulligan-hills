class_name MHRecoveryModel
extends RefCounted
## Pure options for the bankruptcy recovery dialog (DEC-053): a free bank loan with a reputation penalty,
## or a token-paid recovery plan (earned and paid tokens both count), or carry on. The numbers come from the
## economy through MHGameStateView.recovery_offer(); this class only decides what is tappable.

const OPT_LOAN: String = "loan"
const OPT_TOKENS: String = "tokens"
const OPT_LATER: String = "later"


static func is_active(offer: Dictionary) -> bool:
	return bool(offer.get("active", false))


## Rows {id, enabled, amount, penalty, tokens}. Order is the order shown. "later" is always enabled.
static func options(offer: Dictionary, tokens_total: int) -> Array:
	var out: Array = []
	var loan: int = maxi(0, int(offer.get("loan_amount", 0)))
	var penalty: int = maxi(0, int(offer.get("reputation_penalty", 0)))
	var cost: int = maxi(0, int(offer.get("token_cost", 0)))
	out.append({"id": OPT_LOAN, "enabled": loan > 0, "amount": loan, "penalty": penalty, "tokens": 0})
	out.append({"id": OPT_TOKENS, "enabled": cost > 0 and tokens_total >= cost, "amount": 0, "penalty": 0, "tokens": cost})
	out.append({"id": OPT_LATER, "enabled": true, "amount": 0, "penalty": 0, "tokens": 0})
	return out


## Tokens still missing for the token plan (0 when affordable or no plan is offered).
static func tokens_short(offer: Dictionary, tokens_total: int) -> int:
	var cost: int = maxi(0, int(offer.get("token_cost", 0)))
	return maxi(0, cost - maxi(0, tokens_total))

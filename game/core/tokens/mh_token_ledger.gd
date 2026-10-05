class_name MHTokenLedger
extends RefCounted
## Time-skip tokens (DEC-053). Two separate balances:
##   earned: gameplay rewards, capped at EARNED_CAP.
##   paid:   changed ONLY by apply_validated_purchase / apply_refund (called after the server has validated
##           a receipt; there is no store code in this class).
## Tokens never buy cash or progress, only clock speed-ups and bankruptcy recovery (see docs/phase1/clock_events.md).
## Spend order: earned first, then paid. All integers. Serialisable with to_dict / from_dict.
## Pure logic: no clocks, no randomness, no engine calls.

const EARNED_CAP: int = 999
const PAID_CAP: int = 100000
const MAX_PACK_TOKENS: int = 10000
const MAX_KEYS: int = 256
const MAX_RECEIPTS: int = 500
const SAVE_VERSION: int = 1
const DEFAULT_PATH: String = "user://tokens.json"

const PURCHASE_APPLIED: int = 0
const PURCHASE_DUPLICATE: int = 1
const PURCHASE_INVALID: int = 2

const REFUND_APPLIED: int = 0
const REFUND_ALREADY: int = 1
const REFUND_UNKNOWN: int = 2

var earned: int = 0
var paid: int = 0
## Breakdown of the most recent successful spend (for UI and tests).
var last_spend_earned: int = 0
var last_spend_paid: int = 0

var _keys: PackedStringArray = PackedStringArray()
var _receipt_ids: PackedStringArray = PackedStringArray()
var _receipt_tokens: PackedInt32Array = PackedInt32Array()
var _receipt_refunded: PackedInt32Array = PackedInt32Array()


func total() -> int:
	return earned + paid


## Tokens granted by a reward rule. Unknown rule or param gives 0.
## Rules: daily_login (2), tournament_result (param = finishing place: 1 gives 10, 2 gives 6, 3 gives 4,
## any other place 1), challenge_complete (3), achievement (1).
static func rule_amount(rule_id: String, param: int = 0) -> int:
	if rule_id == "daily_login":
		return 2
	if rule_id == "challenge_complete":
		return 3
	if rule_id == "achievement":
		return 1
	if rule_id == "tournament_result":
		if param < 1:
			return 0
		if param == 1:
			return 10
		if param == 2:
			return 6
		if param == 3:
			return 4
		return 1
	return 0


## Grant an earned reward once per (rule_id, key). Returns tokens actually added (0 for a repeat, an unknown
## rule, an empty key, or a full earned balance). The key must identify the occurrence, for example the UTC day
## number for daily_login, the tournament id for tournament_result, the challenge id for challenge_complete.
func grant_earned(rule_id: String, key: String, param: int = 0) -> int:
	if key.is_empty():
		return 0
	var amount: int = rule_amount(rule_id, param)
	if amount <= 0:
		return 0
	var full_key: String = rule_id + ":" + key
	if _keys.has(full_key):
		return 0
	_keys.append(full_key)
	if _keys.size() > MAX_KEYS:
		_keys.remove_at(0)
	var room: int = EARNED_CAP - earned
	if room <= 0:
		return 0
	var added: int = amount
	if added > room:
		added = room
	earned += added
	return added


func claim_daily_login(utc_day: int) -> int:
	return grant_earned("daily_login", str(utc_day))


func has_key(rule_id: String, key: String) -> bool:
	return _keys.has(rule_id + ":" + key)


## Call only after the server (or the store plugin plus server) validated the receipt. Idempotent per receipt id.
func apply_validated_purchase(receipt_id: String, tokens: int) -> int:
	if receipt_id.is_empty() or tokens <= 0 or tokens > MAX_PACK_TOKENS:
		return PURCHASE_INVALID
	if _receipt_ids.has(receipt_id):
		return PURCHASE_DUPLICATE
	_receipt_ids.append(receipt_id)
	_receipt_tokens.append(tokens)
	_receipt_refunded.append(0)
	if _receipt_ids.size() > MAX_RECEIPTS:
		_receipt_ids.remove_at(0)
		_receipt_tokens.remove_at(0)
		_receipt_refunded.remove_at(0)
	paid += tokens
	if paid > PAID_CAP:
		paid = PAID_CAP
	return PURCHASE_APPLIED


## Reverse a purchase after a store refund. Removes up to the pack size from the paid balance (never below 0;
## tokens already spent cannot be clawed back). Idempotent.
func apply_refund(receipt_id: String) -> int:
	var idx: int = _receipt_ids.find(receipt_id)
	if idx < 0:
		return REFUND_UNKNOWN
	if _receipt_refunded[idx] != 0:
		return REFUND_ALREADY
	_receipt_refunded[idx] = 1
	var take: int = _receipt_tokens[idx]
	if take > paid:
		take = paid
	paid -= take
	return REFUND_APPLIED


func has_receipt(receipt_id: String) -> bool:
	return _receipt_ids.has(receipt_id)


func can_spend(amount: int) -> bool:
	return amount > 0 and total() >= amount


## Atomic: spends exactly `amount` (earned first, then paid) or nothing.
func spend(amount: int) -> bool:
	if not can_spend(amount):
		return false
	_take(amount)
	return true


## Spends up to `amount`, returns how many were spent (0 when empty). Used by the clock's prepaid credit.
func spend_up_to(amount: int) -> int:
	if amount <= 0:
		return 0
	var n: int = amount
	if n > total():
		n = total()
	if n <= 0:
		return 0
	_take(n)
	return n


func _take(n: int) -> void:
	var from_earned: int = n
	if from_earned > earned:
		from_earned = earned
	var from_paid: int = n - from_earned
	earned -= from_earned
	paid -= from_paid
	last_spend_earned = from_earned
	last_spend_paid = from_paid


func to_dict() -> Dictionary:
	var receipts: Array = []
	for i in range(_receipt_ids.size()):
		receipts.append({"id": _receipt_ids[i], "tokens": _receipt_tokens[i], "refunded": _receipt_refunded[i]})
	var keys: Array = []
	for k in _keys:
		keys.append(k)
	return {
		"v": SAVE_VERSION,
		"earned": earned,
		"paid": paid,
		"keys": keys,
		"receipts": receipts,
	}


## Restores from to_dict output (JSON round trip safe). Returns false and leaves the ledger untouched if invalid.
func from_dict(d: Dictionary) -> bool:
	if not d.has("earned") or not d.has("paid"):
		return false
	var e: int = int(d["earned"])
	var p: int = int(d["paid"])
	if e < 0 or p < 0 or e > EARNED_CAP or p > PAID_CAP:
		return false
	var new_keys: PackedStringArray = PackedStringArray()
	var keys_v: Variant = d.get("keys", [])
	if typeof(keys_v) != TYPE_ARRAY:
		return false
	for k in (keys_v as Array):
		new_keys.append(str(k))
	var ids: PackedStringArray = PackedStringArray()
	var toks: PackedInt32Array = PackedInt32Array()
	var refs: PackedInt32Array = PackedInt32Array()
	var rec_v: Variant = d.get("receipts", [])
	if typeof(rec_v) != TYPE_ARRAY:
		return false
	for r in (rec_v as Array):
		if typeof(r) != TYPE_DICTIONARY:
			return false
		var rd: Dictionary = r as Dictionary
		if not rd.has("id") or not rd.has("tokens"):
			return false
		ids.append(str(rd["id"]))
		toks.append(int(rd["tokens"]))
		refs.append(1 if int(rd.get("refunded", 0)) != 0 else 0)
	earned = e
	paid = p
	_keys = new_keys
	_receipt_ids = ids
	_receipt_tokens = toks
	_receipt_refunded = refs
	last_spend_earned = 0
	last_spend_paid = 0
	return true


## The ledger is NOT part of a save slot (saves never hold tokens, so a cloud or imported save cannot grant any).
## It lives in its own crash-safe file. Returns OK or an error code.
func save_to(path: String = DEFAULT_PATH) -> int:
	return MHJsonFile.write_dict(path, to_dict())


## Loads from its own file. A missing file is normal on first launch (ledger stays empty and the result is NOT_FOUND).
## A damaged main file falls back to the .bak. Returns the MHSaveResult of the read.
func load_from(path: String = DEFAULT_PATH) -> MHSaveResult:
	var r: MHSaveResult = MHJsonFile.read_dict(path)
	if r.is_ok():
		if not from_dict(r.value as Dictionary):
			return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, "token ledger file is invalid")
	return r

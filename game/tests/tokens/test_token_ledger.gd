extends GdUnitTestSuite
## MHTokenLedger: earned vs paid, spend order, idempotent validated purchases, refunds, caps, persistence.
## NOT YET RUN in Godot.

const Fixture = preload("res://tests/save/save_fixture.gd")
const PATH: String = "user://mh_test_tokens/tokens.json"


func after_test() -> void:
	MHJsonFile.delete_all(PATH)
	var d: DirAccess = DirAccess.open("user://")
	if d != null:
		d.remove("mh_test_tokens")


func test_starts_empty() -> void:
	var l := MHTokenLedger.new()
	assert_int(l.earned).is_equal(0)
	assert_int(l.paid).is_equal(0)
	assert_int(l.total()).is_equal(0)
	assert_bool(l.can_spend(1)).is_false()
	assert_bool(l.spend(1)).is_false()


func test_reward_rule_amounts() -> void:
	assert_int(MHTokenLedger.rule_amount("daily_login")).is_equal(2)
	assert_int(MHTokenLedger.rule_amount("challenge_complete")).is_equal(3)
	assert_int(MHTokenLedger.rule_amount("achievement")).is_equal(1)
	assert_int(MHTokenLedger.rule_amount("tournament_result", 1)).is_equal(10)
	assert_int(MHTokenLedger.rule_amount("tournament_result", 2)).is_equal(6)
	assert_int(MHTokenLedger.rule_amount("tournament_result", 3)).is_equal(4)
	assert_int(MHTokenLedger.rule_amount("tournament_result", 17)).is_equal(1)
	assert_int(MHTokenLedger.rule_amount("tournament_result", 0)).is_equal(0)
	assert_int(MHTokenLedger.rule_amount("buy_cash")).is_equal(0)


func test_earned_grants_are_once_per_key() -> void:
	var l := MHTokenLedger.new()
	assert_int(l.claim_daily_login(20000)).is_equal(2)
	assert_int(l.claim_daily_login(20000)).is_equal(0)
	assert_int(l.claim_daily_login(20001)).is_equal(2)
	assert_int(l.grant_earned("challenge_complete", "c1")).is_equal(3)
	assert_int(l.grant_earned("challenge_complete", "c1")).is_equal(0)
	assert_int(l.grant_earned("challenge_complete", "")).is_equal(0)
	assert_int(l.grant_earned("unknown_rule", "x")).is_equal(0)
	assert_int(l.earned).is_equal(7)
	assert_int(l.paid).is_equal(0)
	assert_bool(l.has_key("daily_login", "20000")).is_true()
	assert_bool(l.has_key("daily_login", "29999")).is_false()


func test_earned_balance_is_capped() -> void:
	var l := MHTokenLedger.new()
	l.earned = MHTokenLedger.EARNED_CAP - 1
	assert_int(l.grant_earned("tournament_result", "t1", 1)).is_equal(1)
	assert_int(l.earned).is_equal(MHTokenLedger.EARNED_CAP)
	assert_int(l.grant_earned("tournament_result", "t2", 1)).is_equal(0)
	assert_int(l.earned).is_equal(MHTokenLedger.EARNED_CAP)


func test_purchase_is_idempotent_per_receipt_id() -> void:
	var l := MHTokenLedger.new()
	assert_int(l.apply_validated_purchase("rcpt-1", 50)).is_equal(MHTokenLedger.PURCHASE_APPLIED)
	assert_int(l.paid).is_equal(50)
	assert_int(l.apply_validated_purchase("rcpt-1", 50)).is_equal(MHTokenLedger.PURCHASE_DUPLICATE)
	assert_int(l.apply_validated_purchase("rcpt-1", 500)).is_equal(MHTokenLedger.PURCHASE_DUPLICATE)
	assert_int(l.paid).is_equal(50)
	assert_int(l.apply_validated_purchase("rcpt-2", 120)).is_equal(MHTokenLedger.PURCHASE_APPLIED)
	assert_int(l.paid).is_equal(170)
	assert_int(l.earned).is_equal(0)
	assert_bool(l.has_receipt("rcpt-2")).is_true()
	assert_bool(l.has_receipt("rcpt-3")).is_false()


func test_invalid_purchases_change_nothing() -> void:
	var l := MHTokenLedger.new()
	assert_int(l.apply_validated_purchase("", 50)).is_equal(MHTokenLedger.PURCHASE_INVALID)
	assert_int(l.apply_validated_purchase("r", 0)).is_equal(MHTokenLedger.PURCHASE_INVALID)
	assert_int(l.apply_validated_purchase("r", -5)).is_equal(MHTokenLedger.PURCHASE_INVALID)
	assert_int(l.apply_validated_purchase("r", MHTokenLedger.MAX_PACK_TOKENS + 1)).is_equal(MHTokenLedger.PURCHASE_INVALID)
	assert_int(l.paid).is_equal(0)
	assert_bool(l.has_receipt("r")).is_false()


func test_spend_takes_earned_first_then_paid() -> void:
	var l := MHTokenLedger.new()
	l.earned = 3
	l.paid = 10
	assert_bool(l.spend(2)).is_true()
	assert_int(l.earned).is_equal(1)
	assert_int(l.paid).is_equal(10)
	assert_int(l.last_spend_earned).is_equal(2)
	assert_int(l.last_spend_paid).is_equal(0)
	assert_bool(l.spend(4)).is_true()
	assert_int(l.earned).is_equal(0)
	assert_int(l.paid).is_equal(7)
	assert_int(l.last_spend_earned).is_equal(1)
	assert_int(l.last_spend_paid).is_equal(3)


func test_spend_is_atomic() -> void:
	var l := MHTokenLedger.new()
	l.earned = 2
	l.paid = 1
	assert_bool(l.spend(4)).is_false()
	assert_int(l.earned).is_equal(2)
	assert_int(l.paid).is_equal(1)
	assert_bool(l.spend(0)).is_false()
	assert_bool(l.spend(-1)).is_false()
	assert_bool(l.spend(3)).is_true()
	assert_int(l.total()).is_equal(0)


func test_spend_up_to() -> void:
	var l := MHTokenLedger.new()
	l.earned = 1
	l.paid = 1
	assert_int(l.spend_up_to(5)).is_equal(2)
	assert_int(l.total()).is_equal(0)
	assert_int(l.spend_up_to(5)).is_equal(0)
	assert_int(l.spend_up_to(0)).is_equal(0)


func test_refund_is_idempotent_and_cannot_go_below_zero() -> void:
	var l := MHTokenLedger.new()
	l.apply_validated_purchase("rcpt-1", 50)
	assert_bool(l.spend(30)).is_true()
	assert_int(l.apply_refund("rcpt-1")).is_equal(MHTokenLedger.REFUND_APPLIED)
	assert_int(l.paid).is_equal(0)
	assert_int(l.apply_refund("rcpt-1")).is_equal(MHTokenLedger.REFUND_ALREADY)
	assert_int(l.apply_refund("nope")).is_equal(MHTokenLedger.REFUND_UNKNOWN)
	# a refunded receipt id can never be re-applied
	assert_int(l.apply_validated_purchase("rcpt-1", 50)).is_equal(MHTokenLedger.PURCHASE_DUPLICATE)
	assert_int(l.paid).is_equal(0)


func test_refund_never_touches_earned_tokens() -> void:
	var l := MHTokenLedger.new()
	l.earned = 20
	l.apply_validated_purchase("rcpt-1", 10)
	l.apply_refund("rcpt-1")
	assert_int(l.earned).is_equal(20)
	assert_int(l.paid).is_equal(0)


func test_paid_cap() -> void:
	var l := MHTokenLedger.new()
	l.paid = MHTokenLedger.PAID_CAP - 5
	assert_int(l.apply_validated_purchase("big", 100)).is_equal(MHTokenLedger.PURCHASE_APPLIED)
	assert_int(l.paid).is_equal(MHTokenLedger.PAID_CAP)


func test_tokens_never_buy_cash() -> void:
	# the ledger has no cash API at all: its public surface is balances, grants, purchases, refunds and spend
	var l := MHTokenLedger.new()
	assert_bool(l.has_method("add_cash")).is_false()
	assert_bool(l.has_method("buy_cash")).is_false()
	assert_bool(l.has_method("apply_validated_purchase")).is_true()


func test_json_round_trip_keeps_idempotency_and_balances() -> void:
	var l := MHTokenLedger.new()
	l.claim_daily_login(20000)
	l.apply_validated_purchase("rcpt-1", 50)
	l.apply_validated_purchase("rcpt-2", 10)
	l.apply_refund("rcpt-2")
	var parsed: Variant = JSON.parse_string(JSON.stringify(l.to_dict()))
	var back := MHTokenLedger.new()
	assert_bool(back.from_dict(parsed as Dictionary)).is_true()
	assert_int(back.earned).is_equal(2)
	assert_int(back.paid).is_equal(50)
	assert_int(back.claim_daily_login(20000)).is_equal(0)
	assert_int(back.apply_validated_purchase("rcpt-1", 50)).is_equal(MHTokenLedger.PURCHASE_DUPLICATE)
	assert_int(back.apply_refund("rcpt-2")).is_equal(MHTokenLedger.REFUND_ALREADY)
	assert_bool(back.to_dict() == l.to_dict()).is_true()


func test_from_dict_rejects_bad_data_and_leaves_ledger_alone() -> void:
	var l := MHTokenLedger.new()
	l.earned = 5
	assert_bool(l.from_dict({})).is_false()
	assert_bool(l.from_dict({"earned": -1, "paid": 0})).is_false()
	assert_bool(l.from_dict({"earned": 0, "paid": MHTokenLedger.PAID_CAP + 1})).is_false()
	assert_bool(l.from_dict({"earned": MHTokenLedger.EARNED_CAP + 1, "paid": 0})).is_false()
	assert_bool(l.from_dict({"earned": 0, "paid": 0, "keys": "x"})).is_false()
	assert_bool(l.from_dict({"earned": 0, "paid": 0, "receipts": [5]})).is_false()
	assert_int(l.earned).is_equal(5)


func test_ledger_file_round_trip_and_first_launch() -> void:
	var l := MHTokenLedger.new()
	assert_int(l.load_from(PATH).code).is_equal(MHSaveResult.Code.NOT_FOUND)
	assert_int(l.total()).is_equal(0)
	l.earned = 7
	l.apply_validated_purchase("rcpt-1", 25)
	assert_int(l.save_to(PATH)).is_equal(OK)
	var back := MHTokenLedger.new()
	assert_bool(back.load_from(PATH).is_ok()).is_true()
	assert_int(back.earned).is_equal(7)
	assert_int(back.paid).is_equal(25)
	assert_bool(back.has_receipt("rcpt-1")).is_true()


func test_ledger_is_not_part_of_a_save_document() -> void:
	var doc: Dictionary = Fixture.make_doc()
	MHSaveGame.seal(doc)
	assert_bool(MHSaveGame.validate(doc).is_empty()).is_true()
	doc["tokens"] = {"earned": 5, "paid": 9999}
	assert_bool(MHSaveGame.validate(doc).is_empty()).is_false()
	var doc2: Dictionary = Fixture.make_doc()
	doc2["token"] = 5
	assert_bool(MHSaveGame.validate(doc2).is_empty()).is_false()

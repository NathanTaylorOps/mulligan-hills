extends GdUnitTestSuite


func _hole() -> Dictionary:
	return {"slot_id": 0, "tee": [0, 0], "green": [0, 120, 5],
		"features": [{"t": "fairway", "rect": [-14, 0, 14, 120]}]}


func test_queue_never_changes_customer_payment_values() -> void:
	var q: MHCustomerRoundQueue = MHCustomerRoundQueue.new()
	var paid: Dictionary = {"serial": 7, "paid_fee": 4200, "ancillary": 900, "admitted_day": 1, "admitted_hour": 3, "hole_slot": 0}
	q.admit([paid], _hole(), {"save_secret": 55, "rating_epoch": 0})
	assert_int(q.waiting.size()).is_equal(1)
	var queued: Dictionary = q.waiting[0]
	assert_int(int(queued["paid_fee"])).is_equal(4200)
	assert_int(int(queued["ancillary"])).is_equal(900)


func test_customer_starts_finishes_and_frees_tee() -> void:
	var q: MHCustomerRoundQueue = MHCustomerRoundQueue.new()
	var rows: Array = [
		{"serial": 0, "paid_fee": 4000, "ancillary": 500},
		{"serial": 1, "paid_fee": 4000, "ancillary": 500},
	]
	q.admit(rows, _hole(), {"save_secret": 123, "rating_epoch": 0})
	var started: Dictionary = q.advance(0.0)
	assert_str(str(started["kind"])).is_equal("started")
	assert_bool(q.active.is_empty()).is_false()
	var round: Dictionary = q.active["round"]
	var finish_at: float = MHCustomerRoundQueue.TEE_INTERVAL_S + MHAIRoundTimeline.total_duration(round["events"] as Array) + 1.0
	var finished: Dictionary = q.advance(finish_at)
	assert_str(str(finished["kind"])).is_equal("finished")
	assert_bool(q.active.is_empty()).is_true()
	assert_int(q.completed.size()).is_equal(1)
	assert_bool(int((q.completed[0] as Dictionary)["satisfaction"]) >= 0).is_true()
	var second: Dictionary = q.advance(finish_at + 0.01)
	assert_str(str(second["kind"])).is_equal("started")
	assert_int(int((second["customer"] as Dictionary)["serial"])).is_equal(1)


func test_satisfaction_reacts_to_penalties_and_pickup() -> void:
	var clean: int = MHCustomerRoundQueue.satisfaction({"strokes": 3, "flags": 0})
	var penalty: int = MHCustomerRoundQueue.satisfaction({"strokes": 3, "flags": 32})
	var pickup: int = MHCustomerRoundQueue.satisfaction({"strokes": 7, "flags": 4})
	assert_bool(clean > penalty).is_true()
	assert_bool(penalty > pickup).is_true()
	assert_str(MHCustomerRoundQueue.reaction(clean, 0)).contains("play that again")

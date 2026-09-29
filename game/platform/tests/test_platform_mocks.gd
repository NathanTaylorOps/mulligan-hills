extends GdUnitTestSuite
## Tests the mock implementations and the interface contract (signals, hooks). NOT YET RUN.

func _ent() -> MHEntitlementServiceMock:
	var e: MHEntitlementServiceMock = auto_free(MHEntitlementServiceMock.new())
	add_child(e)
	return e

func test_demo_is_locked_by_default() -> void:
	var e: MHEntitlementServiceMock = _ent()
	e.initialize()
	assert_bool(e.is_unlocked()).is_false()
	assert_int(e.query_owned_products().size()).is_equal(0)

func test_purchase_unlocks_and_emits() -> void:
	var e: MHEntitlementServiceMock = _ent()
	var changed: Array = []
	e.entitlement_changed.connect(func(u: bool) -> void: changed.append(u))
	e.purchase(MHPlatformConfig.PRODUCT_UNLOCK)
	assert_bool(e.is_unlocked()).is_true()
	assert_array(changed).is_equal([true])
	assert_bool(e.query_owned_products().has(MHPlatformConfig.PRODUCT_UNLOCK)).is_true()

func test_canceled_purchase_does_not_unlock() -> void:
	var e: MHEntitlementServiceMock = _ent()
	e.next_purchase_result = MHEntitlementService.PurchaseResult.CANCELED
	e.purchase(MHPlatformConfig.PRODUCT_UNLOCK)
	assert_bool(e.is_unlocked()).is_false()

func test_unknown_product_errors() -> void:
	var e: MHEntitlementServiceMock = _ent()
	e.purchase("something_else")
	assert_bool(e.is_unlocked()).is_false()

func test_restore_hook() -> void:
	var e: MHEntitlementServiceMock = _ent()
	e.restore()
	assert_int(e.restore_calls).is_equal(1)
	assert_bool(e.is_unlocked()).is_true()

func test_restore_nothing_found() -> void:
	var e: MHEntitlementServiceMock = _ent()
	e.restore_finds_purchase = false
	e.restore()
	assert_bool(e.is_unlocked()).is_false()

func test_account_deletion_keeps_entitlement_by_default() -> void:
	var e: MHEntitlementServiceMock = _ent()
	e.purchase(MHPlatformConfig.PRODUCT_UNLOCK)
	e.on_account_deleted(false)
	assert_bool(e.is_unlocked()).is_true()
	e.on_account_deleted(true)
	assert_bool(e.is_unlocked()).is_false()
	assert_int(e.account_deleted_calls).is_equal(2)

func test_integrity_mock() -> void:
	var i: MHIntegrityServiceMock = MHIntegrityServiceMock.new()
	add_child(i)
	var r: Dictionary = await i.request_token("h")
	assert_bool(bool(r["ok"])).is_true()
	assert_str(i.last_request_hash).is_equal("h")
	i.fail_next = true
	r = await i.request_token("h2")
	assert_bool(bool(r["ok"])).is_false()

func test_leaderboard_requires_sign_in() -> void:
	var l: MHLeaderboardServiceMock = MHLeaderboardServiceMock.new()
	add_child(l)
	l.submit_score("b", 5)
	assert_int(l.submitted.size()).is_equal(0)
	l.sign_in()
	l.submit_score("b", 5)
	assert_int(l.submitted.size()).is_equal(1)

func test_notifications_need_permission() -> void:
	var n: MHNotificationServiceMock = MHNotificationServiceMock.new()
	add_child(n)
	n.schedule(1, "t", "b", 5)
	assert_int(n.scheduled.size()).is_equal(0)
	n.request_permission()
	n.schedule(1, "t", "b", 5)
	assert_int(n.scheduled.size()).is_equal(1)
	n.cancel_all()
	assert_int(n.scheduled.size()).is_equal(0)

func test_analytics_respects_consent_and_reset() -> void:
	var a: MHAnalyticsServiceMock = MHAnalyticsServiceMock.new()
	add_child(a)
	a.log_event("x")
	assert_int(a.events.size()).is_equal(0)
	a.set_enabled(true)
	a.log_event("x", {"k": 1})
	a.set_user_property("p", "v")
	assert_int(a.events.size()).is_equal(1)
	a.reset_identity()
	assert_int(a.properties.size()).is_equal(0)

func test_factory_returns_mocks_on_desktop() -> void:
	assert_bool(MHPlatform.use_mocks()).is_true()
	assert_bool(MHPlatform.create_entitlement() is MHEntitlementServiceMock).is_true()

func test_account_deletion_helper() -> void:
	var e: MHEntitlementServiceMock = _ent()
	var a: MHAnalyticsServiceMock = MHAnalyticsServiceMock.new()
	add_child(a)
	MHPlatform.on_account_deleted(e, a, false)
	assert_int(a.reset_calls).is_equal(1)
	assert_int(e.account_deleted_calls).is_equal(1)

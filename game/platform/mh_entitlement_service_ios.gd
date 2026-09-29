class_name MHEntitlementServiceIOS
extends MHEntitlementService
## Adapter: Godot's official iOS `InAppStore` singleton (godot-sdk-integrations/godot-ios-plugins,
## plugins/inappstore). API taken from its README (fetched 2026-09-29):
##   request_product_info({"product_ids": [..]}), purchase({"product_id": id}), restore_purchases(),
##   set_auto_finish_transaction(bool), finish_transaction(product_id), get_pending_event_count(), pop_pending_event()
##   Events (polled): {type: product_info|purchase|restore|completed, result: ok|progress|error|unhandled|completed, ...}
##   purchase/restore events carry product_id, transaction_id, receipt.
## The README does not state StoreKit 1 vs 2 or a Godot version: UNVERIFIED. This is a Phase 0 DESIGN adapter:
## the server side (Apple App Store Server API verification, function `verify-apple`) is NOT built yet.
## Until it is, this adapter only exercises the store flow and reports VERIFY_FAILED with "server_not_implemented".

const SINGLETON: String = "InAppStore"
var _store: Object = null
var _poll_accum: float = 0.0
var _price: String = ""
var _restoring: bool = false

func initialize() -> void:
	_load_cache()
	if not Engine.has_singleton(SINGLETON):
		push_warning("InAppStore singleton not present; cached entitlement only")
		return
	_store = Engine.get_singleton(SINGLETON)
	_store.call("set_auto_finish_transaction", false)
	_store.call("request_product_info", {"product_ids": [MHPlatformConfig.PRODUCT_UNLOCK]})
	set_process(true)

func _process(delta: float) -> void:
	if _store == null:
		return
	_poll_accum += delta
	if _poll_accum < 0.25:
		return
	_poll_accum = 0.0
	while int(_store.call("get_pending_event_count")) > 0:
		_on_event(_store.call("pop_pending_event") as Dictionary)

func query_owned_products() -> PackedStringArray:
	return _owned_from_cache()

func purchase(product_id: String) -> void:
	if _store == null:
		purchase_finished.emit(product_id, PurchaseResult.UNAVAILABLE, "store_unavailable")
		return
	_store.call("purchase", {"product_id": product_id})

func restore() -> void:
	if _store == null:
		restore_finished.emit(false, "store_unavailable")
		return
	_restoring = true
	_store.call("restore_purchases")

func get_display_price(product_id: String) -> String:
	return _price

func _on_event(e: Dictionary) -> void:
	var t: String = str(e.get("type", ""))
	var result: String = str(e.get("result", ""))
	match t:
		"product_info":
			var prices: Array = e.get("localized_prices", []) as Array
			if prices.size() > 0:
				_price = str(prices[0])
		"purchase", "restore":
			if result == "ok" and str(e.get("product_id", "")) == MHPlatformConfig.PRODUCT_UNLOCK:
				_on_transaction(e)
			elif result == "error":
				purchase_finished.emit(MHPlatformConfig.PRODUCT_UNLOCK, PurchaseResult.ERROR, str(e.get("message", "error")))
		"completed":
			if _restoring:
				_restoring = false
				restore_finished.emit(_unlocked, "completed")

func _on_transaction(e: Dictionary) -> void:
	# TODO(ios-server): POST {transaction_id, receipt} to verify-apple, adopt the signed token, then
	# finish_transaction(product_id). Not implemented in Phase 0.
	purchase_finished.emit(MHPlatformConfig.PRODUCT_UNLOCK, PurchaseResult.VERIFY_FAILED, "server_not_implemented")

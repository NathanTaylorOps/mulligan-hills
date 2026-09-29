class_name MHEntitlementServiceMock
extends MHEntitlementService
## Used by tests and desktop/editor builds. No store, no network. Deterministic.
## Configure behaviour with the public vars before calling purchase()/restore().

var next_purchase_result: int = MHEntitlementService.PurchaseResult.OK
var restore_finds_purchase: bool = true
var price_text: String = "$4.99"
var use_disk_cache: bool = false  # tests keep this false so they never touch user://
var purchase_calls: int = 0
var restore_calls: int = 0
var account_deleted_calls: int = 0

func initialize() -> void:
	if use_disk_cache:
		_load_cache()

func query_owned_products() -> PackedStringArray:
	var ids: PackedStringArray = _owned_from_cache()
	owned_products_updated.emit(ids)
	return ids

func purchase(product_id: String) -> void:
	purchase_calls += 1
	if product_id != MHPlatformConfig.PRODUCT_UNLOCK:
		purchase_finished.emit(product_id, PurchaseResult.ERROR, "unknown product")
		return
	if next_purchase_result == PurchaseResult.OK:
		_set_unlocked(true)
	purchase_finished.emit(product_id, next_purchase_result, "mock")

func restore() -> void:
	restore_calls += 1
	if restore_finds_purchase:
		_set_unlocked(true)
	restore_finished.emit(restore_finds_purchase, "mock")

func get_display_price(product_id: String) -> String:
	return price_text

func on_account_deleted(clear_entitlement: bool = false) -> void:
	account_deleted_calls += 1
	if clear_entitlement:
		_unlocked = false
		_token = ""
		_payload = {}
		entitlement_changed.emit(false)

## Test helper: adopt a real signed token (e.g. the golden vector) using a supplied public key.
func inject_token_for_test(token: String, public_key_pem: String) -> bool:
	var res: Dictionary = MHEntitlementToken.verify(
		token, public_key_pem, MHPlatformConfig.PACKAGE_NAME, MHPlatformConfig.PRODUCT_UNLOCK)
	if not bool(res["ok"]):
		return false
	_token = token
	_payload = res["payload"]
	_set_unlocked(true)
	return true

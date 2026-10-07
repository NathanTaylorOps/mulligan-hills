class_name MHEntitlementServiceAndroid
extends MHEntitlementService
## Adapter: official Godot Google Play Billing plugin (godot-sdk-integrations/godot-google-play-billing,
## 3.x line, class-based `BillingClient`, Play Billing Library 8+/9 as of 2026).
##
## EVERYTHING that touches the plugin is in the "PLUGIN SEAM" section so a wrong name is a 1-line fix.
## Plugin names below come from public docs but the exact method/signal parameter lists could NOT be
## confirmed (docs pages did not render). Marked UNVERIFIED in docs/phase0/platform.md. The Gate 0
## device check must run this against the real addon.
##
## Flow: purchase -> (plugin) on_purchase_updated -> server verify (Play Developer API + Play Integrity)
##       -> signed token cached -> acknowledge purchase (within 3 days or Google refunds).

const SINGLETON: String = "GodotGooglePlayBilling"  # UNVERIFIED: the native singleton the addon wraps
const BILLING_CLIENT_SCRIPT: String = "res://addons/GodotGooglePlayBilling/BillingClient.gd"  # UNVERIFIED path
const RESPONSE_OK: int = 0        # BillingClient.BillingResponseCode.OK
const RESPONSE_USER_CANCELED: int = 1
const PURCHASE_STATE_PURCHASED: int = 1  # UNVERIFIED enum value naming; Play API: 0 unspecified, 1 purchased, 2 pending

var _client: Object = null
var _connected: bool = false
var _api: MHVerifyApi = null
var _integrity: MHIntegrityService = null
var _price: String = ""
var _pending_restore: bool = false
var _busy_tokens: Dictionary = {}  # purchase_token -> true while verifying (dedupe)
signal _owned_refreshed()

## integrity may be null (then the server must be configured not to require it: NOT recommended for release).
func attach_integrity(integrity: MHIntegrityService) -> void:
	_integrity = integrity

func initialize() -> void:
	_load_cache()
	if _api == null:
		_api = MHVerifyApi.new()
		add_child(_api)
	if not _plugin_available():
		push_warning("Google Play Billing plugin not present; running with cached entitlement only")
		return
	_client = _seam_create_client()
	if _client == null:
		return
	if _client is Node:
		add_child(_client as Node)
	_seam_connect_signals()
	_client.call("start_connection")

func query_owned_products() -> PackedStringArray:
	if _connected:
		_seam_query_purchases()
		await _owned_refreshed
	return _owned_from_cache()

func purchase(product_id: String) -> void:
	if not _connected:
		purchase_finished.emit(product_id, PurchaseResult.UNAVAILABLE, "store_not_connected")
		return
	var launch: Dictionary = _seam_purchase(product_id)
	if int(launch.get("response_code", RESPONSE_OK)) != RESPONSE_OK:
		purchase_finished.emit(product_id, PurchaseResult.ERROR,
			str(launch.get("debug_message", "billing_flow_launch_failed")))

func restore() -> void:
	# Google has no "restore" call: querying owned purchases IS the restore.
	if not _connected:
		restore_finished.emit(false, "store_not_connected")
		return
	_pending_restore = true
	_seam_query_purchases()

func get_display_price(product_id: String) -> String:
	return _price

# ---- verification pipeline -------------------------------------------------------------------

func _handle_owned_purchase(p: Dictionary) -> void:
	var token: String = _seam_purchase_token(p)
	if token == "" or _busy_tokens.has(token):
		return
	if _cached_entitlement_is_fresh():
		if not _seam_is_acknowledged(p):
			_seam_acknowledge(token)
		if _pending_restore:
			_pending_restore = false
			restore_finished.emit(true, "restored")
		return
	_busy_tokens[token] = true
	var integrity_token: String = ""
	if _integrity != null and _integrity.is_supported():
		var h: String = MHIntegrityService.request_hash(PackedStringArray([
			MHPlatformConfig.PACKAGE_NAME, MHPlatformConfig.PRODUCT_UNLOCK, token]))
		var ir: Dictionary = await _integrity.request_token(h)
		if bool(ir["ok"]):
			integrity_token = str(ir["token"])
	var res: Dictionary = await _api.verify_purchase(MHPlatformConfig.PRODUCT_UNLOCK, token, integrity_token)
	_busy_tokens.erase(token)
	if bool(res["ok"]) and _apply_token(str((res["body"] as Dictionary).get("entitlement", ""))):
		if not _seam_is_acknowledged(p):
			_seam_acknowledge(token)
		purchase_finished.emit(MHPlatformConfig.PRODUCT_UNLOCK, PurchaseResult.OK, "verified")
		if _pending_restore:
			_pending_restore = false
			restore_finished.emit(true, "restored")
	else:
		# Network failure keeps the purchase in Play; next launch re-queries and retries.
		purchase_finished.emit(MHPlatformConfig.PRODUCT_UNLOCK, PurchaseResult.VERIFY_FAILED, str(res["error"]))

## A valid cached entitlement is deliberately not re-verified on every Play ownership query. The signed token
## remains valid offline; its ref field is the server's soft refresh time.
func _cached_entitlement_is_fresh(now_unix: int = -1) -> bool:
	if not is_unlocked() or _token == "":
		return false
	var now: int = now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	return not MHEntitlementToken.needs_refresh(_payload, now)


# ---- signal handlers (plugin -> our signals) -------------------------------------------------

func _on_connected() -> void:
	_connected = true
	_seam_query_product_details()
	_seam_query_purchases()

func _on_disconnected() -> void:
	_connected = false

func _on_purchase_updated(response: Dictionary) -> void:
	var code: int = int(response.get("response_code", -1))
	if code == RESPONSE_USER_CANCELED:
		purchase_finished.emit(MHPlatformConfig.PRODUCT_UNLOCK, PurchaseResult.CANCELED, "canceled")
		return
	if code != RESPONSE_OK:
		purchase_finished.emit(MHPlatformConfig.PRODUCT_UNLOCK, PurchaseResult.ERROR, str(response.get("debug_message", "error")))
		return
	_process_purchases(response.get("purchases", []) as Array)

func _on_query_purchases_response(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) == RESPONSE_OK:
		_process_purchases(response.get("purchases", []) as Array)
	elif _pending_restore:
		_pending_restore = false
		restore_finished.emit(false, str(response.get("debug_message", "query_failed")))
	_owned_refreshed.emit()

func _on_query_product_details_response(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != RESPONSE_OK:
		return
	for d: Variant in (response.get("product_details", []) as Array):
		var dd: Dictionary = d as Dictionary
		if str(dd.get("product_id", "")) == MHPlatformConfig.PRODUCT_UNLOCK:
			_price = _seam_price_from_details(dd)

func _process_purchases(purchases: Array) -> void:
	var found: bool = false
	for p: Variant in purchases:
		var pd: Dictionary = p as Dictionary
		if _seam_product_ids(pd).has(MHPlatformConfig.PRODUCT_UNLOCK):
			if int(pd.get("purchase_state", -1)) == PURCHASE_STATE_PURCHASED:
				found = true
				_handle_owned_purchase(pd)
			else:
				purchase_finished.emit(MHPlatformConfig.PRODUCT_UNLOCK, PurchaseResult.PENDING, "pending")
	if _pending_restore and not found:
		_pending_restore = false
		restore_finished.emit(false, "nothing_to_restore")

# ==================================== PLUGIN SEAM (UNVERIFIED) ===================================

func _plugin_available() -> bool:
	return Engine.has_singleton(SINGLETON) and ResourceLoader.exists(BILLING_CLIENT_SCRIPT)

func _seam_create_client() -> Object:
	var script: Script = load(BILLING_CLIENT_SCRIPT) as Script
	if script == null:
		return null
	return script.call("new") as Object

func _seam_connect_signals() -> void:
	# Signal names: `connected` and `on_purchase_updated` appear in the plugin docs; the rest are UNVERIFIED.
	var pairs: Array = [
		["connected", _on_connected],
		["disconnected", _on_disconnected],
		["on_purchase_updated", _on_purchase_updated],
		["query_purchases_response", _on_query_purchases_response],
		["query_product_details_response", _on_query_product_details_response],
	]
	for pair: Array in pairs:
		if _client.has_signal(pair[0]):
			_client.connect(pair[0], pair[1])
		else:
			push_warning("Billing plugin lacks signal '%s' (see platform.md Unverified)" % pair[0])

func _seam_query_product_details() -> void:
	# Product type enum BillingClient.ProductType.INAPP appears in the plugin docs; arg order is UNVERIFIED.
	_client.call("query_product_details", [MHPlatformConfig.PRODUCT_UNLOCK], _seam_inapp_type())

func _seam_query_purchases() -> void:
	_client.call("query_purchases", _seam_inapp_type())

func _seam_inapp_type() -> Variant:
	# Resolve BillingClient.ProductType.INAPP dynamically; fall back to 0 (UNVERIFIED).
	var script: Script = _client.get_script() as Script
	if script != null:
		var consts: Dictionary = script.get_script_constant_map()
		if consts.has("ProductType") and (consts["ProductType"] as Dictionary).has("INAPP"):
			return (consts["ProductType"] as Dictionary)["INAPP"]
	return 0

func _seam_purchase(product_id: String) -> Dictionary:
	var result: Variant = _client.call("purchase", product_id)
	return result as Dictionary if typeof(result) == TYPE_DICTIONARY else {}

func _seam_acknowledge(purchase_token: String) -> void:
	_client.call("acknowledge_purchase", purchase_token)

func _seam_purchase_token(p: Dictionary) -> String:
	return str(p.get("purchase_token", ""))

func _seam_is_acknowledged(p: Dictionary) -> bool:
	return bool(p.get("is_acknowledged", false))

func _seam_product_ids(p: Dictionary) -> Array:
	return p.get("product_ids", []) as Array

func _seam_price_from_details(d: Dictionary) -> String:
	var offers_v: Variant = d.get("one_time_purchase_offer_details_list", null)
	if typeof(offers_v) == TYPE_ARRAY:
		for offer_v: Variant in offers_v as Array:
			if typeof(offer_v) != TYPE_DICTIONARY:
				continue
			var offer: Dictionary = offer_v as Dictionary
			var formatted: String = str(offer.get("formatted_price", ""))
			if formatted != "":
				return formatted
	# Compatibility fallback for older plugin result shapes.
	return str(d.get("formatted_price", d.get("price", "")))

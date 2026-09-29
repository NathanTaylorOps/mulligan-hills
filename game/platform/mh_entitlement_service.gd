class_name MHEntitlementService
extends Node
## INTERFACE for purchases. Gameplay code talks ONLY to this class (never to a plugin).
## Unlock model: free demo + one non-consumable unlock. Entitlement is tied to the STORE RECEIPT,
## not to the Supabase account. Online: store purchase -> server verifies -> signed token.
## Offline: the cached signed token is verified locally with the embedded public key.
##
## Typical use:
##   var ent: MHEntitlementService = MHPlatform.create_entitlement()
##   add_child(ent); ent.initialize()
##   if ent.is_unlocked(): ...
##   ent.purchase(MHPlatformConfig.PRODUCT_UNLOCK)

enum PurchaseResult { OK, CANCELED, PENDING, ERROR, UNAVAILABLE, VERIFY_FAILED }

signal entitlement_changed(unlocked: bool)
signal owned_products_updated(product_ids: PackedStringArray)
signal purchase_finished(product_id: String, result: int, message: String)
signal restore_finished(success: bool, message: String)

var _unlocked: bool = false
var _payload: Dictionary = {}
var _token: String = ""

# ---- Interface (override in adapters) ----------------------------------------------------------

## Load cache, connect to the store. Safe to call more than once.
func initialize() -> void:
	_load_cache()

## Coroutine-friendly: `var ids: PackedStringArray = await ent.query_owned_products()`.
## Returns product ids the user is entitled to (cache first, then store if reachable).
func query_owned_products() -> PackedStringArray:
	return _owned_from_cache()

## Starts a purchase. Result arrives via purchase_finished. Never grants without a valid token.
func purchase(product_id: String) -> void:
	push_error("MHEntitlementService.purchase not implemented")
	purchase_finished.emit(product_id, PurchaseResult.UNAVAILABLE, "not implemented")

## RESTORE PURCHASES hook (required by Apple; wired to a Settings button on both platforms).
func restore() -> void:
	push_error("MHEntitlementService.restore not implemented")
	restore_finished.emit(false, "not implemented")

## Localised price string for the UI ("$4.99"), or "" if unknown. Cached from the store when available.
func get_display_price(product_id: String) -> String:
	return ""

## ACCOUNT DELETION hook: call from the account-deletion flow. Deleting a Supabase account does NOT
## revoke the purchase (it belongs to the store account). By default this keeps the cached token.
## Pass true to also wipe the local entitlement cache (the user can Restore afterwards).
func on_account_deleted(clear_entitlement: bool = false) -> void:
	if clear_entitlement:
		clear_local_cache()

# ---- Shared implementation (do not override lightly) -------------------------------------------

func is_unlocked() -> bool:
	return _unlocked

func get_cached_token() -> String:
	return _token

func clear_local_cache() -> void:
	var was: bool = _unlocked
	_unlocked = false
	_payload = {}
	_token = ""
	if FileAccess.file_exists(MHPlatformConfig.CACHE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MHPlatformConfig.CACHE_PATH))
	if was:
		entitlement_changed.emit(false)

## True when a token exists and the soft refresh time has passed (caller should re-verify when online).
func needs_revalidation() -> bool:
	if _token == "":
		return false
	return MHEntitlementToken.needs_refresh(_payload, int(Time.get_unix_time_from_system()))

func _owned_from_cache() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if _unlocked:
		out.append(MHPlatformConfig.PRODUCT_UNLOCK)
	return out

## Verify + adopt + persist a server-issued token. Returns true if it unlocked the game.
func _apply_token(token: String) -> bool:
	var res: Dictionary = MHEntitlementToken.verify(
		token, MHPlatformConfig.ENTITLEMENT_PUBLIC_KEY_PEM,
		MHPlatformConfig.PACKAGE_NAME, MHPlatformConfig.PRODUCT_UNLOCK)
	if not bool(res["ok"]):
		push_warning("Entitlement token rejected: %s" % str(res["reason"]))
		return false
	_token = token
	_payload = res["payload"]
	_save_cache()
	_set_unlocked(true)
	return true

func _set_unlocked(value: bool) -> void:
	if value != _unlocked:
		_unlocked = value
		entitlement_changed.emit(value)
		owned_products_updated.emit(_owned_from_cache())

func _save_cache() -> void:
	var f: FileAccess = FileAccess.open(MHPlatformConfig.CACHE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write entitlement cache")
		return
	f.store_string(JSON.stringify({"token": _token}))

func _load_cache() -> void:
	if not FileAccess.file_exists(MHPlatformConfig.CACHE_PATH):
		return
	var f: FileAccess = FileAccess.open(MHPlatformConfig.CACHE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var token: String = str((parsed as Dictionary).get("token", ""))
	if token != "":
		_apply_token(token)

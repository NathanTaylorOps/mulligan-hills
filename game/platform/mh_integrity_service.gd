class_name MHIntegrityService
extends Node
## INTERFACE for device/app attestation. Android: Play Integrity STANDARD requests via the
## MHPlayIntegrity Kotlin plugin (android/plugin). iOS: not implemented in Phase 0 (see ios/README.md).
##
## Result dictionary from request_token: {"ok": bool, "token": String, "error": String}
## The token is opaque to the game; it is only forwarded to the server, which decodes it.

signal prepared(ok: bool, message: String)

func is_supported() -> bool:
	return false

## Warm up the token provider (Play Integrity "prepareIntegrityToken"). Call at app start.
func prepare() -> void:
	prepared.emit(false, "not implemented")

## Coroutine: `var r: Dictionary = await integrity.request_token(hash)`.
## request_hash binds the token to one action; use MHIntegrityService.request_hash(...).
func request_token(request_hash: String) -> Dictionary:
	return {"ok": false, "token": "", "error": "not_implemented"}

## Hash source shared with the server (sha256 hex of the parts joined by "|").
## purchase: [package, product_id, purchase_token]; generic: [package, action, nonce].
static func request_hash(parts: PackedStringArray) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update("|".join(parts).to_utf8_buffer())
	return ctx.finish().hex_encode()

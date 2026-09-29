class_name MHEntitlementToken
extends RefCounted
## Offline verifier for the server-signed entitlement token ("mh1").
##
## Format:  mh1.<b64url(payload_json)>.<b64url(RSASSA-PKCS1-v1_5 SHA-256 signature)>
## The signature covers the ASCII string "mh1.<b64url(payload_json)>".
## Payload keys: v (int, =1), pkg (String), pid (String product id), ord (String order id),
## pth (String, first 16 hex of sha256(purchase token)), iat (int unix secs), ref (int unix secs: soft refresh time).
##
## Godot API assumed (stable 4.x, UNVERIFIED because Godot is not runnable here):
##   CryptoKey.load_from_string(pem, public_only=true) -> Error
##   Crypto.verify(hash_type, hash: PackedByteArray, signature: PackedByteArray, key: CryptoKey) -> bool
##   HashingContext, Marshalls.base64_to_raw

const PREFIX: String = "mh1"

static func b64url_decode(s: String) -> PackedByteArray:
	var t: String = s.replace("-", "+").replace("_", "/")
	while t.length() % 4 != 0:
		t += "="
	return Marshalls.base64_to_raw(t)

static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "payload": {}}

## Returns {"ok": bool, "reason": String, "payload": Dictionary}.
## Does NOT check expiry: entitlements are valid offline forever; "ref" is only a hint to re-verify online.
static func verify(token: String, public_key_pem: String, expected_pkg: String, expected_pid: String) -> Dictionary:
	if public_key_pem == "":
		return _fail("no_public_key")
	var parts: PackedStringArray = token.split(".")
	if parts.size() != 3 or parts[0] != PREFIX:
		return _fail("malformed")
	var key: CryptoKey = CryptoKey.new()
	if key.load_from_string(public_key_pem, true) != OK:
		return _fail("bad_public_key")
	var signed_bytes: PackedByteArray = (parts[0] + "." + parts[1]).to_utf8_buffer()
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(signed_bytes)
	var digest: PackedByteArray = ctx.finish()
	var crypto: Crypto = Crypto.new()
	var sig_ok: bool = crypto.verify(HashingContext.HASH_SHA256, digest, b64url_decode(parts[2]), key)
	if not sig_ok:
		return _fail("bad_signature")
	var parsed: Variant = JSON.parse_string(b64url_decode(parts[1]).get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail("bad_payload")
	var payload: Dictionary = parsed
	if int(payload.get("v", 0)) != 1:
		return _fail("bad_version")
	if str(payload.get("pkg", "")) != expected_pkg:
		return _fail("wrong_package")
	if str(payload.get("pid", "")) != expected_pid:
		return _fail("wrong_product")
	return {"ok": true, "reason": "", "payload": payload}

static func needs_refresh(payload: Dictionary, now_unix: int) -> bool:
	return now_unix >= int(payload.get("ref", 0))

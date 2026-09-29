class_name MHVerifyApi
extends Node
## Thin HTTPS client for the Supabase Edge Functions. The only place that knows the URLs.
## Add as a child of a node in the scene tree before use.
##
## Response dictionary: {"ok": bool, "status": int, "body": Dictionary, "error": String}

func _headers() -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"apikey: %s" % MHPlatformConfig.SUPABASE_ANON_KEY,
		"Authorization: Bearer %s" % MHPlatformConfig.SUPABASE_ANON_KEY,
	])

func _post(path: String, body: Dictionary) -> Dictionary:
	if MHPlatformConfig.SUPABASE_URL == "" or MHPlatformConfig.SUPABASE_ANON_KEY == "":
		return {"ok": false, "status": 0, "body": {}, "error": "not_configured"}
	var req: HTTPRequest = HTTPRequest.new()
	req.timeout = MHPlatformConfig.HTTP_TIMEOUT_SECONDS
	add_child(req)
	var err: int = req.request(MHPlatformConfig.SUPABASE_URL + path, _headers(),
		HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		req.queue_free()
		return {"ok": false, "status": 0, "body": {}, "error": "request_error_%d" % err}
	var r: Array = await req.request_completed
	req.queue_free()
	var result_code: int = int(r[0])
	var status: int = int(r[1])
	var raw: PackedByteArray = r[3]
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": status, "body": {}, "error": "network_%d" % result_code}
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	var dict: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return {"ok": status >= 200 and status < 300, "status": status, "body": dict,
		"error": str(dict.get("error", ""))}

## integrity_token may be "" (server decides whether that is acceptable).
func verify_purchase(product_id: String, purchase_token: String, integrity_token: String) -> Dictionary:
	return await _post(MHPlatformConfig.VERIFY_PURCHASE_PATH, {
		"platform": "android",
		"package_name": MHPlatformConfig.PACKAGE_NAME,
		"product_id": product_id,
		"purchase_token": purchase_token,
		"integrity_token": integrity_token,
	})

## Standalone integrity check. Hash source on both sides: sha256hex(package|action|nonce).
func verify_integrity(integrity_token: String, action: String, nonce: String) -> Dictionary:
	return await _post(MHPlatformConfig.VERIFY_INTEGRITY_PATH, {
		"package_name": MHPlatformConfig.PACKAGE_NAME,
		"integrity_token": integrity_token,
		"action": action,
		"nonce": nonce,
	})

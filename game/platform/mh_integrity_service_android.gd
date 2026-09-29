class_name MHIntegrityServiceAndroid
extends MHIntegrityService
## Adapter for the MHPlayIntegrity Kotlin plugin (android/plugin/mhplayintegrity).
## Singleton name MUST equal the plugin name returned by getPluginName() in Kotlin.
## Plugin surface (defined by us, so not "unverified" as an API; the Godot mechanics are, see platform.md):
##   methods: prepare(cloud_project_number: String), request_token(request_hash: String)
##   signals: integrity_prepared(ok: bool, message: String)
##            integrity_token_result(request_hash: String, ok: bool, token: String, error: String)

const SINGLETON: String = "MHPlayIntegrity"
signal _token_result(request_hash: String, ok: bool, token: String, error: String)

var _plugin: Object = null
var _ready_ok: bool = false

func is_supported() -> bool:
	return Engine.has_singleton(SINGLETON)

func _ensure_plugin() -> bool:
	if _plugin != null:
		return true
	if not Engine.has_singleton(SINGLETON):
		return false
	_plugin = Engine.get_singleton(SINGLETON)
	_plugin.connect("integrity_prepared", _on_prepared)
	_plugin.connect("integrity_token_result", _on_token_result)
	return true

func prepare() -> void:
	if not _ensure_plugin():
		prepared.emit(false, "plugin_missing")
		return
	if MHPlatformConfig.CLOUD_PROJECT_NUMBER == "":
		prepared.emit(false, "cloud_project_number_not_configured")
		return
	_plugin.call("prepare", MHPlatformConfig.CLOUD_PROJECT_NUMBER)

func request_token(request_hash: String) -> Dictionary:
	if not _ensure_plugin():
		return {"ok": false, "token": "", "error": "plugin_missing"}
	if not _ready_ok:
		return {"ok": false, "token": "", "error": "not_prepared"}
	_plugin.call("request_token", request_hash)
	while true:
		var r: Array = await _token_result
		if str(r[0]) == request_hash:
			return {"ok": bool(r[1]), "token": str(r[2]), "error": str(r[3])}
	return {"ok": false, "token": "", "error": "unreachable"}

func _on_prepared(ok: bool, message: String) -> void:
	_ready_ok = ok
	prepared.emit(ok, message)

func _on_token_result(request_hash: String, ok: bool, token: String, error: String) -> void:
	_token_result.emit(request_hash, ok, token, error)

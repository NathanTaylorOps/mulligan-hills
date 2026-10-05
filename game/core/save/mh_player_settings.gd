class_name MHPlayerSettings
extends RefCounted
## Player settings that live OUTSIDE the save slots, so cloud sync and slot import can never change them.
## Analytics consent is opt-in (DEC-057): analytics_consent defaults to false and stays false until the player taps
## "yes" on the first-launch consent screen. consent_asked records that the screen has been shown.
## File: user://settings.json (canonical JSON via MHJsonFile).
## This class only stores the flag. Wiring it to MHAnalyticsService.set_enabled is the caller's job
## (call apply_to_analytics_flag(...) or read analytics_consent directly).

const DEFAULT_PATH: String = "user://settings.json"
const SAVE_VERSION: int = 1

var path: String = DEFAULT_PATH
var analytics_consent: bool = false
var consent_asked: bool = false
## Anonymous install id (UUID text) used by saves and cloud sync. "" until generated.
var install_id: String = ""


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


func to_dict() -> Dictionary:
	return {
		"v": SAVE_VERSION,
		"analytics_consent": analytics_consent,
		"consent_asked": consent_asked,
		"install_id": install_id,
	}


## Invalid or missing fields keep their safe defaults (consent false).
func from_dict(d: Dictionary) -> void:
	var consent_v: Variant = d.get("analytics_consent", false)
	analytics_consent = typeof(consent_v) == TYPE_BOOL and bool(consent_v)
	var asked_v: Variant = d.get("consent_asked", false)
	consent_asked = typeof(asked_v) == TYPE_BOOL and bool(asked_v)
	var iid: Variant = d.get("install_id", "")
	install_id = String(iid) if typeof(iid) == TYPE_STRING else ""


## Records the player's answer to the consent screen.
func set_consent(granted: bool) -> void:
	analytics_consent = granted
	consent_asked = true


func save() -> int:
	return MHJsonFile.write_dict(path, to_dict())


## Loads from disk. A missing or damaged file leaves the defaults (consent false, not asked). Returns the result of
## the read (NOT_FOUND on first launch is normal).
func load_from_disk() -> MHSaveResult:
	analytics_consent = false
	consent_asked = false
	install_id = ""
	var r: MHSaveResult = MHJsonFile.read_dict(path)
	if r.is_ok():
		from_dict(r.value as Dictionary)
	return r


## True when the consent screen still has to be shown.
func needs_consent_prompt() -> bool:
	return not consent_asked


## Creates and stores a random anonymous install id when none exists. Returns the id.
func ensure_install_id() -> String:
	if install_id.is_empty():
		install_id = generate_install_id()
	return install_id


## Random version 4 UUID text. Uses Crypto.generate_random_bytes (Godot 4 API, UNVERIFIED on all export targets).
static func generate_install_id() -> String:
	var crypto := Crypto.new()
	var b: PackedByteArray = crypto.generate_random_bytes(16)
	return uuid_from_bytes(b)


## Formats 16 bytes as a version 4 UUID (sets the version and variant bits). Short input is zero padded.
static func uuid_from_bytes(bytes: PackedByteArray) -> String:
	var b: PackedByteArray = bytes.duplicate()
	b.resize(16)
	b[6] = (b[6] & 0x0F) | 0x40
	b[8] = (b[8] & 0x3F) | 0x80
	var hex: String = ""
	for i in range(16):
		hex += MHHash.hex32(b[i]).substr(6, 2)
		if i == 3 or i == 5 or i == 7 or i == 9:
			hex += "-"
	return hex

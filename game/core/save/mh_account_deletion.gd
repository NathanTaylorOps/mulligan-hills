class_name MHAccountDeletion
extends RefCounted
## Account deletion helper (SAVE_MIGRATION.md rule 11, store policy: in-app deletion path).
## Server side (cloud saves, leaderboard rows, analytics rows for the anonymous id) is the backend's job and is
## described by build_request(). This class does the LOCAL part:
##   - always: reset settings (analytics consent back to false, consent screen will show again, new anonymous id).
##   - only when delete_saves is true: also delete every local save slot. By default local saves STAY (rule 11).
## The paid unlock and the token ledger are NOT touched here: deleting an account never revokes a purchase
## (see MHAccountService), and purchased tokens belong to the store account.

## What the backend must delete. Plain ints and strings, ready to send.
static func build_request(install_id: String) -> Dictionary:
	return {
		"install_id": install_id,
		"delete": ["cloud_saves", "leaderboard_rows", "analytics_events", "consent_records"],
		"keep": ["store_purchases"],
	}


## Local cleanup after the server confirmed deletion. value = {"slots_deleted": int, "settings_reset": bool}.
static func delete_local(settings: MHPlayerSettings, store: MHSaveStore, delete_saves: bool) -> MHSaveResult:
	var slots_deleted: int = 0
	if delete_saves and store != null:
		for slot in range(MHSaveGame.MAX_SLOTS):
			var r: MHSaveResult = store.delete_slot(slot)
			if not r.is_ok():
				return r
			if int(r.value) > 0:
				slots_deleted += 1
	var reset_ok: bool = true
	if settings != null:
		settings.analytics_consent = false
		settings.consent_asked = false
		settings.install_id = MHPlayerSettings.generate_install_id()
		reset_ok = settings.save() == OK
	if not reset_ok:
		return MHSaveResult.failure(MHSaveResult.Code.IO_ERROR, "settings could not be reset")
	return MHSaveResult.success({"slots_deleted": slots_deleted, "settings_reset": settings != null})

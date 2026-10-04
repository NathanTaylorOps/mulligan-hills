class_name MHSlotInfo
extends RefCounted
## One row of the slot list. present = some file for the slot exists; valid = a loadable save was found.

var slot: int = 0
var present: bool = false
var valid: bool = false
var kind: String = ""
var summary: MHSaveSummary = null
## "main", "tmp" or "bak": which JSON file the summary came from ("" when not valid).
var source: String = ""
var error_code: int = MHSaveResult.Code.OK
var error_message: String = ""


func needs_app_update() -> bool:
	return error_code == MHSaveResult.Code.NEEDS_APP_UPDATE

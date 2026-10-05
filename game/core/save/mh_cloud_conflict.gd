class_name MHCloudConflict
extends RefCounted
## Cloud save conflict model (DEC-058: conflicts ALWAYS ask the player; there is no "newest wins" automation).
## Pure data: compares two MHSaveSummary values (local and cloud) and prepares the rows for the prompt:
## in-game day, cash, hole count and play time for both sides. It never touches files or the network.
##
## kind:
##   IN_SYNC     checksums equal, nothing to do, no prompt.
##   LOCAL_ONLY  no cloud copy (upload is allowed, no prompt).
##   CLOUD_ONLY  no local copy (the caller may offer a restore into an EMPTY slot; nothing is overwritten).
##   CONFLICT    both exist and differ. The player must choose. needs_prompt() is true.
## Choices (resolve): KEEP_LOCAL (cloud copy is left alone, upload only on the player's later request),
## USE_CLOUD (the caller imports the cloud copy with MHSaveStore.import_slot(..., confirmed_overwrite = true)),
## KEEP_BOTH (the caller imports the cloud copy into a free slot), CANCEL (decide later, nothing changes).
## Cash is shown in the economy module's smallest whole unit; the UI formats it.

enum Kind { IN_SYNC = 0, LOCAL_ONLY = 1, CLOUD_ONLY = 2, CONFLICT = 3 }
enum Choice { CANCEL = 0, KEEP_LOCAL = 1, USE_CLOUD = 2, KEEP_BOTH = 3 }

var kind: int = Kind.IN_SYNC
var local: MHSaveSummary = null
var cloud: MHSaveSummary = null
## True when the two saves were written by different installs (another device).
var other_device: bool = false
## True when the cloud copy is ahead on revision. Informational only: it never decides anything.
var cloud_has_higher_revision: bool = false


static func detect(p_local: MHSaveSummary, p_cloud: MHSaveSummary) -> MHCloudConflict:
	var c := MHCloudConflict.new()
	c.local = p_local
	c.cloud = p_cloud
	if p_local == null and p_cloud == null:
		c.kind = Kind.IN_SYNC
		return c
	if p_cloud == null:
		c.kind = Kind.LOCAL_ONLY
		return c
	if p_local == null:
		c.kind = Kind.CLOUD_ONLY
		return c
	c.other_device = p_local.install_id != p_cloud.install_id
	c.cloud_has_higher_revision = p_cloud.revision > p_local.revision
	if p_local.checksum != "" and p_local.checksum == p_cloud.checksum:
		c.kind = Kind.IN_SYNC
	else:
		c.kind = Kind.CONFLICT
	return c


func needs_prompt() -> bool:
	return kind == Kind.CONFLICT


## Rows for the prompt, always in this order: day, cash, holes, playtime_s, saved_at_unix.
## Each row: {"field": String, "local": int, "cloud": int, "differs": bool}. Empty when a side is missing.
func rows() -> Array:
	var out: Array = []
	if local == null or cloud == null:
		return out
	out.append(_row("day", local.day, cloud.day))
	out.append(_row("cash", local.cash, cloud.cash))
	out.append(_row("holes", local.holes, cloud.holes))
	out.append(_row("playtime_s", local.playtime_s, cloud.playtime_s))
	out.append(_row("saved_at_unix", local.saved_at_unix, cloud.saved_at_unix))
	return out


func _row(field: String, l: int, c: int) -> Dictionary:
	return {"field": field, "local": l, "cloud": c, "differs": l != c}


## True when `choice` is a legal answer for this conflict. Only CONFLICT accepts KEEP_LOCAL, USE_CLOUD, KEEP_BOTH.
func is_valid_choice(choice: int) -> bool:
	if choice == Choice.CANCEL:
		return true
	if kind != Kind.CONFLICT:
		return false
	return choice == Choice.KEEP_LOCAL or choice == Choice.USE_CLOUD or choice == Choice.KEEP_BOTH


## What the caller must do for a choice. value = {"action": String} with one of
## "none", "keep_local", "import_cloud_overwrite", "import_cloud_new_slot". Fails for an invalid choice.
## USE_CLOUD says "import_cloud_overwrite": the caller must pass confirmed_overwrite = true, which it may do only
## because the player just chose it.
func resolve(choice: int) -> MHSaveResult:
	if not is_valid_choice(choice):
		return MHSaveResult.failure(MHSaveResult.Code.INVALID_ARGUMENT, "choice is not valid for this conflict")
	if choice == Choice.KEEP_LOCAL:
		return MHSaveResult.success({"action": "keep_local"})
	if choice == Choice.USE_CLOUD:
		return MHSaveResult.success({"action": "import_cloud_overwrite"})
	if choice == Choice.KEEP_BOTH:
		return MHSaveResult.success({"action": "import_cloud_new_slot"})
	return MHSaveResult.success({"action": "none"})


## Smallest slot index (1 to MAX_SLOTS - 1, never the autosave slot) with no files, or -1 when all are in use.
## `slots` is MHSaveStore.list_slots() output.
static func free_manual_slot(slots: Array) -> int:
	for i in range(1, MHSaveGame.MAX_SLOTS):
		var used: bool = false
		for s in slots:
			var info: MHSlotInfo = s
			if info.slot == i and info.present:
				used = true
		if not used:
			return i
	return -1

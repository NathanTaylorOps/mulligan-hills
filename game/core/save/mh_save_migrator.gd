class_name MHSaveMigrator
extends RefCounted
## Registry of save migration steps (SAVE_MIGRATION.md rules 1 to 3 and 8).
##
## A step is a Callable(d: Dictionary) -> Dictionary registered for the version it upgrades FROM. It must be pure and
## deterministic: no I/O, no randomness, no clock. It receives a private deep copy, returns the upgraded document, and
## does NOT need to set save_version (the migrator sets it to from_version + 1) or the checksum (the caller re-seals).
## Steps are applied one at a time, in order, never skipped. The migrator refuses a step that changes the determinism
## state (sim.rng_seed, sim.rng_inc, sim.rating_epoch), because rule 8 says those survive migration unchanged.
##
## create_default() is the registry the game uses. It is empty while SAVE_VERSION is 1. To add v1 -> v2:
##   1. bump MHSaveGame.SAVE_VERSION, 2. add `m.register_step(1, Callable(MHSaveMigrations, "v1_to_v2"))` in create_default,
##   3. add fixtures and a test, 4. update the manifest table in docs/spec/data/SAVE_MIGRATION.md.

var target_version: int = MHSaveGame.SAVE_VERSION
## Number of steps applied by the last migrate() call.
var last_steps_applied: int = 0
var _steps: Dictionary = {}


static func create_default() -> MHSaveMigrator:
	var m := MHSaveMigrator.new()
	return m


func register_step(from_version: int, step: Callable) -> bool:
	if from_version < 0 or not step.is_valid() or _steps.has(from_version):
		return false
	_steps[from_version] = step
	return true


func has_step(from_version: int) -> bool:
	return _steps.has(from_version)


func registered_versions() -> Array:
	var keys: Array = _steps.keys()
	keys.sort()
	return keys


static func version_of(d: Dictionary) -> int:
	var v: Variant = d.get("save_version", 0)
	if typeof(v) != TYPE_INT:
		return -1
	return int(v)


func needs_migration(d: Dictionary) -> bool:
	var v: int = version_of(d)
	return v >= 0 and v < target_version


## value = migrated deep copy. The input is never modified. A document already at (or beyond) target_version is
## returned unchanged as a copy; whether a newer file is acceptable is the caller's decision (min_reader_version).
func migrate(d: Dictionary) -> MHSaveResult:
	last_steps_applied = 0
	var v: int = version_of(d)
	if v < 0:
		return MHSaveResult.failure(MHSaveResult.Code.MIGRATION_FAILED, "save_version missing or not an integer")
	var work: Dictionary = d.duplicate(true)
	while v < target_version:
		if not _steps.has(v):
			return MHSaveResult.failure(MHSaveResult.Code.MIGRATION_FAILED, "no migration step from version %d" % v)
		var step: Callable = _steps[v]
		var before: Array = _determinism_state(work)
		var out: Variant = step.call(work.duplicate(true))
		if typeof(out) != TYPE_DICTIONARY:
			return MHSaveResult.failure(MHSaveResult.Code.MIGRATION_FAILED, "step %d did not return a Dictionary" % v)
		var nr: MHSaveResult = MHSaveGame.normalize(out)
		if not nr.is_ok():
			return MHSaveResult.failure(MHSaveResult.Code.MIGRATION_FAILED, "step %d produced invalid data: %s" % [v, nr.message])
		work = nr.value
		if _determinism_state(work) != before:
			return MHSaveResult.failure(MHSaveResult.Code.MIGRATION_FAILED, "step %d changed determinism state (rule 8)" % v)
		v += 1
		work["save_version"] = v
		last_steps_applied += 1
	return MHSaveResult.success(work)


static func _determinism_state(d: Dictionary) -> Array:
	var sim: Variant = d.get("sim", null)
	if typeof(sim) != TYPE_DICTIONARY:
		return [null, null, null]
	var sd: Dictionary = sim
	return [sd.get("rng_seed", null), sd.get("rng_inc", null), sd.get("rating_epoch", null)]

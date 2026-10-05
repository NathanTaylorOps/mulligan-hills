# Interface: Save (`game/core/save/`, owner assigned in Phase 1; atomic file I/O reviewed with F)

## Implementation status (5 Oct 2026)
Built in `game/core/save/` (Phase 1, see `docs/phase1/save.md`): `MHSaveGame` (document, canonical JSON, checksum, validation), `MHSaveFile` (atomic write, `.bak`), `MHSaveStore` (slots 0 to 4, JSON plus terrain blob pairing by `course.terrain.content_hash`, hourly `autosave_if_due`, export/import, delete), `MHSaveMigrator`, `MHCloudConflict` (always asks, DEC-058), `MHSaveSummary`, `MHSlotInfo`, `MHLoadedSave`, `MHSaveResult`, `MHPlayerSettings`, `MHAccountDeletion`. The save document is a plain Dictionary shaped like `docs/spec/data/save.schema.json`; the `MHGameState` class below was never built (the game assembles the Dictionary from its modules: `to_save_block` / `from_save_block` on each). The names in the sketch below are the original draft and differ from the code in places (`MHResult` is `MHSaveResult`, `recover` is folded into `load_slot`, `export_backup` / `import_backup` are `export_slot` / `import_slot`). The terrain blob is a separate file; the torn-pair case is handled by `load_slot` through the height hash. Not built yet: the game-state-to-document assembly, cloud upload, the conflict prompt screen.

Purpose: versioned, atomic, migratable saves, slots, backup/export, cloud sync handoff. Format and migration rules: `docs/spec/data/save.schema.json` and `SAVE_MIGRATION.md`.

```gdscript
class_name MHSaveStore extends RefCounted
const SAVE_VERSION: int = 1
signal saved(slot: int, revision: int)          # UI only
signal load_failed(slot: int, code: int)
func list_slots() -> Array[MHSlotInfo]           # slot, kind, revision, day, cash, holes, saved_at_unix, valid
func load_slot(slot: int) -> MHResult            # value = MHGameState, runs the loader order in SAVE_MIGRATION.md
func save_slot(slot: int, state: MHGameState) -> MHResult   # atomic (tmp, verify, rename); revision + 1
func autosave(state: MHGameState) -> MHResult    # called at every game-hour boundary (DEC-052) and after edits, debounced
func export_backup(slot: int) -> MHResult        # value = path or bytes for the share sheet
func import_backup(bytes: PackedByteArray) -> MHResult      # validates fully before touching any slot; never overwrites without confirmation
func delete_slot(slot: int) -> MHResult
func recover() -> MHResult                       # after a crash: prefers newest valid of slot file, .tmp, .bak
func canonical_json(state: MHGameState) -> String            # sorted keys, no whitespace, ints only
func checksum(state: MHGameState) -> String                  # hex sha256
```
```gdscript
class_name MHGameState extends RefCounted     # in-memory mirror of save.schema.json; owned by the game, copied into save
func to_dict() -> Dictionary                  # ints only; 64-bit values as 16-char hex strings
static func from_dict(d: Dictionary) -> MHResult    # converts float64 JSON numbers to int with range checks, rejects non-integral values
```

## Rules
- The store never reads or writes entitlement data.
- `load_slot` never returns a partially valid state. Failure leaves files untouched.
- Cloud sync is a separate service (platform_services/Supabase client) that uploads only validated, checksummed files and hands downloads to `import_backup`-style validation. It never auto-overwrites local; conflicts surface a prompt.
- No Ironman (DEC-058). Cloud conflicts always ask the player; local never loses to a higher cloud revision silently.
- Kill-during-save must leave a loadable file at every instant (Gate 0 item 10).

## Consumers
All modules through `MHGameState`; UI (slot list); platform services (cloud).

## Contract tests
Round trip byte equality, migration fixtures for each version, corruption cases (truncated, bad checksum, wrong schema, future min_reader_version), kill-during-save harness (owned by F for Gate 0), float64 integer conversion edge cases at 2^53.

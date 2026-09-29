# Interface: Save (`game/core/save/`, owner assigned in Phase 1; atomic file I/O reviewed with F)

## Implementation status (29 Sep 2026)
No save-store code exists (no `game/core/save/`, no `MHSaveStore`, `MHGameState`, `MHSlotInfo`, `MHResult`). The only implemented persistence is the terrain blob: `MHTerrainSave` (`game/terrain/`, magic `MHTS`, version 1, zstd, CRC32, FNV-1a height hash, write to `<path>.tmp` then rename, no read-back verify step, no `.bak`). See `terrain.md` section 7. The save slot JSON (`docs/spec/data/save.schema.json`) references the blob by `course.terrain.file`; the example name is `terrain_0.mhts`. The terrain blob is a separate binary file, so the "atomic per slot" rule and the kill-during-save test (Gate 0 item 10) must cover the JSON file and the blob together (a torn pair, new JSON with old blob, is not yet handled: `terrain.content_hash` is the check to add). The rules below are the Phase 1 draft.

Purpose: versioned, atomic, migratable saves, slots, backup/export, cloud sync handoff. Format and migration rules: `docs/spec/data/save.schema.json` and `SAVE_MIGRATION.md`.

```gdscript
class_name MHSaveStore extends RefCounted
const SAVE_VERSION: int = 1
signal saved(slot: int, revision: int)          # UI only
signal load_failed(slot: int, code: int)
func list_slots() -> Array[MHSlotInfo]           # slot, kind, revision, day, cash, holes, saved_at_unix, valid
func load_slot(slot: int) -> MHResult            # value = MHGameState, runs the loader order in SAVE_MIGRATION.md
func save_slot(slot: int, state: MHGameState) -> MHResult   # atomic (tmp, verify, rename); revision + 1
func autosave(state: MHGameState) -> MHResult    # called at day boundaries and after edits, debounced
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
- Ironman slot rules per SAVE_MIGRATION.md item 9 (pending decision).
- Kill-during-save must leave a loadable file at every instant (Gate 0 item 10).

## Consumers
All modules through `MHGameState`; UI (slot list); platform services (cloud).

## Contract tests
Round trip byte equality, migration fixtures for each version, corruption cases (truncated, bad checksum, wrong schema, future min_reader_version), kill-during-save harness (owned by F for Gate 0), float64 integer conversion edge cases at 2^53.

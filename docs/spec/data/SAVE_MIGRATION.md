# Save file versioning and migration rules

Schema: `save.schema.json`. Current `save_version`: 1.

## What a save contains and does not contain
- Contains: club state, buildings, land, the embedded course, deterministic sim seed/counters, a ratings cache, progress, tournament and commission state.
- Does NOT contain: the paid unlock, receipts, tokens, or any entitlement (schema rejects them; cash or an unlock flag in a cloud blob must not be able to unlock the game). The entitlement is a separate signed cache verified against the store.
- Does NOT contain live golfers or mid-day state. Autosave happens at day boundaries and after edits; quitting mid-day resumes at the start of that day (at 18 s per day at 1x this costs seconds).
- Does NOT contain undo/redo history (session only) or player-typed text (names are preset ids).

## Versioning
- `save_version`: integer, +1 for every schema change that alters shape or meaning. `min_reader_version`: the lowest app save-reader version able to read this file. `written_by` records app, sim and rating versions.
- Loader order: (1) parse JSON, (2) check `schema == "mh.save"`, (3) if `min_reader_version` > reader's version: refuse and show "update the app" (never guess), (4) verify checksum, (5) migrate step by step to current, (6) validate against the current schema, (7) validate embedded course against hard limits, (8) recompute ratings if `rating_version` differs.
- Checksum: sha256 over the canonical serialisation of the file with the `checksum` object removed (keys sorted, no whitespace, UTF-8). A mismatch is treated as corruption, not as tampering.

## Migration rules
1. One function per step: `migrate_v{N}_to_v{N+1}(d: Dictionary) -> Dictionary`, pure, deterministic, no I/O, no randomness, no clock. Steps are applied in order; never skip.
2. Every step ships with a fixture pair `tests/fixtures/save_vN.json` and `save_vN+1.json` and a test proving migrate(vN) equals vN+1 byte for byte after canonical serialisation. The lead may not merge a schema change without both.
3. Migrations only add defaults or reshape. Deleting player progress in a migration is forbidden. Unknown future fields are dropped only when the reader version is newer than the file (never the reverse).
4. Before migrating, the original file is copied to a `.bak` slot of the same slot number (`slot_kind: "backup"`). The backup is kept until the migrated save has loaded and run one successful autosave.
5. Writes are atomic: write to `slot_N.tmp`, flush, verify checksum by re-reading, rename over `slot_N.json`. A kill during any step leaves either the old or the new file intact, never a half file (Gate 0 item 10 proves this). The terrain blob (`MHTerrainSave`, `.mhts`) is a separate file with its own tmp-then-rename write and no read-back verify or `.bak`; the JSON slot and the blob are written as two files, so a kill between them can leave a new JSON beside an old blob. Loader must compare `course.terrain.content_hash` (FNV-1a of the heights) with the blob and fall back to the `.bak` pair on mismatch. Not yet implemented.
6. Revision counter: `revision` is +1 on every successful write of a slot. Local always wins offline. Cloud sync is backup-first: a cloud copy with a higher revision never silently overwrites local; the player is prompted with day, cash, holes and time for both. Cloud upload never sends a save whose validation failed.
7. Rating cache is never authoritative: on version mismatch it is recomputed and the save re-written. Course geometry and buildings are the truth.
8. Determinism state (`sim.rng_seed`, `sim.rng_inc`, `sim.rating_epoch`) must survive migration unchanged. A change to engine algorithms that alters results increments `rating_version`/`sim_version` and requires new golden files; it does NOT by itself bump `save_version`.
9. Ironman: `ironman: true`, `slot_kind: "ironman"`, exactly one slot, autosave only, no manual backup or export, cloud copy is upload-only backup (restore only after the local file is missing). Decision needed to confirm (see DECISIONS.md, open items).
10. Demo to full: same file, same schema. Demo limits are enforced by the app from the entitlement state and the data files (`demo_max_tier`, 9 holes), not by a save flag. A demo save never exceeds demo limits, so the upgrade simply lifts them.
11. Deletion: account deletion removes cloud saves, leaderboard rows and any other server rows for the anonymous id; local saves stay until the player deletes the app data.

## Migration manifest (keep updated with each bump)
| From | To | Change | Fixtures |
| --- | --- | --- | --- |
| (none) | 1 | Initial schema | n/a |

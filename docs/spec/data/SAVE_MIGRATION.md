# Save file versioning and migration rules

Schema: `save.schema.json`. Current `save_version`: 1. Code: `game/core/save/` (`MHSaveGame`, `MHSaveStore`, `MHSaveMigrator`). Updated 5 Oct 2026 for DEC-052 (clock position, hourly autosave) and DEC-058 (Ironman cut, cloud conflicts always ask).

## What a save contains and does not contain
- Contains: club state, buildings, land, the embedded course, deterministic sim seed/counters, a ratings cache, progress (tutorial, achievements and their stats, daily streak, daily challenge record, tournament state and counters, commissions, event card history, purchased tiers, play time), the in-day clock position, and the other fields in the schema.
- Does NOT contain: the paid unlock, receipts, tokens, or any entitlement (schema rejects them; cash or an unlock flag in a cloud blob must not be able to unlock the game). The entitlement is a separate signed cache verified against the store.
- Does NOT contain live golfers or other mid-day simulation state. The save holds the day (`world.day`) and the position inside the day (`world.minute_of_day`, game minutes 0..659, a day is 660 minutes, DEC-052). Autosave happens at every game-hour boundary (and after edits, debounced), so a quit loses at most about one game hour (about 80 real seconds at 1x). On load the clock resumes at `day` and `minute_of_day` with an EMPTY golfer roster: golfers who were on the course are not restored, and the simulation fills the course again from the arrival model. A save without `minute_of_day` (written before the field existed) resumes at minute 0 of its day.
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
5. Writes are atomic: write to `slot_N.tmp`, flush, verify checksum by re-reading, rename over `slot_N.json`. A kill during any step leaves either the old or the new file intact, never a half file (Gate 0 item 10 proves this). The terrain blob (`MHTerrainSave`, `.mhts`) is a separate file with its own tmp-then-rename write and no read-back verify or `.bak`; the JSON slot and the blob are written as two files, so a kill between them can leave a new JSON beside an old blob. The loader compares `course.terrain.content_hash` (FNV-1a of the heights) with the blob and falls back to the `.bak` pair on mismatch (implemented in `MHSaveStore.load_slot`; a torn pair that differs only in paint layers is not detected, see `docs/phase1/save.md` risk 2).
6. Revision counter: `revision` is +1 on every successful write of a slot. Local always wins offline. Cloud sync is backup-first: a cloud copy with a higher revision never silently overwrites local; the player is prompted with day, cash, holes and time for both. Cloud upload never sends a save whose validation failed.
7. Rating cache is never authoritative: on version mismatch it is recomputed and the save re-written. Course geometry and buildings are the truth.
8. Determinism state (`sim.rng_seed`, `sim.rng_inc`, `sim.rating_epoch`) must survive migration unchanged. A change to engine algorithms that alters results increments `rating_version`/`sim_version` and requires new golden files; it does NOT by itself bump `save_version`.
9. Ironman is cut from v1 (DEC-058). There is no Ironman slot kind, no one-slot rule and no upload-only cloud rule. The legacy key `ironman` may still appear in the first v1 files: it is optional and must be `false`; a rewrite drops it (`MHSaveGame.strip_legacy_keys`). A save with `ironman: true` or `slot_kind: "ironman"` is invalid. Cloud save conflicts always ask the player (rule 6).
10. Demo to full: same file, same schema. Demo limits are enforced by the app from the entitlement state and the data files (`demo_max_tier`, 9 holes), not by a save flag. A demo save never exceeds demo limits, so the upgrade simply lifts them.
11. Deletion: account deletion removes cloud saves, leaderboard rows and any other server rows for the anonymous id; local saves stay until the player deletes the app data.

## Additive optional fields (no version bump)
12. A field that is new but OPTIONAL (absent means a documented default) does not change `save_version`: files without it stay valid and need no migration step. These fields were added to v1 before any build shipped, and each one has a default when missing: `world.minute_of_day` (0), `progress.playtime_s` (0), `progress.tournaments.hosted_count` and `attempted_count` (raised to what `hosted_levels` implies), `progress.stats` (empty: stats rebuild from the next game updates), `progress.streak` (a fresh streak), `progress.daily` (no attempts). Readers use the defaults; they never fail on a missing optional field. Once a build has shipped, a new field that older readers cannot ignore must set `min_reader_version`, and a change of meaning or shape needs a real step with fixtures (rules 1 to 3).
13. Stats are high-water marks and are rebuilt from game state where possible, so a lost `progress.stats` block costs only the counters with no other source (`streak_best`, `active_days`, `tournaments_attempted`, `challenges_*`, `cards_played`, `commission_kinds`, `best_axis`, `bonus_prestige`). Unknown stat names (from a newer build) are dropped on load, not an error.

## Migration manifest (keep updated with each bump)
| From | To | Change | Fixtures |
| --- | --- | --- | --- |
| (none) | 1 | Initial schema. Optional fields added during v1, before any shipped build: `world.minute_of_day`, `progress.playtime_s`, `progress.stats`, `progress.streak`, `progress.daily`, tournament counters. `ironman` made optional (must be false), `slot_kind: "ironman"` removed. | `tests/save/test_save_progress.gd` builds a legacy v1 document and a full document in code |


## Optional live runtime checkpoint (reader 2, 5 October 2026)

`runtime` is optional in save v1; files without it remain readable. Files containing it set `min_reader_version=2`, so a reader-1 app refuses before checksum/schema handling rather than dropping precise accounting. Reader 2 retains old-file behavior. The block carries exact integer clock/economy state, saved seed/history, a separate-ledger equality hash and the full terrain-byte pairing hash (SHA256 of lowercase hex text of the compressed blob, not raw-byte SHA256). Token balances/claim keys remain outside slots.

`MHSessionSave` verifies redundant fields agree and restores a new session atomically. This first live adapter accepts zero finalized holes only; legacy/finished-hole slots are not silently reinitialized. The development scene uses an isolated official slot directory and immutable separate ledger generations. Full course geometry conversion, production identities, generation cleanup and cloud ledger reconciliation remain open. `live_save.example.json` is a schema/checksum fixture; its terrain-byte hash is a placeholder because no paired binary fixture is shipped there. Godot regressions include actual encoded blobs and a paint-only torn-write recovery.

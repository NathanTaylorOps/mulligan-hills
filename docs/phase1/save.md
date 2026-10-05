# Phase 1: save system (`game/core/save/`)

Status: 4 Oct 2026. NOT YET RUN: nobody could run Godot here. CI has not seen the new files (the earlier partial work passed 353 tests; the tests added in this round are unseen). Python was used only to compute golden values (checksum, draw sequences) and to re-validate the event card JSON.

## 1. What was built

Code (typed GDScript, integers only, no floats after JSON load):
- `mh_save_game.gd` `MHSaveGame`: the save document is a plain Dictionary shaped like `docs/spec/data/save.schema.json`. `normalize` (JSON float64 to int, rejects fractions, NaN, inf, |v| over 2^53, non-string keys, nesting over 48), `u64_hex` / `hex_u64`, `canonical_json` (sorted keys, no whitespace, ints without ".0"), `compute_checksum` / `seal` / `checksum_ok` (sha256 of the canonical JSON without the `checksum` key), `parse_bytes` (loader steps 1 to 4 of SAVE_MIGRATION.md: parse, schema tag, `min_reader_version`, checksum), `validate` (structure of everything the save system owns; the embedded course goes through the optional `course_validator` hook). Entitlement-like keys are rejected. Ironman is cut (DEC-058): `ironman` must be false and `slot_kind` "ironman" is rejected.
- `mh_save_file.gd` `MHSaveFile`: format-agnostic atomic write: `<path>.tmp`, flush, read-back (byte equal and validator accepts), rotate a valid main file to `.bak`, rename tmp over main. A main file that fails the validator is never promoted to `.bak`. Fault injection points for tests and the Gate 0 kill harness.
- `mh_save_store.gd` `MHSaveStore`: slots 0 to 4 (0 = autosave, 1 to 4 manual) in `user://saves`. Files per slot: `slot_N.json` (+ `.tmp`, `.bak`), `slot_N.mhts` (+ `.tmp`, `.bak`), `slot_N.premigrate`. `save_slot` (revision = highest on disk or in the doc, plus 1; sets slot, slot_kind, saved_at_unix, terrain file name and content hash; blob written first, then JSON; post-write read-back verify), `autosave`, `autosave_if_due`, `load_slot` (tries every JSON generation, newest revision first, and every blob generation; the first pair whose blob height hash equals `course.terrain.content_hash` wins; heals the main files; migrates; never returns a partial state), `list_slots`, `export_slot`, `import_slot` (full validation before touching anything; refuses to replace an occupied slot unless `confirmed_overwrite`), `delete_slot`.
- `mh_autosave_policy.gd` `MHAutosavePolicy`: pure rule, save when the game-hour index passes the last saved one (DEC-052). Fast-forwarding over several hours saves once.
- `mh_save_migrator.gd` `MHSaveMigrator`: registry of pure steps per "from" version, applied in order, never skipped; refuses a step that changes `sim.rng_seed`, `sim.rng_inc` or `sim.rating_epoch` (rule 8); step output is re-normalised. `create_default()` is empty while `SAVE_VERSION` is 1; the header comment lists the four steps for adding v1 to v2.
- `mh_cloud_conflict.gd` `MHCloudConflict`: always asks (DEC-058). `detect(local, cloud)` gives IN_SYNC (same checksum), LOCAL_ONLY, CLOUD_ONLY or CONFLICT; any difference is a CONFLICT whatever the revisions say. `rows()` gives day, cash, holes, playtime_s, saved_at_unix for both sides. Choices: KEEP_LOCAL, USE_CLOUD, KEEP_BOTH, CANCEL; `resolve` returns the action the caller must take. `free_manual_slot` finds a slot for KEEP_BOTH.
- `mh_save_summary.gd`, `mh_slot_info.gd`, `mh_loaded_save.gd`, `mh_save_result.gd`: small value types (`MHSaveResult` is named so it cannot clash with the platform layer's own result type).
- `mh_json_file.gd` `MHJsonFile`: crash-safe canonical JSON files with `.bak` fallback, for data that must NOT live in a save slot.
- `mh_player_settings.gd` `MHPlayerSettings`: `user://settings.json`. `analytics_consent` defaults to false and only a real `true` boolean counts (DEC-057 opt-in), `consent_asked`, `install_id` (v4 UUID via `Crypto`). Separate from saves, so cloud sync and imports cannot change it.
- `mh_account_deletion.gd` `MHAccountDeletion`: `build_request(install_id)` (what the backend deletes; purchases are kept) and `delete_local(settings, store, delete_saves)`: resets consent to false, makes a new anonymous id, and deletes local saves only when asked (SAVE_MIGRATION.md rule 11: they stay by default). Tokens and the paid unlock are not touched.

Tests (`game/tests/save/`): `test_save_game.gd`, `test_save_store.gd`, `test_save_migrator.gd`, `test_cloud_conflict.gd` (also covers the autosave policy and its agreement with `MHGameClock`), `test_player_settings.gd` (settings, JSON file, account deletion), `save_fixture.gd` (helpers, not a suite). Temp files go to `user://mh_test_*` folders and are removed in `after_test`.

## 2. How it is tested, and what is NOT run

Everything is NOT YET RUN. Only the Python side was executed:
- The checksum golden in `save_fixture.gd` (`DOC_CHECKSUM`) is the sha256 of `json.dumps(sort_keys=True, separators=(",", ":"))` of the fixture JSON, computed in Python. It proves canonical JSON and `String.sha256_text` agree on ASCII content once CI runs it.
- Test cases cover: round trip and byte-identical re-serialisation, revision counting, `.bak` generations, torn main JSON, all generations damaged (files untouched), bad checksum, kill between blob and JSON (old pair recovered and healed), JSON newer than blob, damaged/missing/mismatched blob, kill mid temp write, kill after `.bak` rotation (finished tmp wins), future `min_reader_version`, slot listing, hourly autosave, export/import with overwrite confirmation, full validation before import, delete, migration through the store with a `.premigrate` copy, migrator registry rules, cloud conflict rules, consent default.
- Fault injection uses `MHSaveFile.fault_point` and `MHSaveStore.fault_point`. The real kill (`KILL_PROCESS`) path is for the Gate 0 item 10 harness, not for these unit tests.

## 3. Gate 0 criteria

Item 10 (kill during save leaves a loadable file at every instant): the JSON and blob pair is now handled by design (this closes the "torn pair" gap noted in `docs/spec/interfaces/save.md`). CI evidence needed: the tests above green, plus the F device harness run with `fault_action = KILL_PROCESS` against `MHSaveStore.save_slot` at both fault points and `MHSaveFile` at all three.

## 4. Unverified assumptions

- `RegEx.create_from_string`, `Crypto.generate_random_bytes`, `String.sha256_text`, `JSON.stringify` of strings (escaping) and `DirAccess.rename/remove` semantics on Android and iOS `user://` are used as documented for Godot 4.x but were never executed.
- A lambda used as a validator callable inside a static function (`MHJsonFile.write_dict`).
- `FileAccess.flush()` is not a guaranteed fsync: process-kill safety is designed for, power-loss durability is not proven.
- Godot's JSON parser reads every number as float64; ints above 2^53 would lose precision before `normalize` sees them, which is why 64-bit values are hex strings.

## 5. Risks and follow-ups (for the lead, not owned by this workstream)

1. Schema gaps: FIXED. `save.schema.json` now has the optional additions `world.minute_of_day` (0..659, DEC-052), `progress.playtime_s`, `progress.tournaments.hosted_count/attempted_count`, `progress.stats`, `progress.streak` and `progress.daily`; `ironman` is optional and must be false, `slot_kind` is autosave/manual/backup (DEC-058). `save_version` stays 1: the new fields are optional, so old v1 saves stay valid and readers use defaults (SAVE_MIGRATION.md rules 12 and 13). `MHSaveGame.validate` checks them (`test_save_progress.gd`).
2. The terrain pairing hash (`course.terrain.content_hash`) is the 32-bit FNV-1a of heights only. A torn pair that differs only in paint layers (splat) would not be detected. The blob header already holds a splat hash; adding it to the JSON is a schema change.
3. Cloud upload and the real conflict prompt belong to the platform and UI workstreams; this module only provides the model and the validated export/import calls.
4. `MHSaveGame.course_validator` must be set by the course module so the embedded course is checked on load and save (loader step 7).
5. The sim and rating versions in `written_by` and `ratings.rating_version` are stored but the "recompute ratings on version mismatch" step (loader step 8) is the rating module's job.
6. After loading, the game must set `store.last_saved_hour = MHAutosavePolicy.hour_of(clock.total_minutes())`, otherwise the first hour after load saves immediately (harmless, one extra write).
7. Heal after a "JSON newer than blob" recovery rewrites the older JSON as the main file and moves the newer one to `.bak`. The next load tries the newer one first and falls back again until the next save. Correct, slightly wasteful; acceptable.
8. Export presets: `export_presets.cfg.template` now includes `data/*.json, data/*/*.json` next to `build_info.json` (checked by validate.py). Still to confirm on a real device export that the JSON files are packed.

## 6. For Nathan

Nothing to do yet. Questions are in `docs/phase1/clock_events.md` section 6 and in the final hand-off.

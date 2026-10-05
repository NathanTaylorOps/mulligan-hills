# Phase 1: live construction and exact checkpoints

> 5 October follow-up: `one_hole.md` adds an exact short-hole finalization/rating/save and aim-controlled practice prototype. Earlier zero-hole limits below describe the preceding increment. Legacy polygon conversion, full terrain authoring and finished golfer RPG remain unresolved. See `simgolf_controls_research.md` for Nathan's requested controls research.


Status: 5 October 2026. Implementation and regression tests written. Python schema, economy and clock checks PASS; third-party GDScript syntax parser PASS. Godot import/tests, rendered scene and device checks NOT YET RUN. Separate static review in `live_construction_verification.md`; no completion certification.

## What this increment connects

Launcher entry: **Live construction (ground, club, saves)**, `res://gameplay/mh_live_construction.tscn`. It uses `MHGameSession` and `MHLiveGameStateView`, not gallery sample cash or scores. Existing 3D terrain chunks, orbit camera and gesture router are connected to the actual editor toolbar. One finger edits while the Editor screen is open; two fingers use the existing camera gesture path. Paint has all eleven existing surfaces. Undo/redo reads the real editor history and remains available while the clock is paused. Menus suppress world gestures; leaving editor/focus clears transient pointer state. Overlay mouse presses/releases are consumed so they cannot also click the GUI twice.

Clock input uses integer elapsed microseconds from `Time.get_ticks_usec`, not repeated float frame conversion. The day remains 25 minutes, hourly accounting remains in the session, and suspension catch-up remains capped by the clock. Existing building/land intents recheck gates/prices; recovery-loan success now recognizes the actual loan API's non-negative amount return instead of comparing that amount with zero.

Save requests are coalesced at the scene. Open brush strokes are not serialized: normal saves wait for commit; focus loss and Save & launcher cancel an uncommitted stroke first. Save and reload failures are displayed; existing damaged/unsupported slots are not replaced with new defaults. A failed write does not retry every frame.

## Honest scope limit

This is a live **ground-construction and club-accounting integration**, not a finished course editor or golfer RPG. There are zero finalized golf holes. Surface paint is not automatically a rated hole, and the scene does not invent a tee/green or count painted grass as playable holes. `MHSessionSave` explicitly rejects both a session with finalized RHI holes and an existing save containing finalized course holes until authoritative dm/polygon -> RHI conversion exists. Current staff/pace sources remain absent, so tournament entry remains honestly blocked. No personal golf, XP, rival gameplay, celebrity residency or applied trophy skins are implemented here.

The 128x128-cell patch, fixed development install/course identifiers, test platform writer tag, floating Save/launcher controls and lack of first-launch flow are integration-scene choices only. They are not final map dimensions, production identities, onboarding or phone layout sign-off. Procedural buildings are not yet placed/rendered in this scene.

## Save boundary

`MHSessionSave` captures and restores a NEW session, never partially mutates the running one on failure. The official `mh.save` schema now has optional `runtime`:

- Exact integer economy state: cents, member/arrival remainders, upkeep, loan/arrears/recovery state, tiers and counters.
- Exact clock position, fractional accumulator, pause, speed and prepaid credit; save secret and fourteen daily course-score samples.
- Equality hash of the separate ledger generation, without storing token balances or claim keys in the slot.
- Full terrain-byte equality digest assigned by `MHSaveStore`: SHA256 of the lowercase hex text of the entire compressed blob, including paint.

These files declare `min_reader_version = 2`; the reader is now 2. Save version remains 1 because the block is optional; older slots remain structurally readable. The live construction scene refuses slots without its exact checkpoint instead of guessing lost accounting. Club whole-dollar fields mirror the exact runtime values; the runtime block preserves cents. Current live reputation mirrors the economy permille value; no reputation-achievement conversion was guessed.

Restore checks checksum, schema/types/ranges, official world time vs runtime clock, clock vs economy day/hour, empty course vs economy, ownership/counts, parcel flags, building tiers, club mirrors, progress and ledger generation. Unsupported or inconsistent data fails before returning a session.

`MHSaveStore` still retains the legacy terrain height FNV reference. Runtime checkpoints additionally pair by the full blob digest in save/load/import. This prevents an old JSON/accounting checkpoint matching a newer paint-only blob after a crash; heights alone cannot distinguish those generations. Legacy slots retain their existing pairing behavior.

## Development storage and limitations

The scene isolates its official slot store under `user://phase1_live/saves` and its earned-only ledger generations under `user://phase1_live/ledgers`. Ordinary user save slots and `user://tokens.json` are untouched. Each ledger generation is content-addressed and written before the world checkpoint; previous generations remain available to a recovered older JSON/blob pair. This avoids destroying the matching ledger when a later world write fails.

Ledger garbage collection remains unimplemented: this development scene retains generation files. Cloud/import reconciliation of these development ledger references and production identity generation remain open. No power-loss/fsync guarantee, store entitlement integration or production save rollout is claimed. Process-kill recovery is designed and tested in pending Godot regressions, not yet demonstrated on Android.

## Checks and API evidence

- `python3 docs/spec/data/validate.py`: ALL PASS, including `live_save.example.json` and malformed-runtime negative examples.
- `python3 tools/reference/economy/selftest.py`: PASS.
- `python3 tools/reference/clock/check_clock_vectors.py`: PASS.
- `gdparse` on changed/new GDScript: PASS, syntax only. It is not Godot's type analyser.
- `game/tests/gameplay/test_session_save.gd`: exact state roundtrip; inconsistent mirrors/time/land/tiers; malformed capture; reader/version/type rejection; legacy-slot refusal by the live adapter; missing/corrupt/mismatched ledger; failed world write after a newer ledger; paint-only AFTER_BLOB torn write; live scene pause/paint/history/purchase/save/reload smoke coverage.
- Added coordinator loan-success, paused editor-history and suppressed-pointer regressions in `test_game_session.gd`.

New `PackedByteArray.hex_encode()` usage was verified against [official Godot API documentation](https://docs.godotengine.org/en/stable/classes/class_packedbytearray.html#class-packedbytearray-method-hex-encode). SHA256 text hashing already exists in the save module. Camera, picking, terrain, UI, notification and file method signatures were checked against existing repository call sites. Actual Godot 4.7.2 import/render behavior remains a CI/device check, not a verified outcome.

## Next implementation

1. Finish an authoritative finalized-hole geometry path, including save/load and official rating, without approximating arbitrary polygons as rectangles.
2. Add golfer creation/control and resume-safe round state on one saved player-built hole (DEC-072).
3. Connect training, one NPC rival match and one earned visible reward.
4. Extend staffing, competition, VIP/animals and maintenance from the locked requirements; jointly recalibrate the campaign.

For Nathan, once the latest Android APK is green: first run Sim hash, then Benchmark Quick 60s. Then open Live construction and test pause -> paint -> undo -> redo -> buy a Clubhouse -> Save & launcher -> reopen. It should retain the painted ground, purchase, cash and pause state. Do not use it to judge golf gameplay yet. Low-end phone purchase, Supabase setup and official trademark search remain Nathan's tasks.

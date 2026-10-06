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

## Responsive layout and orientation (6 October)

Device report (Galaxy S22 Ultra, landscape): HUD, bottom nav, floating Save / Save & launcher, the one-hole panel and the status line were stacked on top of each other and the status label wrapped one character per line.

Root cause: the scene added its own controls to a bare `CanvasLayer` at hard-coded positions (Save row y=180, status y=245, one-hole panel y=285) while the HUD (a full-rect VBox with a wrapping chip row, a wrapping speed row and the nav bar) occupies the same area, with a height that changes with width, text scale and safe area. The status `Label` had autowrap on and no container, so its width was its minimum (about one character). The panel was sized once at setup from the viewport width. The dock was also a sibling of the shell, so it never received the shell theme (`ChipButton`, `CardPanel` variations fell back to plain buttons).

Fix (all UI units, no absolute positions):
- `MHHudScreen` and `MHEditorScreen` keep their middle spacer as a named slot and report it via `free_rect()`; `MHUIShell.overlay_free_rect()` / `overlay_active()` expose the rectangle between the top controls and the bottom nav (already inside the safe-area margin).
- `MHLiveLayout` (pure, `game/ui/mh_live_layout.gd`) splits that rectangle into three zones that cannot intersect: actions (wrapping flow of touch_min-high buttons), status (fixed 2-line chip, clipped, real width), panel (HIDDEN / COLLAPSED header only / OPEN). Landscape: panel is a side column (left when left-handed), actions and status stack in the other column. Portrait: actions, status, then a bottom sheet that leaves at least 25% of the free height to the 3D view when possible.
- `MHLiveConstruction` owns a `_dock` (themed like the shell) holding the three zones and re-places them only when the free rect, touch size, text size, panel state or handedness changes (polled in `_process`, because the HUD only has a rect after its first layout pass).
- `MHOneHolePanel` is now header (title + Hide/Show) over a scroll box holding the text and button flows. Collapsing hides the body; `Close` still closes it. No size or position is set by the panel.
- `MHTouchBridge` now clips a button's tap rectangle by any scroll container above it (`visible_rect`), so a button scrolled out of view cannot take a tap meant for the HUD or nav drawn there. This is shared code and also fixes the same latent problem on scrolled pages.
- Router UI regions for the three action buttons return an empty rect while the button is hidden.
- `_fail()` screen uses a margin container (it had the same zero-width label problem).
- Dock is hidden while a full page (Build, Land, Rating, Menu) or a modal is on top; previously the Save buttons floated over those pages.

Orientation: `MHOrientation` (`game/ui/mh_orientation.gd`) is the single switch. `DEFAULT_GAME = SENSOR_LANDSCAPE (4)`; override with project setting `mulligan/ui/game_orientation` if `[mulligan] ui/game_orientation=...` is added to project.godot (not edited here; project.godot belongs to workstream A). Live construction calls `apply_game()` in `_ready` and `restore_default()` (project-wide `display/window/handheld/orientation`, currently 6) in `_exit_tree`. Calls are skipped unless `OS.has_feature("mobile")`, so desktop/CI never touch it. `export_presets.cfg.template` has no Android orientation key (Android reads the project setting); its iOS key `launch_screens_interface_orientation=6` only concerns the launch screen. Locking the whole app instead means changing `display/window/handheld/orientation` from 6 to 4 in project.godot (one line). Nathan has not confirmed landscape-only.

Tests: `game/tests/ui/test_live_layout.gd` (zone rects inside the free rect and pairwise disjoint for six viewport/touch-size cases x three panel states x mirror, touch-target and width floors, side column vs bottom sheet, collapsed header height, flow rows, degenerate tiny rect, orientation sanitising, bridge clip maths). NOT YET RUN: Godot cannot run in this environment.

Unverified engine APIs introduced (all documented Godot 4.x API, none exercised here):
- `DisplayServer.screen_set_orientation(orientation)` with an int cast to `DisplayServer.ScreenOrientation`, and the enum values 0..6 (landscape, portrait, reverse landscape, reverse portrait, sensor landscape, sensor portrait, sensor). Whether Android honours a runtime change on the S22 Ultra without an activity restart, and that `SCREEN_SENSOR_LANDSCAPE` allows both landscape flips, need a device check. The manifest orientation still comes from the project setting (6), so the app may start in portrait and rotate after the scene loads.
- `Label.max_lines_visible`, `Label.text_overrun_behavior` with `TextServer.OVERRUN_TRIM_ELLIPSIS`, `Label.clip_text`.
- `CanvasItem.visibility_changed` signal on the panel; `Node.is_ancestor_of`.
- `Rect2.intersection`, `Rect2.intersects(b, false)`, `Rect2.encloses`, `Rect2.has_area`, `Vector2.max`.
- `Control.theme` assignment on a node outside the shell, so the dock uses the shell's `ChipButton` / `CardPanel` / `HudChip` / `SmallLabel` variations.
- A `Control` whose `size` is set to less than its container minimum is clamped up by the engine; the layout math assumes the minimums stay below the zone sizes (touch_min rows, one-line header). Larger text scales could make the collapsed header or action rows taller than computed; clip_contents bounds the damage but this needs a device pass at 160% text size.

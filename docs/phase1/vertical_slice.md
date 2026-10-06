# Phase 1: first playable vertical slice (buildings, nature, golfers, HUD)

Status: 5 October 2026. Written without Godot. **NOT YET RUN**: no import, parse, test run, render or device check has happened. A bracket and indentation scan passed; that proves nothing about Godot 4.7.2 typing. Treat the first CI run as the first real test and expect small parse or typing fixes (see `README.md` lessons).

## What it is

New launcher entry **Vertical slice (buildings, golfers, HUD)** -> `res://gameplay/mh_vertical_slice.tscn` (`MHVerticalSlice`, `game/gameplay/mh_vertical_slice.gd`). It is a sibling of the live construction scene, not an edit of it. It starts a fresh in-memory `MHGameSession`, builds two starter holes through `submit_course`, sets the fee to the economy's own `suggest_fee()`, and then runs the clock like the live scene does (`session.advance(elapsed_us, wall_unix)` every frame).

Nothing is saved or loaded and nothing is written to `user://`, so ordinary slots and the live construction slot are untouched. There is no terrain editing here; the ground is a flat 128 m course.

1. **Buildings.** Each bought tier appears as `MHBuildingMeshes.build(id, tier, "a")` on its parcel and is replaced when the tier changes. The sim has no tier-3 spec state, so spec "a" is always drawn.
2. **Nature.** `MHSliceNature.scatter(seed, 90)` (integer `MHArtRng`) around the course, grouped into MultiMeshes per (kind, LOD, variant). Default seed `MHVerticalSlice.NATURE_SEED`.
3. **Golfers.** The economy's hourly golfer number is mirrored by `MHSliceSchedule`, cut into groups of up to 3, released one group per tee slot (12 game minutes, from `tee_groups_per_hour`). A group walks the hole: swing at the tee with a ball arc, walk, putt, walk off. Caps below.
4. **HUD.** One chip with cash, day and clock, course rating, income per game hour (gross, from `estimate_day()`), golfers on course, then fee, net per day, holes, members. Buttons: Pause/Resume, Speed, Fee -/+ $1, Build hole, Buy land, Buildings menu, zoom, rotate, Quality, Back. The Buildings menu lists all ten buildings with state text and a Buy button that sends `buy_tier`; Build hole calls `submit_course`; Buy land sends `buy_parcel`. Prices shown are the real charge (`economy.price_cents`), not `defs.price_for`.

Camera: `MHCameraController`. Mouse drag/wheel and one-finger drag/pinch move it (`_unhandled_input`; UI buttons consume their own touches through `MHTouchBridge`). No gesture state machine is used.

## Layout rules (all in `MHSliceLayout`, pure)

- 4x4 parcels of 32 m (same 320 dm as the live scene), parcel id = row * 4 + col. A parcel has a 2x2 grid of 16 m cells. A building is scaled DOWN (never up) so its tier-5 footprint fits a cell with a 1 m margin, using the tier-5 bounds, so it does not shift or resize relative to its cell when upgraded.
- Hole sites: 8 fixed slots (`HOLE_ORIGINS_DM`), two per parcel column, so the four start parcels (5, 6, 9, 10) already hold four holes. Parcels under any hole site are RESERVED and never hold a building. Remaining parcels: golf 1, 2, 13, 14, facility 8, 12, homes 3, 15.
- Building slots: light buildings prefer facility parcels, heavy ones free golf parcels, homes prefer homes parcels; only OWNED parcels count. When none has a free cell, the building goes to an ANNEX strip south of the map (z 132..164), so every bought tier is always drawn. Slots are sticky: a placed building never moves when land is bought (`assign_slots(tiers, owned, previous)`).
- At the start only parcel 8 (facility) is owned and free, so the first four buildings fill it and the fifth goes to the annex. Buying land (recommended order: parcel 1, then 2) opens real cells.

## Performance design (targets: 30 fps floor, DEC-061)

Estimated, NOT measured. Draw calls at the default low tier: ground 1, course props at most 2 MultiMeshes, nature about 31 MultiMesh groups (Python mirror of the integer scatter, seed 20261005: 90 items, 31 groups, at most about 9.5k triangles), buildings at most 10, golfers 2 joint-tree figures (12 draws each) plus up to 8 baked single-mesh golfers, balls at most 6. That is roughly 100 draw calls before UI. Shared material everywhere, no shadows (sun shadow off, `cast_shadow` off), no transparency.

Golfer caps (`MHSliceVisibility.CAPS`, guesses until the phone is measured):

| Tier | Figures (LOD0, 12 draws each) | Total visible |
| --- | --- | --- |
| low (default) | 2 | 10 |
| medium | 4 | 16 |
| high | 8 | 28 |

The nearest golfers by camera distance become figures (one figure per look, so a second near golfer with the same look is baked), the next ones become one baked mesh each (`MHGolferMeshes.build_posed` at LOD1 under 70 m, LOD2 beyond, three frozen poses: idle and two walk steps, cached per look/LOD/pose), the farthest are hidden. Figures are posed directly with `set_pose(MHGolferPoses.sample(...))`; their own `_process` is switched off. Everything is pooled and hidden, never freed per frame. The HUD Quality button cycles the caps live.

## Sim safety

Rendering reads only: `MHSliceSchedule.hour_golfers_expected_milli` recomputes the economy's hour formula from public state without touching it; building/course sync reads `session.tiers()`, `land.owned_ids()`, `hole_definitions()`. The session changes only through `handle_intent` and `submit_course` from buttons. A regression (`test_drawing_never_changes_the_sim`) runs the scene and a bare session through the same 600 steps and compares `economy.state_list()`. Visual golfer counts mirror the economy by formula but use their own carry, so the picture can differ from the booked golfer count by one golfer; it is not an accounting record.

## Findings that matter for the design

- The existing 60 yd plain-fairway test hole rates 22 and is dead (< 25). With one such hole the economy brings 0.3 to 2.4 golfers per day. So the slice uses a short par 3 (64 yd, fairway, bunker, water, two trees) that the Python rating reference (`tools/reference/rating`, seed 0) scores 42, 34, 40, 44, 40, 46, 43 and 41 for slots 0..7 (none dead; the plain hole scores 22). Four such holes at rating 40 give about 26 golfers per day at an $8 fee (Python economy reference). This is the economy's truth: a 4-hole 64 yd course still earns less than its upkeep (about $365 a day for 4 holes and 5 parcels), so cash drains slowly. Not tuned or hidden.
- At 25 real minutes per game day and about 20 to 26 golfers a day, one group tees off roughly every 3 real minutes at 1x, so the course looks sparse. Speeds above 1x cost tokens; visual walking is capped at 2x so groups overlap at 4x and 8x and the caps do the work.
- Six of ten buildings have `demo_max_tier` 0, so with the default `demo = true` they cannot be bought. The slice sets `session.demo = false` in memory (`UNLOCK_FULL_GAME`, development only, never saved) so all ten can be tested. Flip the constant to test the demo limits.

## Tests (NOT YET RUN), `game/tests/gameplay/`

- `test_slice_layout.gd`: order equals art ids, reserved parcels never preferred, hole corridors inside their parcels and the map, every hole template passes `MHRatingEngine.validate_input`, hole-site availability from ownership, slot centres, fit scale, transform centring, slot assignment (start parcel then annex, unique, never reserved, homes parcel, heavy preference, stickiness, determinism, invalid previous slot), real session builds the starter holes and they are not dead.
- `test_slice_schedule.gd`: group splitting, carry, one group per tee slot, skipped slots, queue cap, determinism, expected hour equals the economy's `tick_hour` golfers for all 11 hours, expected-hour call changes nothing.
- `test_slice_round.gd`: timeline ordering, swing before walk, ball only after impact, walk/putt/exit/done, monotonic progress, facing yaw turns the right local axis toward the hole, group spread, ball parabola.
- `test_slice_visibility.gd`: nearest become figures, total cap hides the farthest, same-look rule, tie rule, zero caps, random-input invariants (caps never exceeded, distinct figure looks), tier caps ordered and at most 8 figures.
- `test_slice_nature.gd`: determinism, different seed differs, valid kinds/variants/LOD/scale/extent, exclusions respected, grouping keeps every item and stays at 36 groups or fewer, every group's mesh within its triangle budget.
- `test_slice_text.gd`: HUD text helpers, synthetic and real build-menu rows.
- `test_vertical_slice_scene.gd`: scene loads, launcher lists it, starter state, a bought building appears at its parcel and its mesh changes with tier, ten buildings get distinct non-hole places, buying land does not move buildings, holes build until the start parcels are full, a full game day of ticks keeps golfers within the caps and spawns groups, the sim is unchanged by drawing, pause freezes golfers, quality cycling, menu rows, HUD text, golfer manager caps and cleanup.

## Unverified (check on the first CI run)

Engine APIs and syntax used from memory of the Godot 4 docs, none exercised here:
- `Basis.from_scale` multiplied by `Basis(Vector3.UP, angle)`; `Transform3D(Basis, Vector3)`; `Node3D.rotation` assigned a `Vector3`; `Camera3D.global_position`, `near`, `far`.
- `Array.sort_custom` with a multi-line lambda; typed `for x: Type in [literal array]`; `String.trim_prefix`, `capitalize`, `", ".join(PackedStringArray)`.
- `@warning_ignore_start("integer_division")` (already used in the session) and the class constants `MHVerticalSlice.UNLOCK_FULL_GAME` etc. referenced from tests.
- `Control.theme` set from `MHTheme.build(100)`; `MHUIKit.panel/label/hbox/vbox/flow` and `MHTapButton.make` as used in existing screens; `MOUSE_BUTTON_WHEEL_UP/DOWN`, `InputEventMouseMotion.button_mask`, `InputEventScreenDrag.relative`.
- `MultiMeshInstance3D` made by `MHArtMaterials.make_multimesh` and `cast_shadow` set on it; `MeshInstance3D` created with a null mesh by `MHArtMaterials.make_instance(null, ...)`.
- Headless: `MHSliceGolfers` and `MHGolferFigure` built without a tree; the whole scene under the dummy renderer with its CanvasLayer/Control HUD.
- gdUnit4: `assert_array(...).contains_exactly`, `assert_float(...).is_between/is_less/is_greater_equal/is_less_equal`, `assert_int(...).is_between`, `assert_str(...).is_not_equal`.
- `MHGameSession.submit_course` accepting the bunker/water/tree template: validated only by the Python `validate_input`, and its scores only by the Python rating reference. If the GDScript engine disagrees, `test_the_real_session_can_build_the_starter_holes_and_they_are_not_dead` fails and says which slot.
- The Python economy numbers above come from `tools/reference/economy`; the nature group count comes from a Python port of `MHArtRng` and the scatter. Neither is the GDScript.

## Known limits and risks

- Not a finished hole editor: hole sites, the template hole and the parcel/cell grid are development choices. Parcel size (32 m) is not a production number (DEC-056); a 64 yd hole is 58 m.
- Water of one hole can overlap the fairway edge of its neighbour 16 m away (cosmetic). Golfers are not routed around water or trees; they walk the straight tee-green line, and putt without a ball.
- A touch that starts on a button and then drags will also pan the camera (the touch bridge does not consume drags).
- Playing as a golfer, XP, staff, tournaments, saves and the practice/personal-golf screens are not in this scene.
- Quality tier is a local variable (default low), not read from settings; caps are guesses.

## For Nathan, after a green APK

1. Launcher -> Vertical slice. Expect a green course, trees around it, two holes and (after a minute or two) groups of golfers teeing off. If nothing moves, tell me the Golfers count on the top line.
2. Tap Buildings, buy a Clubhouse: a building should appear on the facility parcel at the left. Buy more: the fifth lands in a strip below the map until you Buy land.
3. Try Quality low/medium/high and Speed. Note the frame rate with the debug overlay on the S22 Ultra and a low-end phone; I need those numbers to set the golfer caps.

# Authoritative hole finalization and practice

Current note, 7 October 2026. The original flat rectangle/width/water-toggle prototype described in this file's history has been superseded by shared-terrain craft authoring. [Live construction](live_construction.md) is the current integration overview.

## Build the player's hole

The editor uses the real `MHCraftHole` draft. `MHCraftConvert` produces the canonical layout and relief; `MHOneHolePanel` checks craft problems, rating input and owned-land placement through `MHCourseLayout` before `MHGameSession.submit_course` rates it. Construction price comes from the existing economy. Official ratings never read the player's practice results.

Readiness includes green radius (5–30 yd), tee-to-pin length (60–1,000 yd), legal markers and property ownership. Painting over a pin can temporarily invalidate a draft without removing its edit controls. Repair is optional and cannot enlarge an already valid green just to restore its flag tile.

The current scene authors hole 1 at its development origin. A loaded finalized hole is preserved exactly and opens in practice. Editing that built hole needs a supported inverse/persisted authoring roundtrip; do not reconstruct a fake rectangular replacement. Extra draft pin slots are saved while unfinished; current finalization and practice use pin 1.

## Play and resume

Aiming moves a target; Play shot commits one automatic shot. Practice reuses the official integer flight/dispersion/lie/tree/penalty simulation and canonical relief. The ball marker follows the result. Current practice starts at scalar skill 500 with a deterministic seed; restarting is reproducible.

Exact position, lie, strokes, next shot and terminal state survive the existing checkpoint. Restore checks the geometry hash and does not charge construction or grant achievements again. Practice ends when holed or picked up; it is not the full future golfer avatar, career, shot-style, rewards or NPC satisfaction system.

## Geometry and save compatibility

`MHCourseLayout` stores exact primitive canonical holes with a world-dm origin and local whole-yard rating layout, including millimetre relief. One yard remains exactly 914.4 mm at the boundary. Owned-land tests remain conservative and authoritative. Legacy polygons are not silently approximated or erased.

Finalized layouts/practice require reader 3; exact unfinalized craft checkpoints require reader 4. The current scene accepts one fixed-origin supported primitive profile; the general codec can represent more than this view. `MHSessionSave` requires document/session geometry agreement and pairs the slot with the exact terrain blob and ledger generation.

## Evidence and next gate

Nathan's Windows Godot 4.7.2 probe at `940f3da` passed the edit/build/practice chain; the preceding stable checkpoint also passed graphical testing. Later editor work adds actual disk reload, precision and marker-workflow coverage to `manual_verify_live_ui.gd`. That expanded probe and the new UI have not yet been run in Godot in this session.

[Historical independent verification](one_hole_verification.md) records the original primitive-hole increment and is not current completion certification. Use [Development guide](../DEVELOPMENT.md) for the combined headless batch, then graphical/mobile testing.

Pending work includes built-hole authoring roundtrip, multi-hole routing, final terrain presentation, real golfer navigation/shot loops and device performance. Preserve the canonical chain while extending these.

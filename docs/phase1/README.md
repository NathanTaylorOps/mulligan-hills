# Development notes

The `phase1` folder contains implementation notes from several development stages; its name is historical. The current priority is **course-editor UX → sculpting → surface painting → hole design → terrain art**, with mobile first and desktop support alongside it.

Start with the [project README](../../README.md) and [development/testing guide](../DEVELOPMENT.md).

| Current reference | Contents |
| --- | --- |
| [Live construction](live_construction.md) | Canonical scene, terrain bridge, controls, checkpoint boundaries and limits |
| [Terrain designer](terrain_designer.md) | Exact model, conversion, tools and outstanding authoring work |
| [One hole and practice](one_hole.md) | Build/rating/practice/save contract |
| [Editor experience](editor_experience.md) | SimGolf/Under Par reference findings, design direction and usability targets |
| [Decisions](../DECISIONS.md) | Recorded constraints and superseded choices |

Dated verification, CI-recovery and handover reports are historical evidence. Read their dates/SHAs; they do not certify current HEAD. The separate [vertical-slice presentation demo](vertical_slice.md) must not become a second course-authoring architecture.

Nathan supplied a Windows Godot 4.7.2 live probe PASS at `940f3da`, following a graphically verified stable checkpoint. New editor work has static syntax checks and expanded tests; its engine/device execution is pending.

## Godot 4.7 lessons learned in CI (apply always)
- `const X = SomeClassName` aliasing a class_name script is a parse error: use `preload("res://path.gd")`.
- No `OS.get_power_percent_left` in Godot 4. Battery is manual.
- `PackedInt32Array` is signed: mask with `& 0xFFFFFFFF` when you need unsigned.
- Tests `extends GdUnitTestSuite`, files `test_*.gd`, folder `game/tests/<module>/`, must pass headless with no display and no user:// leftovers.
- Grep for `class_name` before naming a class (prefix `MH`). Typed GDScript, tabs, no float math in `game/core/`.
- Parse errors anywhere break the whole test run, so keep code conservative and re-read every file once for syntax.


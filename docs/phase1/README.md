# Phase 1 (device-independent slice)

Authorised by Nathan on 29 Sep 2026: build everything that a phone test cannot invalidate, plus UI screens, while Gate 0 device tests wait (see DEC-061). Art is fully procedural from code (DEC-062). Every workstream writes a status doc `docs/phase1/<name>.md` in the Phase 0 status format (built, tested, NOT YET RUN, unverified, risks, for Nathan).

## Godot 4.7 lessons learned in CI (apply always)
- `const X = SomeClassName` aliasing a class_name script is a parse error: use `preload("res://path.gd")`.
- No `OS.get_power_percent_left` in Godot 4. Battery is manual.
- `PackedInt32Array` is signed: mask with `& 0xFFFFFFFF` when you need unsigned.
- Tests `extends GdUnitTestSuite`, files `test_*.gd`, folder `game/tests/<module>/`, must pass headless with no display and no user:// leftovers.
- Grep for `class_name` before naming a class (prefix `MH`). Typed GDScript, tabs, no float math in `game/core/`.
- Parse errors anywhere break the whole test run, so keep code conservative and re-read every file once for syntax.

# Phase 1: Staff (`game/core/staff/`)

Status: built and verified in Python. The GDScript and the gdUnit4 tests have NOT YET RUN: Godot could not run where this was written. Spec and numbers: `docs/spec/staff.md`, `docs/spec/data/staff.json`.
Owner paths: `game/core/staff/`, `game/tests/staff/`, `tools/reference/staff/`, `docs/spec/staff.md`, `docs/spec/data/staff*.json`, `game/data/staff.json`, this file. One small additive edit outside: `game/core/save/mh_save_game.gd`.

## README block

**Purpose.** Eleven staff roles tied to the ten buildings, hiring and hourly wages in cents, area assignment on the 4x4 parcel grid, per-parcel condition and pest pressure, deterministic animal incidents, and the effects on demand, tournament pace and the tournament staff gate. The official rating (MHSIM-1.0.0) is not touched.

**Public API.**
- `MHStaffDefs.load_default()` / `load_from_dict(d)` / `load_from_text(s)`: reads `res://data/staff.json`, validates, exposes `param`, `cap`, `wage`, `hire_cost`, `role_*`, `grade_of`, `work_permille`.
- `MHStaff.create(defs)`: facade. `hire`, `fire`, `assign`, `auto_assign`, `pay_hour`, `on_day`, `personal_mow`, `personal_patrol`, `demand_permille`, `pace_points`, `condition_penalty_permille`, `overlay`, `gate_staff_count`, `legacy_counts`, `report`, `state_list`, `to_save_block`, `from_save_block`.
- `MHStaffView.make(...)`: the club view Dictionary (tiers per building, owned parcels, parcel kinds) that every call takes. The caller builds it from the buildings state and the land.
- Economy wiring recipe (no edits to `game/core/economy`): see the header of `mh_staff.gd` and section 11 of the spec.

**Save.** Optional `club.staff_roster` (additive, `save_version` unchanged). `save.schema.json` and `MHSaveGame._validate_club` accept it; a save without it still validates.

**How tests run.** gdUnit4 headless, `game/tests/staff/` (64 tests in 6 suites plus `staff_fixture.gd`). `test_staff_golden.gd` replays 5 scenarios (starter, neglect, personal, rangers, late) from `golden/staff_golden.json` and compares every op result and state vector with the Python reference. Regenerate with `python3 tools/reference/staff/gen_golden.py` (also copies `staff.json` to `game/data/`).

## What was run

| Check | Result |
|---|---|
| `python3 tools/reference/staff/selftest.py` | ALL PASS |
| `python3 tools/reference/staff/gen_golden.py` | wrote `game/data/staff.json` and golden (167 KB) |
| `python3 docs/spec/data/validate.py` | ALL PASS (staff.json, roster block, negative tests, runtime copy) |
| `python3 tools/reference/staff/staff_sim.py` | report in `staff_sim_report.txt`, 20 runs per cell |
| Godot / gdUnit4 | NOT YET RUN |

## NOT YET RUN: what to check first when Godot is available

1. Parse errors: run the whole test suite once. All GDScript was read through by eye only.
2. Things written from memory of Godot 4.7 that could differ: `Array.remove_at`, `Array.sort()` on ints, `mini`/`maxi`/`clampi`, `1 << 30` as a large sentinel, `Variant` loops with typed `for x: Variant in`, `JSON.parse_string` returning floats for ints (the loader converts with `int()` and checks `is_equal_approx`-free integer equality), `FileAccess.get_file_as_string`.
3. `MHRMath.h32d` is called with `(secret, day, parcel, 0x57)`; the Python mirror is `rating_core.H32`. `test_staff_golden.gd` and the `h32` vectors catch any mismatch.
4. gdUnit4: tests collect errors into an Array and assert it is empty; none uses `override_failure_message`.
5. `mh_save_game.gd` edit: `_validate_staff_roster` and the `_only_keys` list. The save tests in `game/tests/save` must still pass.

## Risks and gaps

- `mh_session_save.gd` (gameplay, not edited) rejects a non-zero `club.staff`, and `game/ui` plus `MHGameSession` use `staff = 0`. The roster is not wired into the live game until the gameplay owner does it (recipe in the spec).
- Pace base source (`min_pace_score`) is still undefined; staff only adds points.
- `incur_loss` wage arrears can trigger the existing bankruptcy rule.
- Strings are drafts in `game/core/staff/staff_strings_en.json`; they are not merged into `game/data/strings/en.json`.
- Full delegation (hire every role) lowers the share finishing in the 100 to 150 day window from 83.7% to 79.9%.

## For Nathan

1. Wire-up: who owns the session and UI changes (roster screen, hire buttons, assignment screen)? Nothing player-facing exists yet.
2. Is a veteran grade at 60 days right, and should full delegation be a bit cheaper (about 15% lower wages)?
3. Should unpaid wages make staff walk out?
4. Should condition ever enter the official rating? That needs a versioned rating (MHSIM-2) first; the overlay is UI-only until then.

# Phase 1: exact finalized hole and personal practice prototype

Status: 5 October 2026. Implementation, schema fixture and regression coverage written. Python schema validation and reference shot calculation PASS; third-party gdparse PASS. Godot import/tests, rendering, touch and device evidence NOT YET RUN. Independent review: `one_hole_verification.md`.

## Built

In Live construction, **Build / play one hole** opens a separate exact-layout view. Adjust a 60–62-yard short par 3, its fairway half-width and optional side water. The first finalized hole uses the existing economy construction price, displayed before committing; redesign is free. Submission validates ownership/geometry and obtains an official rating before charging. A very short hole can be valid but dead for progression; the Python reference's plain 60-yard test hole scores 22 (224 permille), below the existing 25 gate. No gate was weakened to make the prototype look successful.

Aim controls move a yellow target and Play shot commits one automatic shot. Flight, skill-based dispersion, club selection, lies, trees and penalties reuse the official integer sim's flight function. A white marker follows the ball. Practice starts with scalar skill 500 and a deterministic seed. Shots preserve exact position/lie/strokes/next draw through save/load. A redesign invalidates the old practice round. Official rating never reads practice results; reload does not charge or grant achievements again.

Practice ends when holed or picked up at par+4; a penalty can take the final count one higher. Putting is a simple individually aimed, capped-distance prototype; it is not the final skill-based putt model. No money/XP/stakes/rewards are awarded. Restart uses the same seed for reproducible testing.

## Geometry and saves

`MHCourseLayout` provides lossless alternative primitive holes in course schema version 2: hole identity, integer world-dm origin and exact local whole-yard RHI layout. Arbitrary legacy polygons remain schema-v1-readable and are never silently converted or erased. No rating/sim version or formula changes. Source layouts and live session definitions must agree before capture.

The world-dm/local-yard conversion retains a rational boundary: one yard is exactly 914.4 mm. Owned-land checks compare tenths of millimetres without rounding. Parcel data must be integer, bounded, complete and nonoverlapping. Circle bounding boxes conservatively reject encroachment into unowned parcels. World-origin placement is still development-specific; production hole orientation/routing/slope authoring remains unresolved. Global objects/paths are not inferred as rating features.

Primitive saves and optional runtime.practice require reader 3. Reader 3 still reads ordinary v1 saves and reader-2 zero-hole checkpoints. Slot storage retains full terrain/ledger generation pairing. Course rating is recomputed from exact layouts/seed on restore; no cached player score is trusted. `one_hole_save.example.json` is independently generated with the existing Python rating reference; its terrain digest is a zero placeholder because no terrain binary fixture is supplied.

The current view intentionally supports one fixed origin and a rectangle fairway/side-water/circle-green short-hole profile. Other valid primitive profiles are refused before UI setup, with existing files preserved. The general codec supports more geometry than this small view. Terrain brush ground is a separate development surface and is hidden during exact-hole viewing: arbitrary painted ground and raised heights are not falsely claimed as the playable/rated hole. Final authoring must unify those surfaces.

## Checks

- `python3 docs/spec/data/validate.py`: ALL PASS including reader-3 positive/negative cases.
- Existing Python rating reference for seed1234/shot1/skill500, aiming at [0,6000cy]: x=-897, y=5352, rough, no penalty. Geometry hash `1e6e5f2349ac540a`. Added literal golden assertions beside sim-path comparison.
- gdparse on changed scripts: PASS, syntax only, not Godot typing.
- Pending Godot regressions: lossless geometry/legacy protection, owned-land rejection, malformed version/slot/parcel input, ambiguous shapes, resumed next shot, individual putting/terminal state, no reload charge/reward, and actual scene finalize -> shoot -> save -> load.

New CylinderMesh/SphereMesh properties verified in official Godot documentation: [CylinderMesh](https://docs.godotengine.org/en/stable/classes/class_cylindermesh.html), [SphereMesh](https://docs.godotengine.org/en/stable/classes/class_spheremesh.html). BoxMesh/material/button/Node APIs use existing repository call sites. No unverified new API signature identified; engine execution remains pending.

## Remaining work and risks

This is not the full DEC-072 golfer: no avatar creation/movement, skill-specific attributes/XP, shot styles, final touch targeting, animation, played tournaments or private match stakes. See `simgolf_controls_research.md` for the requested control direction. Staff/VIP/animals/maintenance/skins remain required but unimplemented.

Rating a course during checkpoint validation currently repeats the official sim; this is acceptable only as an unmeasured one-hole proof. Add immutable geometry/seed-keyed caching or staged validation and profile before 18-hole saves. No low-end performance claim, cloud compatibility rollout or production slot migration is made.

Latest preceding integration CI at 2675841: Android/import/screenshots runs marked failure with their jobs cancelled before any steps; no job log exists. Determinism still queued at last check. Check annotations in GitHub to establish the runner-start cause; it is not known to be a GDScript failure. No merge or green-APK claim.

## For Nathan after a green APK

1. Run Sim hash, then Benchmark Quick 60s on the S22 Ultra.
2. Open Live construction -> Build / play one hole. Adjust width/side water, note the displayed price, finalize. Cash should fall once.
3. Aim/play a shot, Save & launcher, reopen the same scene and panel. Position/strokes/cash must match.
4. Redesign the hole: no second construction charge and previous practice progress must reset.
5. Report whether selecting targets feels useful. These development buttons are not final mobile controls.

Low-end phone purchase, Supabase setup and official trademark search remain Nathan's tasks.

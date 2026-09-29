# Mulligan Hills data specs (frozen at Gate 0 unless a DECISIONS.md entry says otherwise)

Owner: workstream H (spec). Format: JSON Schema draft 2020-12, one `*.schema.json` per file type, plus examples.

Check everything: `python3 docs/spec/data/validate.py` (needs the `jsonschema` package; it was importable when these files were written, version 4.26, and the run passed: all schemas valid, all 10 examples valid, 11 negative tests correctly rejected, plus semantic checks). Wire this into CI (workstream A) as a required check.

| File | What it defines |
| --- | --- |
| course.schema.json / course.example.json | Holes, tees, greens, hazards, objects, paths, terrain reference, parcels |
| save.schema.json / save.example.json | One save slot; rules in SAVE_MIGRATION.md |
| buildings.json (+ schema) | 10 buildings x 5 tiers with requirements. Costs are PARAMETERS, NOT FINAL |
| tournaments.json (+ schema) | Four ladder levels, spectator capacity, prestige parameters |
| commission_templates.* / event_cards.* | Content templates. Launch target about 30 commission templates and about 40 event cards |
| remote_config.* | Clamped server-tunable values, kill switches |
| analytics_catalog.json, analytics_event.* | Privacy-safe event catalogue and envelope |
| strings.* and LOCALIZATION.md | String table format, key rules, length limits |

## Global data rules
1. No floats in any data that touches the sim, ratings, saves or shared payloads. Integers only, each within +/-2^53 (Godot parses JSON numbers as float64, so larger ints lose bits). 64-bit values (RNG state) are 16-char lowercase hex strings. Loaders must convert with a check that the float is integral and in range, and reject otherwise.
2. Units: horizontal integer decimetres (dm, 100 mm) on a plan grid (x east, y south, origin top-left, 0..65535). Vertical integer millimetres (int16) inside the terrain blob. Distances shown to players are converted to yards at display time only. Money is whole dollars (integer). Scores are integers 0..100. Percentages are integer percent or permille.
3. Hard limits (reject on load, never clamp silently): 18 holes; 4 tees per hole; polygons 3..64 vertices; 48 hazards per hole; 8 fairway polygons per hole; 4000 objects; 64 paths of 2..64 points; 16 parcels; terrain grid 16..2048 cells per side.
4. Score is never stored in a course or a shared code. Ratings are recomputed from geometry by the rating engine (rating_engine_version is recorded so old data can be re-rated or rejected).
5. Every file has `schema` and `schema_version`. Unknown properties are rejected (`additionalProperties: false`) so typos and smuggled fields fail loudly.
6. Ordered collections stay arrays with defined order. Sim code never iterates a Dictionary; loaders convert objects to sorted arrays first.
7. Names are preset ids or string keys, never free text (v1). Fictional brands and people only.
8. Score scale: hole score 0..100 integer; course score is the integer average of hole scores; building gates use average hole score plus hole count. The legacy gates 150/300/500/750 at 6/10/14/18 holes convert to 25/30/36/42. These are placeholders until the rating spec fixes the real hole-score distribution.
9. Land unit: one parcel holds 3 holes (start 2 parcels, max 9, placeholder). Buildings also need parcels via `min_parcels_owned`.
10. Assumption to reconcile: terrain resolution and blob layout are owned by workstream C. This spec asks for int16 mm heights and integer cell sizes; if C documents a different unit, C's doc wins for the blob and H updates the `terrain` reference block.

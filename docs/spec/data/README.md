# Mulligan Hills data specs (frozen at Gate 0 unless a DECISIONS.md entry says otherwise)

Owner: workstream H (spec). Format: JSON Schema draft 2020-12, one `*.schema.json` per file type, plus examples.

Check everything: `python3 docs/spec/data/validate.py` (needs `jsonschema` 4.18+ and `referencing`; last run 5 Oct 2026 with jsonschema 4.26: ALL PASS). It validates every schema, every example and the full data files (buildings, tournaments, event cards, achievements, progression, daily challenges), runs negative tests (including the save fields added after the first v1 files and a legacy v1 save), semantic checks, and that each runtime copy in `game/data/` equals its spec file. Wire it into CI (workstream A) as a required check.

| File | What it defines |
| --- | --- |
| course.schema.json / course.example.json | Holes, tees, greens, hazards, objects, paths, terrain reference, parcels |
| save.schema.json / save.example.json | One save slot; rules in SAVE_MIGRATION.md |
| buildings.json (+ schema) | 10 buildings x 5 tiers with requirements, payback targets (DEC-050) and the land layout. Numbers are PARAMETERS, NOT FINAL |
| tournaments.json (+ schema) | Four ladder levels, spectator capacity, prestige parameters |
| commission_templates.* / event_cards.* | Content templates. Launch target about 30 commission templates and about 40 event cards |
| remote_config.* | Clamped server-tunable values, kill switches. No prices: building prices are payback targets in the economy data (DEC-050, PROP-03) |
| analytics_catalog.json, analytics_event.* | Privacy-safe event catalogue and envelope |
| strings.* and LOCALIZATION.md | String table format, key rules, length limits. Runtime table is `MHStrings.TABLE` (code) until `game/data/strings/en.json` exists |
| achievements, progression, daily_challenges (+ schemas) | Achievement catalogue, club levels and streak numbers, daily challenge templates |
| staff.json (+ schema) | 11 staff roles over the 10 buildings, 3 grades, wages in cents, grounds condition and pest parameters, incident kinds. Numbers are PARAMETERS, NOT FINAL. Spec: docs/spec/staff.md. The save gains an optional club.staff_roster block (save_version unchanged) |

## Global data rules
1. No floats in any data that touches the sim, ratings, saves or shared payloads. Integers only, each within +/-2^53 (Godot parses JSON numbers as float64, so larger ints lose bits). 64-bit values (RNG state) are 16-char lowercase hex strings. Loaders must convert with a check that the float is integral and in range, and reject otherwise.
2. Units: horizontal integer decimetres (dm, 100 mm) on a plan grid (x east, y south, origin top-left, 0..65535). Vertical integer millimetres (int16) inside the terrain blob. Distances shown to players are converted to yards at display time only. Money is whole dollars (integer). Scores are integers 0..100. Percentages are integer percent or permille.
3. Hard limits (reject on load, never clamp silently): 18 holes; 4 tees per hole; polygons 3..64 vertices; 48 hazards per hole; 8 fairway polygons per hole; 4000 objects; 64 paths of 2..64 points; 16 parcels; terrain grid 16..2048 cells per side.
4. Score is never stored in a course or a shared code. Ratings are recomputed from geometry by the rating engine (rating_engine_version is recorded so old data can be re-rated or rejected).
5. Every file has `schema` and `schema_version`. Unknown properties are rejected (`additionalProperties: false`) so typos and smuggled fields fail loudly.
6. Ordered collections stay arrays with defined order. Sim code never iterates a Dictionary; loaders convert objects to sorted arrays first.
7. Names are preset ids or string keys, never free text (v1). Fictional brands and people only.
8. Score scale: hole score 0..100 integer; course score is the integer average of hole scores; building gates use average hole score plus hole count. Gates (DEC-048): average hole score 32 / 42 / 52 / 62 and 6 / 10 / 14 / 18 holes for tiers 2 to 5. A hole with a score under 25 is dead (DEC-063): it stays in the average but does not count toward the hole gate. The gate numbers are still placeholders until the economy simulation and the measured score distribution confirm them.
9. Land unit (DEC-056): 16 parcels on a 4x4 grid (12 golf, 2 facility, 2 homes). Two golf parcels hold 3 holes, so all 12 golf parcels hold the 18-hole cap; start plot is 5 parcels (6 holes), buy only next to owned land. Heavy buildings (Driving range, Pool and spa, Lodging, Homes, Landmark) need one extra parcel at tiers 2 to 5. Gate `min_parcels_owned` and the layout live in `buildings.json` (`land`); sizes in metres are not fixed until the low-end phone shows map size against frame rate.
10. Terrain reconciled 29 Sep 2026 with workstream C's implementation: int16 mm heights, (cells+1) x (cells+1) samples, 1 m default cell (`cell_size_dm` 10 = `cell_size_mm` 1000 / 100), blob file `MHTS` v1 (`.mhts`), chunk size 32, FNV-1a 32-bit height hash as `content_hash`. See `docs/spec/interfaces/terrain.md`. Still open: the 11 named `surface_layers` in the course schema versus the 4 implemented splat layers, and sha256 versus FNV-1a for `content_hash`.

# Mulligan Hills data specifications

The data layer uses JSON Schema (draft 2020-12) plus semantic validation to keep tunable content and persisted structures explicit.

## Validation

From the repository root:

    python3 docs/spec/data/validate.py

The validator checks schemas, examples, full data files, semantic constraints and selected runtime/spec copy consistency.

## Key files

| Area | Files |
| --- | --- |
| Course | course.schema.json, course.example.json |
| Save | save.schema.json, save.example.json, SAVE_MIGRATION.md |
| Buildings | buildings.json, buildings.schema.json |
| Tournaments | tournaments.json, tournaments.schema.json |
| Staff | staff.json, staff.schema.json |
| Progression | progression.json, progression.schema.json |
| Events | event_cards.json, event_cards.schema.json |
| Achievements | achievements.json, achievements.schema.json |
| Analytics | analytics_catalog.json and analytics schemas |
| Remote config | remote_config.example.json, remote_config.schema.json |

## Rules

- Tunable numbers are data when practical.
- "Parameter" does not mean "final balance".
- Runtime copies under game/data must not silently diverge from their specification sources.
- Schema shape and runtime restore validation must agree.
- Persistent changes require migration/reader-capability review.
- Examples must remain valid regression fixtures, not aspirational pseudo-data.
- A schema pass alone does not prove gameplay balance or runtime integration.

See SAVE_MIGRATION.md for persistence compatibility rules.

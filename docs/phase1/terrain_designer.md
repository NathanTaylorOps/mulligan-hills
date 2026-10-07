# Canonical terrain and hole authoring

Current implementation contract, 7 October 2026. Design sources: DEC-084, DEC-088 through DEC-094. See [editor experience](editor_experience.md) for visual direction and [live construction](live_construction.md) for integration/save limits.

## Data already in use

`MHCraftHole` is the canonical semantic authoring grid placed over shared course terrain, not a separate terrain world. Default development size is 24 by 40 tiles, each 2 yards square. Coordinates remain hole-local; conversion to the world uses the existing rational yard/dm/mm boundary.

| Data | Contract |
| --- | --- |
| Surfaces | Rough, fairway, first cut, deep rough, green, fringe, tee, bunker, waste, water, OB, path, dirt |
| Elevation | Authoritative integer `height_mm`, clamped from -4,000 to 16,000 mm; `height_m` is a rounded compatibility cache |
| Markers | One tee and up to four distinct pin tile positions |
| Trees | Real hole-local yard coordinates |
| Rocks / flowers | Counts only; do not invent authoritative placement coordinates |
| History | Up to 100 committed strokes with tile deltas and marker before/after snapshots; cancel restores both; empty edits do not consume history |
| Persistence | Existing versioned craft dictionary, including exact heights and marker coordinates; history and placement previews are transient |

## Current tools

- **Surfaces:** illustrated material tray grouped into Turf, Hazards, and Paths & dirt. Detail/Small/Wide use radii 0/1/3 tiles, or 2/6/14-yard bounding diameters. The footprint uses the same integer disc mask as the edit.
- **Terrain:** Raise and Lower use 250/500/1,000 mm steps. Smooth averages exact millimetre neighbors before writing a dab. Level holds the exact starting height throughout a stroke. Imported fractional heights must not be rounded away.
- **Hole:** Place tee / Place pin stages an on-course preview. Confirm applies one undoable edit; Cancel and focus/tool changes discard it. Cycle pin slots to move an existing pin or add the next available one, with at most four. Duplicate placement cannot clear the other pins. Removal and marker repair are undoable.
- **Readiness:** current yardage, geometry requirements and owned-land placement are checked before Build. A blocked build expands its explanation. Pending marker placement must be confirmed or cancelled first.

Normal course viewing and surface painting have no permanent grid. Raise/Lower/Smooth/Level show temporary sculpt feedback only (DEC-093). Terrain rendering remains batched by surface; the footprint and marker candidate each use a single extra mesh.

## Deterministic conversion and gameplay relief

`MHCraftConvert` emits the existing rating input. Fairway/first cut become fairway rectangles; deep rough, water and OB retain their feature types; bunker/waste use sand. Greedy rectangle coverage has deterministic scan order. Rough, fringe, tee, path and dirt do not invent extra rating feature types.

The rating green is a circle centered at the chosen pin, with equivalent-area radius derived from painted green tile count times **4 square yards per tile**, using the existing integer square-root calculation. Accepted radius is 5–30 yards. Tee-to-pin length is 60–1,000 yards. All pins must lie on green, the tee must avoid water/OB, and tree/feature/bounds limits remain authoritative.

The relief grid carries exact tile-center millimetres. `MHRHole.z_at` interpolates it for rating, shots and roll; display and picking use the same relief. The previous assertion that elevation only affects endpoint heights is obsolete (DEC-091).

`MHCraftTerrainBridge` synchronizes the semantic footprint with the shared world. Do not change units, introduce float simulation, or add a parallel hole representation for visual convenience.

## Built versus still outstanding

The model, converter, terrain bridge, draft checkpoint, editor, finalization and practice path exist. New dock/precision/marker behavior is syntax-checked and awaits Godot/device validation; the historical baseline passed separately.

Still outstanding: polished authored terrain art, shaped bunker/water transitions, a supported editor roundtrip for finalized holes, course routing beyond the one-hole development origin, finalized multi-round pin scheduling, placed landscaping coordinates/migration, and touch occlusion tuning. Existing tree coordinates can support real placement later; rock/flower counts need an explicit canonical migration first.

Do not assume per-stroke prices, automatic pin rotation in current practice, final shot-style overlays or landscaping placement are implemented just because older proposal notes described them. Future costs belong in the existing session/economy command path when designed.

## Regression priorities

Preserve exact elevation through paint/sculpt/undo/redo/conversion/save; preserve markers through confirm/cancel/history/draft disk reload; reject duplicate/fifth pins without data loss; keep the brush mesh and canonical footprint aligned. Retain green repair bounds, early owned-land warnings and EDIT → BUILD → PLAY → SAVE → RELOAD.

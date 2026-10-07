# Terrain designer ("craft") spec

Status: 6 October 2026. Core model/converter, live craft controls, shared-world bridge and exact-draft persistence are implemented on the current integration branch. Godot/device verification is still required before merge. Sources: DEC-084 (craft), DEC-085 (isometric camera), DEC-086 (SimGolf quality bar), DEC-088 to DEC-090 (v1 scope), `simgolf_reference.md`.

## What the player does
Paint a hole tile by tile, sculpt its height, place one tee, one to four pins and scenery, see the shot line and numbers, and get the rating. Square tiles, drawn with smoothed edges (logic stays on the grid).

## Data (built: `game/craft/mh_craft_hole.gd`)
- Hole-local grid of tiles, 2 yards a side (`TILE_YD`). x across with 0 on the centre line, y from the tee end toward the green. Default 24 by 40 tiles (48 by 80 yd) for the slice; real holes use more rows.
- 13 surfaces: rough, fairway, first cut, deep rough, green, fringe, tee, bunker, waste, water, out of bounds, path, dirt. (These are the player's tools. The existing 11-layer paint map in `game/terrain/` stays the renderer's blend source.)
- Height per tile in whole metres, -4 to +16 (`HEIGHT_MIN_M`, `HEIGHT_MAX_M`).
- One tee box (DEC-090). Up to four pin positions; the hole plays pin `round mod count` each round (DEC-088). Trees as yard points; rock and flower counts.
- Undo and redo: one finger stroke is one step, 100 deep, empty strokes dropped, cancel rolls back (built). The undo button must stay usable while the game is paused.

## Converter (built: `game/craft/mh_craft_convert.gd`)
Painting to rating input (RHI v1, whole yards, hole-local frame), deterministic and integer only:
- fairway and first cut become fairway rectangles; deep rough, water and out of bounds map to their own types; bunker and waste both count as sand; green, fringe, tee, path, dirt and rough add no area feature.
- Rectangles come from a greedy scan (row 0 upward, left to right, longest run, grown over rows with the same columns), so the same painting always gives the same list.
- Green is a circle at the round's pin with radius floor(sqrt(green tiles x 16 x 7 / 22)) yards, at least 1. Tee point and heights (`tee_z_mm`, `green_z_mm`) come from the tee and pin tiles.
- Blocking problems, in plain words for the UI: no tee, no green, no pin, pin not on the green, tee in water or out of bounds, too many trees (over 1,500), too complex (over 3,000 features), too large (beyond 1,200 yd).
- Limit to check: the rating engine reads only area rectangles, so slopes affect nothing but the two heights. Elevation as a rating factor is the engine owner's call (open question 2).

## Tools and screens (to build)
1. **Bottom bar, edit mode** (SimGolf pattern): palette pods in two rows with labels, price on hover or long press; height pods (raise, lower, flatten, smooth) with brush size; Undo and Redo buttons; Test shot; Rate.
2. **Edit grid** shown in edit mode only; hole label and tee-to-green line as in the slice.
3. **Shot analysis**: from the tee, three arcs (low, normal, high) with landing zone, carry and roll, wind arrow, plus the text readout the slice already has. Uses the rating engine's planner, so the numbers match the score.
4. **Smooth edges**: draw each surface with marching squares on the tile grid so tiles look rounded while rules stay square. Water, sand and fairway edges get a shore or lip.
5. **Pins**: tap a green tile to add a pin (up to four); pins show numbered flags and the current round's pin is highlighted.
6. **Tree and plant brush** uses the content catalogue (15 tree styles x 3 heights, 10 plants x 15 colours). Placement snaps to a half tile.
7. **Costs**: every tool has a price, paid through the session like building. Undo refunds the stroke.

## Build order
1. Craft model and converter (done). 2. Wire a `MHCraftHole` into the session as a hole definition (replaces the fixed slice designs). 3. Tile renderer with edit grid and height. 4. Bottom bar tools and undo. 5. Shot overlay. 6. Smooth edges. 7. Content catalogue brushes. 8. Save format (`course.schema.json` terrain block) and migration.

## Open questions for the lead
1. Tile size: 2 yd is good for a phone finger on an 18-hole course; 1 yd is finer but four times the tiles. Keep 2?
2. Elevation is resolved by DEC-091: rating and ball roll read relief.
3. Shared-map architecture is resolved by DEC-092: the persisted world terrain is shared; each hole carries a semantic/rating craft grid over its footprint rather than owning a separate terrain world.

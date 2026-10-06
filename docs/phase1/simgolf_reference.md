# SimGolf reference study (from Nathan's clips, 5 Oct 2026)

Source: three short clips supplied by Nathan (two of Sid Meier's SimGolf, one of Under Par Golf Architect, a current mobile rival). This records design PATTERNS only. No SimGolf assets, text or code are used or to be used (DEC-086 note: match the look, never the files).

## What SimGolf does (clips 1 and 2)
- **Camera:** fixed isometric view, the map is a diamond slab floating in black with a soil edge. Hole labels ("Hole 3, 381 yards, Par 4") float over the tee with a thin white line to the green.
- **Terrain is painted in tiles.** Palette of pods in two rows, each with a small label: tees, green, sand trap, rough, pot bunker, streams, fairway, firm fairway, deep rough, waste bunker, brush. Fairway tiles show mown stripes. Tile edges are cut cleanly, not blended.
- **Edit mode shows a blue grid** over the ground. Height tools are three big glowing round pods with arrows.
- **Costs are visible at the point of action:** a hover tooltip gives name, price and a one line description; the price floats in red when spent.
- **HUD:** one wide bevelled lavender-grey bar at the bottom. Round tab buttons on its left switch modes. The bar changes content (palette, height tools, shot analysis, scorecard) rather than opening windows.
- **Shot analysis panel:** three arc-type buttons (low, normal, high), a text block (attitude, club, distance, lie) and a list of the golfer's trait modifiers (for example power hitter +20 percent). The shot path is drawn as a white line over the course.
- **Golfers:** tiny figures with a name label, walking in groups, chatter shown as coloured speech text. Faces never show in play. A round ball-framed cartoon portrait appears only in event messages ("applies for membership") and the overview.
- **Exhibition scorecard** sits in the bar: stake per hole, players, hole columns.
- **Scenery:** dense clusters of conifers on brown dirt, cherry blossom, rocks and standing stones, ornate clubhouse with striped awnings, grey cobble walkways, arched stone bridges, statues, ducks and geese, pots of flowers.

## What Under Par does (clip 3)
- Brighter, softer, rounder top-down look; lollipop trees; thin icon toolbar across the top; ghost building with a price tag while placing and a yellow grid; red angry-face bubbles over unhappy golfers and short speech bubbles; bottom card with building stats. Its polish is below SimGolf's scenery density, which supports DEC-086.

## What we take from this
1. **One bottom bar that changes mode** instead of stacked windows. Fits landscape phones.
2. **Price and one-line help at the point of touch** (tap and hold on mobile).
3. **Mood bubbles over golfers** (from Under Par): tiny, readable, no faces needed.
4. **Painted tiles with striped fairway texture**, clean tile edges, a grid in edit mode.
5. **Dense scenery clusters** (tree groups on dirt, rocks, flower pots) matter more to the SimGolf feel than model detail.
6. **Hole label and shot line overlay** to show a hole's length, par and path.
7. **Shot analysis as three arc buttons plus a text readout.**

## Not taken
Any SimGolf art, icon, font, sound, text strings or layout copied pixel for pixel.

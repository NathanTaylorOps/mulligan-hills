# Mulligan Hills — editor experience direction
Status: direction plus implementation progress, grounded in reference review; not a claim of validated usability.
Date: 2026-10-07 UTC.
Confirmed priorities: mobile first, desktop also a first-class game version. Shared canonical world and game systems.
Baseline: 940f3da navigation probe passed on user Windows Godot 4.7.2. Brush changes 4673daa and the later dock/precision/marker batch await runtime validation.

## Implemented editor batch (pending engine/device acceptance)

- `2af3b50`: precise millimetre sculpt operations, smoothing and unified terrain/marker history.
- `a7331b8`: focused bottom dock and compact HUD; grouped horizontal material tray; Detail/Small/Wide brush cycling; fine/medium/coarse sculpt steps; exact Level sampling; tee/pin preview/confirm/cancel; recoverable draft pin slots; desktop shortcuts and gesture cancellation.
- The live probe now covers the dock, precision, marker history and draft disk saves as well as owned-land repair/build/practice and complete checkpoint reload.
- The new dock is implemented. The 65% unobstructed-world target, left-handed ergonomics, text scaling, authored artwork and device comfort still need evaluation. The current palette thumbnails are temporary.
- Current finalization/practice uses pin 1. Extra pins persist in the unfinished draft; finalized multi-round schedules and editing a built hole remain outstanding.


## Reference findings and evidence limits
Reviewed publicly available SimGolf screenshots, Under Par developer screenshots/devlog, developer commentary and independent reviews. No hands-on competitor testing in this session. Demo-era comments are historical anecdotes, not proof of current defects or population-level satisfaction.
- SimGolf: small illustrated terrain palettes, readable surface contrast, a course-dominant isometric scene and useful on-course hole/shot information. Preserve the interaction principles, never copy art or assets.
- Under Par: contemporary stylized terrain, course shaping and on-course shot analysis. Its June 2025 developer material shows tee/fairway/hazard/green relationships and waypoint shaping.
- Independent April 2026 PS5 review reports menu/control friction and television readability concerns. This reinforces input-specific layouts; it does not establish mobile performance or usability.
- November 2025 demo feedback asks for understandable icon labels, easier selection through objects and recoverable panels. Treat these as questions to test, not current product findings.
- Android's official guidance recommends at least 48dp touch targets. Existing MHUIContext/MHTheme sizing remains the source of truth; do not replace it with hard-coded pixel sizing.

Sources:
https://www.retrogaminggeek.com/wp-content/uploads/2024/06/sid-meiers-simgolf-building-course.jpg
https://brokenarmsgames.itch.io/under-par-golf-architect/devlog/982173/-june-dev-blog-the-anatomy-of-a-golf-hole
https://store.steampowered.com/app/2928410/Under_Par_Golf_Architect__Sim_Manager/
https://www.playstationlifestyle.net/review/930742-under-par-golf-architect-review-ps5
https://news.xbox.com/en-us/2026/04/16/building-the-greens-of-our-dreams/
https://steamcommunity.com/app/2928410/discussions/0/684113073641922522/
https://developer.android.com/guide/topics/ui/accessibility/views/apps-views

## Product goal
Make creating a course feel like shaping a miniature living landscape. Players should predict an action, see its exact effect, undo it easily and understand how golfers experience the result.
Market leadership is an aspiration to validate with real playtesting, not a conclusion supported by screenshots.

## Visual language
- Warm cream panels, forest-green ink, clear turf/sand/water colours, restrained gold selection accents and coral problem indicators.
- Rounded, consistent controls with original illustrated categories and material previews matching the course's actual art.
- Labels accompany icons; selected state also uses shape/border/check feedback, not colour alone.
- One typography hierarchy and icon family. Avoid competing styles, gratuitous wood textures, giant text palettes and opaque engineering codes.
- Micro-animation, optional haptics and modest tool audio communicate selection, completion and recovery. Respect reduced-motion and sound settings.
- Authored terrain/material art is necessary: UI polish cannot disguise unattractive course geometry, seams or muddy surface distinctions.

## Mobile-first layout target
- Landscape phone is the primary design/test surface, including safe insets on the Samsung S22.
- Compact top status band. Do not leave prototype Save / Save & launcher / Build-play actions as permanent competing controls in final game UI.
- Bottom reachable category dock: Surfaces, Terrain, Hole. Show only the active palette and relevant brush settings.
- Keep common materials immediately available; separate optional material choices into a clearly discoverable second palette.
- A compact selected-hole summary shows hole number, live yardage, readiness and Build. Expand it intentionally for details.
- Only one large editing panel at a time. Undo/Redo and a predictable Back/Close path remain reachable.
- Target at least 65% unobstructed course area in typical editing states. Measure this after safe areas and controls; this is a proposed target, not current measured performance.
- Collapse tools without leaving invisible input-blocking regions. Allow left-handed placement through existing settings.
- Avoid putting the entire workflow in a narrow scrollable inspector. The previous side panel has been replaced by the bottom dock; measure the new layout on device.

## Desktop adaptation
Use the same categories, canonical commands, state and save format.
- More spacious material palette and an optional inspector on wide displays.
- Accurate mouse-hover footprint, tooltips with names and effects, familiar Undo/Redo shortcuts and camera controls.
- Keep visible alternatives for essential actions; shortcuts are accelerators.
- Window resizing, text scale and high-DPI support; never determine input exclusively from viewport aspect ratio.
- Keep platform prompts appropriate: mouse/keyboard hints on desktop, gesture hints on phones.

## Interaction contract
- Every gesture has one owner. UI taps never paint; two-finger camera gestures cancel unfinished paint safely.
- Brush feedback matches the authoritative disc and relief. Surface mode does not acquire a permanent grid; grid remains sculpt-only.
- Detail/Small/Wide are understandable defaults. Preserve selection across categories.
- Sculpt strength now offers 0.25/0.50/1.00 m increments through canonical millimetres. Do not round imported terrain as a side effect; evaluate step comfort on device.
- Level visibly explains the sampled starting height and retains it throughout the stroke.
- Touch placement needs a visible target and reliable positioning; evaluate an offset reticle/fine adjustment for finger occlusion.
- Freeform painting commits per stroke with undo. Discrete marker placement should support preview/confirm/cancel and undo through the canonical model.
- Switching tools, closing a panel, pausing or losing focus cannot commit an unfinished gesture.
- Do not silently clear four existing pins to place another. Show four slots, select/move one or explain the limit.
- Invalid design feedback identifies the location and offers an applicable next action: move flag, enlarge green, move feature onto owned land.
- A build-readiness card gives the most important problem first, with additional details on demand.
- On-course ownership feedback appears when relevant, before Build, without weakening authoritative ownership checks.
- Optional shot/landing/slope overlays answer a specific question and disappear when disabled.
- Success feedback celebrates building the actual hole, then offers practice on that same terrain.
- Character reactions should eventually connect visible choices to understandable consequences, based on real simulation evidence.

## Implementation order and boundaries
1. Validate the accumulated editor batch, including landscape layout, precision, marker workflow and disk reload.
2. Consolidate the editor's presentation into the mobile dock and compact hole summary. Reuse existing canonical operations; do not introduce a second editor model.
3. Improve sculpt precision and Level feedback; preserve exact height and stroke history.
4. Improve surface palette hierarchy, previews and material consistency.
5. Implement clear marker/pin-slot workflow and on-course design/ownership warnings.
6. Apply coherent terrain art, edge shaping and smooth relief presentation.
Desktop layout and input coverage accompany each step; management/carts remain outside this phase.

## Usability acceptance targets
These are targets for formative tests, not proven outcomes:
- A first-time player builds and practices a starter hole within five minutes, without verbal instruction.
- At least four of five formative participants find a requested common tool and recover an accidental stroke unaided. Five people reveal usability problems; this is not a statistically reliable market estimate.
- Typical material/tool switching takes at most two selections, without leaving the course.
- No unintended edit from opening a menu, moving the camera, touching UI or closing an unfinished stroke.
- Players can explain why Build is unavailable and locate the offending feature.
- Brush preview and committed footprint agree at edges and on slopes.
- Readability survives phone safe areas, chosen text scaling, desktop resizing and colour-vision alternatives.
- Validate input latency and sustained performance on device before setting a shipping threshold.

## Regression gates
Every major editor change retains EDIT -> BUILD -> PLAY -> SAVE -> RELOAD.
Cover actual landscape dimensions as well as desktop/square windows, selected-tool persistence, palette containment, touch/mouse input ownership, gesture cancellation, undo/redo, brush masks, invalid marker/green repair, land ownership, exact canonical relief, practice state and real disk reload.
Do not call graphical quality, touch usability or market-leading satisfaction verified based on a headless PASS.

## User-supplied visual references, 2026-10-07
Five screenshots were inspected directly: three SimGolf views (terrain palette, tournament notice, building palette) and two Under Par views (hole handles and terrain palette). These sharpen the proposed direction; they are reference material, not production assets.

| Visible feature | Interpretation for Mulligan Hills |
| --- | --- |
| SimGolf terrain and building palettes show actual miniature items | Use original material swatches and object previews that resemble the result in the world. Keep consistent camera angle, framing and selected-state treatment. |
| SimGolf category controls cluster in a lower corner and open a bottom palette | Keep category access near the thumb and contextual choices along the lower edge. Use simple geometry and explicit labels; the ornamental circular fan is not a layout requirement. |
| SimGolf course view distinguishes striped fairway, green, rough, sand, paths and water | Establish a readable surface hierarchy at ordinary playing zoom, supported by edging, texture and shape as well as colour. |
| SimGolf mixes tree silhouettes, flowers, bridges, buildings and small golfer reactions | Aim for a varied, inhabited landscape. Preserve this goal for the art/social phases without bringing their implementation ahead of editor work. |
| Large SimGolf tournament/celebrity notices cover the upper course | Later events should normally use a compact portrait ribbon with optional expansion, preserving camera and course visibility. |
| Under Par places interactive handles along the selected hole | Offer direct manipulation of the current tee/pin/selected design element. Make the active handle obvious, touchable and cancellable. Do not add unsupported waypoint geometry to the canonical model just to imitate the reference. |
| Under Par's lower palette groups related tools into a shallow strip | Prefer a shallow contextual tray over a tall, permanently open inspector. Phone width determines how many cards fit; do not shrink touch targets to expose the whole catalogue. |
| Under Par screenshots show terrain grids and small status/goal panels | Retain DEC-093 sculpt-only grids. On phones, collapse secondary goals/status information while editing; never require reading a desktop-density panel. |

### Concrete editor states for the next layout pass
- Browse: compact status, category entry and course view; no material catalogue covering the scene.
- Surfaces: illustrated category selection, a shallow material tray, the chosen brush size and visible undo. Material name accompanies its preview. Less-used surfaces remain discoverable through a clearly labelled additional palette.
- Terrain: four visual tools (Raise, Lower, Smooth, Level), compact brush controls and a temporary grid. The brush footprint stays legible over every surface.
- Hole: a compact number/yardage/readiness card, tee and pin controls, on-course placement feedback and a prominent Build action. Expand validation details only when needed.
- At the top level, Close returns to the course; within an expanded picker, Back returns to the prior tool context. Preserve current tool and brush selection when reopening.
- On desktop, expose more palette choices and optional details when space allows while preserving the same state transitions and action meanings.

### Art priorities revealed by these references
1. Clear fairway mowing character, putting-green texture and readable fringe/rough boundaries.
2. Shaped bunker edges and sand depth; deliberate water banks and crossings.
3. Varied vegetation silhouettes and believable scale relative to golfers, paths and buildings.
4. Ground/contact shadows and restrained surface highlights that preserve clarity on a phone.
5. Quiet UI surfaces with original illustrated assets, allowing the landscape to supply most of the visual richness.

Do not reproduce the references' exact colours, ornaments or screenshots as in-game assets. Evaluate palette density and event size in the actual mobile layout rather than inheriting them from these desktop screenshots.


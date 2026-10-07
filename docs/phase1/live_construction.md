# Live course construction and checkpoints

Current architecture note, 7 October 2026. Supersedes the earlier zero-hole integration and side-column layout descriptions in this file's history.

## Entry point and scope

**Course design & practice** in the launcher opens `res://gameplay/mh_live_construction.tscn` (`MHLiveConstruction`). This is the canonical saved-course path. `MHVerticalSlice` is a historical presentation demo with sample layouts; do not extend it as a second authoring/gameplay architecture.

The live scene coordinates the existing `MHGameSession`, `MHLiveGameStateView`, shared world editor/chunks, camera, UI shell, input router and `MHOneHolePanel`. It supports normal ground editing, an unfinished authored hole, authoritative finalization, exact-hole practice and save/restore. The development patch remains 128 by 128 cells, with one authored hole at the current fixed origin.

## Authoritative data flow

`MHCraftHole → MHCraftConvert → canonical hole + relief → MHOneHolePanel → MHRatingEngine → MHPracticeRound → MHSessionSave`

`MHCraftTerrainBridge` synchronizes edits between the shared persisted world and the hole's 2-yard semantic grid. The exact draft preserves information that the world splat layers cannot encode losslessly. Rendering and screen picking sample the canonical relief used by gameplay. World terrain outside the current hole remains visible during design/practice.

Build checks craft constraints, the rating input and `MHCourseLayout.encode` ownership/geometry rules before submission. Readiness calls the same placement boundary before presenting the hole as ready. Repair restores displaced marker surfaces and expands genuinely undersized greens only; it must not enlarge an already valid green or bypass ownership.

## Editor and input

The focused editor/practice view uses a full-width bottom dock inside the HUD safe area. The HUD keeps compact cash/time/score chips and hides its competing speed/navigation controls until the panel closes. Routine save text is hidden in this mode; save failures remain visible. Outside it, the normal HUD actions remain available.

The dock keeps summary, Build/Review, Details, Collapse/Close and category/history controls reachable. Its active material/tool tray scrolls horizontally. Surfaces are grouped into Turf, Hazards, and Paths & dirt; terrain tools expose appropriate brush/step controls. Detailed validation expands on request or a blocked Build.

`MHPracticeAimInput` owns exact-hole gestures. UI taps cannot paint, including panel padding and clipped palette items. Two-finger camera gestures, tool changes, close and focus loss cancel unfinished edits. Markers stage a visible candidate and require Confirm; committed marker edits and terrain strokes share canonical history. Desktop supports hover footprints, mouse camera controls and undo/redo shortcuts.

These interactions are implemented, but the new dock's visual balance, safe-area behavior, text scaling and touch comfort still require engine/device testing. The layout's world-space floor is a fallback bound, not achievement of the proposed 65% unobstructed-course target.

## Save boundary

The live store remains isolated under `user://phase1_live/saves`, with content-addressed ledger generations under `user://phase1_live/ledgers`. Ordinary slots are not repurposed. `MHSessionSave` validates a new restored session rather than partially mutating the running session on malformed input.

Checkpoints retain exact clock/economy state, save seed, rating inputs/results, ledger generation identity and full terrain-byte digest. Finalized primitive layouts/practice use reader 3; the optional exact unfinalized `runtime.craft_draft` requires reader 4. The marker/precision editor increment does not introduce a new save schema.

Save requests coalesce. Open strokes are not serialized; confirmed marker-only changes explicitly request a save even without terrain changes. Preview candidates and undo stacks are not serialized. Ledger generation is written before the world checkpoint so the older JSON/blob/ledger pair remains recoverable after a later write failure. Damaged or unsupported saves must not silently become new defaults.

## Current limits

- One authored hole, fixed development origin, and no supported inverse canonical-layout-to-craft editor roundtrip for finalized holes. Opening an existing built hole preserves it and enters practice; it does not invent replacement terrain.
- Up to four pins are editable and persisted in an unfinished draft. Conversion accepts a round index, but current finalization/practice uses pin 1. Finalized multi-round pin scheduling is still outstanding.
- Exact primitive rectangles/relief/positioned trees are supported by this scene's profile. Legacy polygon layouts and arbitrary unsupported profiles are not guessed into it.
- No complete NPC golfer loop, final terrain art, player-placed building footprints or landscaping-coordinate migration is claimed.
- Ledger garbage collection, production identity/slot rollout, cloud reconciliation and power-loss/device durability need later work.

## Evidence

Historical Windows Godot 4.7.2 evidence includes a passing live probe at `940f3da`; the preceding stable baseline also passed graphical testing. Later editor coverage must be evaluated against current-head evidence. Current Godot execution and graphical/device acceptance are pending.

Use [the development guide](../DEVELOPMENT.md) for one combined testing batch. Relevant regressions include `manual_verify_live_ui.gd`, craft/terrain bridge, one-hole/practice, session save and UI/input tests. Historical verification reports describe their dated commits, not current HEAD.

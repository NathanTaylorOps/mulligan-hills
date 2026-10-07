# MULLIGAN HILLS

Build a beautiful golf course, play the holes you create, and grow a club with character. Mulligan Hills is a stylized 3D golf-course management game built in **Godot 4.7.2 / GDScript**, with **mobile as the primary platform and a desktop version planned alongside it**.

Development currently concentrates on making course building enjoyable: editor navigation, terrain sculpting, surface painting, hole design, then terrain art. The wider management, golfer and social systems remain part of the game vision; this repository is an active development build, not a finished release.

## Run the current game

Open `game/project.godot` in Godot 4.7.2, or use PowerShell:

```powershell
cd "$HOME\Documents\GitHub\mulligan-hills"
godot --path ".\game"
```

Choose **Course design & practice** in the launcher, then **Build / play one hole**. This is the player-authored, saved-course path. **Presentation demo (sample course)** is a separate historical showcase with fixed layouts; it is not the foundation for new gameplay.

The project uses the Compatibility renderer and landscape orientation. Engine, gdUnit4 and export tool versions are pinned in [tools/ci/versions.env](tools/ci/versions.env).

## Current editor

- A bottom tool dock with **Surfaces / Terrain / Hole**, persistent Undo/Redo, compact yardage and Build/Review controls.
- Illustrated surface cards grouped into **Turf**, **Hazards**, and **Paths & dirt**. The current generated thumbnails remain temporary art.
- Raise, Lower, Smooth and Level; Detail/Small/Wide brushes; 0.25/0.50/1.00 m raise/lower steps; a footprint that follows canonical relief. The grid appears only while sculpting.
- Tee/pin preview, Confirm/Cancel, up to four editable draft pin positions, marker repair and shared undo history. Current finalized practice uses pin 1.
- Build readiness includes playable geometry and owned-land checks. Practice uses the exact finalized hole and relief.
- Shared terrain, unfinished draft and finalized practice checkpoints use the existing save system.

**Verification:** Nathan reported `LIVE_UI_PROBE PASS` on Windows Godot `4.7.2.stable.official.ed1daf0bf` at `940f3da`; the preceding stable checkpoint also passed graphical testing. Later brush/dock/precision/marker changes have syntax checks and expanded regression coverage, but **Godot runtime, graphical and device acceptance for this batch are pending**. A historical PASS is not a PASS for current HEAD.

Known limits include one authored hole at a fixed development origin, no supported editor roundtrip for an already finalized hole, temporary art, and unmeasured Android performance. Extra draft pins are not yet a persisted multi-round pin schedule for finalized courses.

## One course, one authoritative chain

`MHCraftHole → MHCraftConvert → canonical definition + relief → MHOneHolePanel → MHRatingEngine → practice → save/restore`

`MHCraftTerrainBridge` connects the semantic hole grid to the shared persisted terrain. Rendering, rating and shots must agree about elevation. Keep ownership validation authoritative; do not add a parallel hole model or turn the presentation demo into a second gameplay architecture.

## Repository guide

| Location | Purpose |
| --- | --- |
| [game/craft](game/craft) | Canonical authoring grid, conversion and shared-terrain bridge |
| [game/gameplay](game/gameplay) | Live course scene, editor/practice panel and historical presentation scenes |
| [game/core](game/core) | Rating, simulation, session coordination and persistence |
| [game/terrain](game/terrain) | Shared terrain editing, rendering and terrain checkpoints |
| [game/ui](game/ui), [game/input](game/input) | UI shell, responsive layout, touch and desktop input |
| [game/tests](game/tests) | gdUnit4 regressions and dependency-free live probe |
| [tools/ci](tools/ci), [.github/workflows](.github/workflows) | Engine setup, validation, exports and CI |
| [tools/reference](tools/reference) | Deterministic reference implementations and checks |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Recorded design and architecture decisions |
| [docs/phase1](docs/phase1) | Implementation notes, research and historical evidence |
| [android](android), [ios](ios), [supabase](supabase) | Platform and service work; not required to launch local course editing |

## Development and testing

Continue on **`fix/canonical-relief-save`**. Inspect its current HEAD before editing, keep commits focused, and preserve shared history. Do not push work blindly to `main` or rewrite published commits as housekeeping.

See [Development guide](docs/DEVELOPMENT.md) for the copy/paste regression batch and repository hygiene, [current live-course architecture](docs/phase1/live_construction.md), [terrain contracts](docs/phase1/terrain_designer.md), and [editor experience direction](docs/phase1/editor_experience.md).

Every substantial editor change must preserve **EDIT → BUILD → PLAY → SAVE → RELOAD**. Keep engine results, static checks, graphical impressions and device evidence distinct.

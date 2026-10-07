# MULLIGAN HILLS

**Build the course. Play it. Grow the club.**

Mulligan Hills is a mobile-first stylized 3D golf-course management game built in **Godot 4.7.2 / GDScript**. Players sculpt terrain, design golf holes, play the course they create, and grow a living golf club from a small operation into a prestigious destination.

**Status: pre-alpha / active development.** The current integration focus is the course-building and practice loop. Multi-hole play, club management, persistent golfers, staff and the wider RPG layer are being developed on top of the same core architecture.

## Current development build

The current project includes:

- touch-first terrain sculpting with Raise, Lower, Smooth and Level tools;
- surface painting for turf, hazards, paths and dirt;
- tee and pin authoring with multiple draft pin positions;
- hole validation, yardage feedback and deterministic rating;
- practice/play on the authored terrain and relief;
- shared persisted world terrain rather than a separate gameplay-only course;
- undo/redo and recoverable editing workflows;
- persistent course, terrain and session state through the save system;
- mobile-first UI with desktop input supported alongside it.

Some systems are still being integrated or validated, including complete multi-hole course flow, final art, management/RPG depth, real-device Android performance and production backend/store integrations.

## Product direction

Mulligan Hills combines three connected fantasies:

1. **Course architect** — shape land, paint surfaces, place hazards, build holes and refine how they play.
2. **Golfer** — play the course you designed with a persistent character whose attributes develop over time.
3. **Club operator** — grow facilities, staff the property, attract recurring golfers and visitors, host events and build a club with personality.

The goal is a management game with enough simulation depth to reward good decisions without burying the player in administration.

## Engineering principles

The project is being built around a small set of architectural rules:

- **One canonical course model.** Editing, rendering, rating, shots and persistence must agree on the same terrain and hole state.
- **Deterministic authoritative logic.** Rating and simulation do not depend on camera state, presentation code or nondeterministic physics.
- **Presentation is not authority.** UI and rendering communicate state; they do not become a second gameplay model.
- **Offline-first persistence.** Core play remains local and reliable, with online services layered on top.
- **Data-driven progression.** Economy, buildings and other tunable systems live in data/specification layers where practical.
- **Mobile first, not mobile only.** Touch interaction and performance budgets lead the design while desktop remains a supported target.
- **Verification is commit-specific.** Historical test results are evidence for the commit that produced them, not automatic approval of current HEAD.

## Architecture at a glance

The current course-authoring path follows one authoritative chain:

**MHCraftHole → MHCraftConvert → canonical course definition + shared relief → rating / practice → save & restore**

`MHCraftTerrainBridge` connects the semantic hole grid to the shared persisted terrain. Elevation is gameplay data: rendering, rating and ball behavior must agree on the same relief.

The wider runtime keeps deterministic domain logic separate from Godot presentation and platform/service integrations.

For the current architecture, status and decision baseline, start with [docs/README.md](docs/README.md).

## Quick start

### Requirements

- Godot **4.7.2**
- GDScript project support
- Compatibility renderer

Open `game/project.godot` in Godot, or from PowerShell:

~~~powershell
cd "$HOME\Documents\GitHub\mulligan-hills"
godot --path ".\game"
~~~

From the launcher, open **Course design & practice** to enter the current player-authored course path.

## Repository guide

| Location | Purpose |
| --- | --- |
| [game/craft](game/craft) | Deterministic course-authoring grid, conversion and terrain bridge |
| [game/core](game/core) | Rating, simulation, session orchestration and persistence |
| [game/gameplay](game/gameplay) | Live course/editor/practice integration |
| [game/terrain](game/terrain) | Shared terrain editing, rendering and terrain checkpoints |
| [game/ui](game/ui) | UI shell and responsive presentation |
| [game/input](game/input) | Touch and desktop input handling |
| [game/tests](game/tests) | gdUnit4 regressions and live integration probes |
| [tools/reference](tools/reference) | Deterministic reference implementations and simulation checks |
| [tools/ci](tools/ci) | Reproducible engine/test/export tooling |
| [.github/workflows](.github/workflows) | CI, determinism and platform build workflows |
| [supabase](supabase) | Cloud-save, account, entitlement and online-service work |
| [android](android), [ios](ios) | Platform integration work |
| [docs](docs) | Architecture, design, decisions, implementation and verification material |

## Development and validation

The repository uses automated tests, deterministic checks, headless/live probes and platform build workflows. Engine/tool versions are pinned in [tools/ci/versions.env](tools/ci/versions.env).

Keep these evidence types distinct:

- **Static/test evidence** — code and automated regression checks.
- **Runtime evidence** — Godot import/execution against the exact commit.
- **Graphical evidence** — interaction and presentation checked in a graphical build.
- **Device evidence** — performance, touch behavior, thermals and platform integration checked on the target hardware.

A pass at an older commit is historical evidence, not a pass for a newer one.

For contributor workflow and regression commands, see [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Current priorities

Near-term engineering work is focused on making the existing foundation reliable before expanding breadth further:

- keep multi-hole state authoritative across rendering, aiming, scoring and save/restore;
- keep the course editor responsive as terrain and art complexity increase;
- validate the mobile interaction and performance budget on real Android hardware;
- continue separating large presentation/controller responsibilities into maintainable subsystems;
- validate store, entitlement and cloud paths in real staging environments;
- integrate management and RPG systems without creating parallel sources of gameplay truth.

## Key documentation

- [Documentation index](docs/README.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Current status](docs/STATUS.md)
- [Current product & architecture decisions](docs/DECISIONS.md)
- [Roadmap](docs/ROADMAP.md)
- [Verification](docs/VERIFICATION.md)
- [Quality gates](docs/QUALITY_GATES.md)
- [Development guide](docs/DEVELOPMENT.md)
- [Supabase/backend status](supabase/README.md)

The repository is under active development. Planned behavior, implemented behavior and verified behavior are intentionally documented as separate states.

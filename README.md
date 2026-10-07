# Mulligan Hills

> **Build Your Golf Legacy.**

**Mulligan Hills** is a stylised 3D golf-course design, management, simulation and light-RPG game being built in **Godot 4**. The project combines hands-on course creation with club operations, golfer simulation, progression, staff and equipment management, events, and the ability to play the course you build.

The primary design target is **mobile**, with Android first and iPhone/iPad support planned, while the project is also intended to support a full desktop experience.

> **Development status:** Pre-release / active development. The repository contains working gameplay and simulation systems, tests, platform infrastructure, prototypes and specifications. It is **not yet a finished or publicly released game**.

---

## The Game

Mulligan Hills starts with a simple idea:

**Build a golf course from the ground up, turn it into a successful club, and create a golf legacy around it.**

The player is not limited to placing prefabricated holes. Course design is intended to be a core creative system: shape terrain, define playing surfaces, place hazards and scenery, develop facilities, watch golfers use the course, improve the club, and eventually compete on the course personally.

The design combines four connected layers:

- **Course design** — sculpt and build a playable golf course.
- **Club management** — manage money, facilities, staff, equipment, golfers and operations.
- **Golf simulation** — golfers and shots are driven by deterministic simulation rather than decorative animation alone.
- **Golf RPG** — develop a personal golfer, play rounds, train attributes, enter events and build a career alongside the club.

The goal is a game with the accessibility and personality of a classic management game, but with substantially deeper course-building, simulation and long-term progression.

---

## Design Principles

### Build, don't just place

The course is meant to feel authored by the player. Terrain elevation, grass, hazards, paths, trees, planting, buildings and hole routing all contribute to how the course looks and plays.

### Simulation that creates stories

Golfers have persistent state and the simulation is designed to produce understandable outcomes: good and bad rounds, preferences, satisfaction, relationships, events, progression and memorable club stories.

### Management depth without turning into accounting software

Staff, equipment, maintenance, facilities, costs and operational warnings matter, but the game is designed around meaningful decisions rather than excessive administrative detail.

### Mobile first, not mobile limited

Touch interaction, landscape layouts, performance budgets and low-end-device considerations are part of the architecture from the beginning. Desktop remains a target experience rather than an afterthought.

### Deterministic core

Simulation-critical systems are designed for deterministic behaviour. Core simulation code uses seeded RNG and integer/fixed-point approaches where results must be reproducible across platforms.

---

## Current Project Highlights

The repository already contains substantial foundations across the game stack, including:

- Godot 4.7 project structure and launcher
- deterministic simulation utilities and cross-platform hash testing
- shot simulation and golf-model reference implementations
- terrain editing, elevation and relief-grid systems
- hole construction and live construction prototypes
- course-rating and elevation-aware golf logic
- golfer and character systems
- economy, land, buildings and progression systems
- staff and equipment systems
- events, challenges and tournament foundations
- save/data schemas and validation
- touch gesture, camera and input routing systems
- isometric camera work
- procedural/stylised rendering systems
- trees, vegetation, turf, paths and water foundations
- mobile-oriented UI and layout systems
- Android platform integration work
- iOS platform design/integration scaffolding
- Supabase backend, migrations, tests and Edge Functions
- automated CI, unit testing and determinism checks
- Android debug, Windows development and iOS/TestFlight workflows
- automated screenshot infrastructure

Implementation maturity varies by system. Some areas are production-oriented foundations, some are playable prototypes, and some remain under active integration.

---

## Target Gameplay

The current v1 direction includes the following major gameplay areas.

### Course creation

Players are intended to be able to shape terrain and construct their own course using systems for elevation, tees, greens, fairways, rough, bunkers, water, vegetation, paths and decorative content.

Elevation is gameplay-relevant: it can affect plays-like distance, ball behaviour, putting difficulty and course evaluation.

The design also calls for multiple turf types, walking paths, cart paths, varied vegetation, landscaping options and procedural visual variety.

### Club development

The club grows from a modest operation into a developed golf destination. Progression includes land, holes, buildings, upgrades, operating costs, golfer demand, membership and long-term prestige.

The economy is being designed around a long-form campaign rather than rapid idle-game progression, followed by open-ended play.

### Golfers and club life

The club is intended to feel inhabited rather than operate as a spreadsheet. Golfers can use the course, form recurring relationships with it, react to conditions and contribute to the stories generated by the simulation.

The broader design includes regulars, members, guests, fictional personalities, visiting pros/celebrities, families, events and golfer-specific statistics.

### Personal golfer

The player will also develop a personal golfer.

The control direction is **decision-led rather than reflex-led**: choose targets, clubs and shot styles, then let golfer attributes and the simulation determine execution. The goal is to make golf strategy and character progression matter without requiring a timing bar or swipe-perfect swing on a phone.

### Staff, equipment and maintenance

Club operations include staff hiring and assignment, equipment ownership and condition, maintenance quality, workshop/facility capability, costs and operational warnings.

These systems are deliberately being balanced to create useful management decisions without overwhelming the player with unnecessary micromanagement.

### Events and tournaments

The design includes hosted tournaments, multi-round events, progression gates, costs and rewards, as well as the player's own golf career and competitive matches.

### Golf carts

Golf carts are part of the club simulation and gameplay. The wider design includes path-aware cart use as well as a free-drive mode, while tournament rules and special characters can alter normal cart behaviour.

---

## Art & UX Direction

Mulligan Hills targets a **clean, colourful, readable stylised-3D presentation** with an isometric course view.

The project takes broad inspiration from the clarity and personality of classic golf-management games while developing its own visual identity and modern mobile-first interaction model.

Current UX priorities include:

- landscape-first presentation
- readable course state at phone scale
- low-friction touch controls
- discrete isometric camera rotation
- useful zoom and pan behaviour
- clear build/management modes
- immediate placement feedback
- strong information hierarchy
- responsive layouts for phones, tablets and desktop
- visual feedback that explains why simulation outcomes occurred

Placeholder and procedural assets in the repository should not be treated as the final visual-quality target.

---

## Technology

| Area | Technology / approach |
| --- | --- |
| Engine | Godot **4.7.2-stable**, standard/GDScript build |
| Language | Typed GDScript |
| Rendering | Godot GL Compatibility renderer |
| Primary platform | Android |
| Additional targets | iOS/iPadOS and desktop |
| Orientation | Landscape |
| Tests | gdUnit4 |
| Backend | Supabase |
| Backend functions | Supabase Edge Functions |
| CI | GitHub Actions |
| Determinism | Seeded RNG, fixed/integer simulation rules and cross-platform hash checks |
| Reference models | Python reference implementations where useful for verification |

The engine/toolchain versions are centrally documented in `tools/ci/versions.env` and `docs/GODOT_VERSION.md`.

---

## Repository Structure

```text
mulligan-hills/
├── .github/
│   └── workflows/          # CI, determinism, platform builds and screenshots
├── android/                # Android plugin/platform source and integration notes
├── docs/                   # Engineering contract, decisions, specifications and runbooks
│   ├── phase0/             # Technical proof / platform documentation
│   ├── phase1/             # Later gameplay and RPG scope work
│   ├── spec/               # Gameplay, data and interface specifications
│   └── store/              # Store/release-related documentation
├── game/                   # Main Godot project
│   ├── art/                # Art-related project content
│   ├── bench/              # Performance/benchmark scenes and scripts
│   ├── characters/         # Character and animation systems
│   ├── core/               # Deterministic simulation and game-domain systems
│   ├── craft/              # Course/hole crafting systems
│   ├── data/               # Game data
│   ├── gameplay/           # Integrated/playable gameplay scenes and controllers
│   ├── gate0/              # Technical proof scenes
│   ├── input/              # Touch, gestures, camera and input routing
│   ├── platform/           # Platform-service abstraction/integrations
│   ├── render/             # Rendering, procedural visuals and performance systems
│   ├── terrain/            # Terrain representation and editing
│   ├── tests/              # gdUnit4 automated tests
│   ├── ui/                 # Launcher and game UI
│   └── project.godot       # Godot project entry point
├── ios/                    # iOS platform notes/integration scaffolding
├── supabase/               # Database, migrations, Edge Functions and backend tests
└── tools/
    ├── animation/          # Animation tooling
    ├── ci/                 # CI setup and test scripts
    └── reference/          # Independent reference implementations/test vectors
```

---

## Getting Started

### Requirements

For normal game development:

- **Git**
- **Godot 4.7.2-stable** — standard build, not .NET
- a desktop capable of running the Godot editor

Additional platform work may require Android Studio/SDK/JDK tooling, Xcode/macOS, Supabase CLI or platform credentials. Those are **not required simply to open and inspect the Godot project**.

### Clone

```bash
git clone https://github.com/NathanTaylorOps/mulligan-hills.git
cd mulligan-hills
```

### Open the game

Open:

```text
game/project.godot
```

in Godot 4.7.2.

The configured main scene is:

```text
res://ui/mh_launcher.tscn
```

Run the project from the editor with **F6/F5 as appropriate**, with **F5** running the configured project entry point.

> The repository is under active development. A clean checkout may require the same dependency/setup steps used by CI before every test or platform-export path is available locally.

---

## Testing

Mulligan Hills uses **gdUnit4** for GDScript tests.

Tests live primarily under:

```text
game/tests/
```

and are grouped by subsystem.

The main CI workflow performs:

1. Python reference-model self-tests.
2. Godot download and checksum verification.
3. gdUnit4 installation.
4. headless Godot project import.
5. headless automated tests.
6. JUnit/test artifact publication.

The CI scripts are under:

```text
tools/ci/
```

The repository also has a dedicated determinism workflow that runs simulation tests on multiple operating systems and compares generated hashes.

This is important because gameplay-critical simulation is intended to produce reproducible results rather than silently diverging by platform.

---

## Continuous Integration

GitHub Actions currently includes workflows for:

- import and unit tests
- cross-platform determinism verification
- Android debug builds
- Windows development builds
- iOS/TestFlight work
- automated screenshots

Workflow definitions live in `.github/workflows/`.

CI is the authoritative place to verify a change that touches engine compatibility, tests or cross-platform behaviour.

---

## Backend

The `supabase/` directory contains the backend foundation for online/platform-connected features, including:

- database migrations
- SQL setup
- Edge Functions
- backend tests
- configuration
- platform verification/integration work

The game architecture is designed so core course design and simulation logic remain separate from platform-service adapters wherever practical.

See `supabase/README.md` for backend-specific setup information.

---

## Android

Android is the first mobile target.

The repository contains Android-specific plugin/integration work, including Play Integrity-related source and build notes. Platform setup is intentionally separated from the main game code.

See:

```text
android/README.md
docs/phase0/platform.md
```

for current platform notes.

---

## iOS / iPadOS

iOS support is planned after the Android-first path. The repository already contains interface and platform-design work so Android-specific decisions do not become hard-coded into the game architecture.

See:

```text
ios/README.md
```

for current status and integration notes.

---

## Project Documentation

This repository uses documentation as part of the engineering process rather than treating it as an afterthought.

Important documents include:

| Document | Purpose |
| --- | --- |
| `docs/DECISIONS.md` | Product and technical decision log |
| `docs/CONTRACT.md` | Engineering conventions and architecture rules |
| `docs/DEFINITION_OF_DONE.md` | Completion criteria |
| `docs/GODOT_VERSION.md` | Engine/toolchain version pin |
| `docs/LICENSE_LEDGER.md` | Asset/source licensing ledger |
| `docs/spec/` | Gameplay, data and interface specifications |
| `docs/phase0/` | Technical proof, test and platform documentation |
| `docs/phase1/` | Later gameplay/RPG design work |

Where code, an older document and the current decision log disagree, contributors should investigate the relevant later decision before changing behaviour.

---

## Engineering Conventions

Key conventions currently used by the project include:

- typed GDScript
- `snake_case` files and functions
- `PascalCase` class names
- project-specific GDScript classes prefixed with `MH`
- deterministic rules for simulation-critical code
- explicit save/data validation
- tests grouped by subsystem
- platform integrations behind adapters/interfaces
- performance decisions measured against mobile constraints
- documented product decisions rather than undocumented scope changes

Simulation-critical code should not introduce nondeterministic random calls, floating-point-dependent result logic or unordered iteration without first checking the project's determinism requirements.

---

## Development Status

Mulligan Hills is moving quickly and the codebase changes frequently.

At this stage, expect:

- unfinished or placeholder presentation
- systems at different levels of completeness
- active balancing and integration work
- specifications that may be ahead of playable UI
- temporary debug/prototype scenes
- platform features that require external credentials or device testing
- changes to structure as systems are consolidated

The repository should be treated as an **active game-development codebase**, not a release package.

---

## Roadmap Direction

The broad direction toward v1 is:

**technical foundation → integrated course builder → club simulation → personal golf/RPG → content and UX polish → device/performance validation → platform integration → balancing/playtesting → release candidate**

Current priorities should be taken from the repository's latest decision/specification documents and active development work rather than this README alone.

---

## Contributing

This repository is currently a privately managed development project.

Before making a substantial change:

1. Read `docs/CONTRACT.md`.
2. Check `docs/DECISIONS.md` for locked product decisions.
3. Review the relevant file under `docs/spec/`.
4. Keep simulation-critical code deterministic.
5. Add or update automated tests.
6. Run the relevant checks where possible.
7. Keep platform-specific logic behind the existing service abstractions.
8. Do not commit credentials, signing keys, API secrets or generated private configuration.

For major gameplay changes, update the design/decision documentation alongside the implementation so the repository remains internally consistent.

---

## Security & Secrets

Never commit:

- Supabase service-role keys
- Android signing keystores/passwords
- Apple signing credentials
- App Store Connect private keys
- Google service-account private keys
- production access tokens
- other platform secrets

Use local environment configuration or GitHub repository/environment secrets as appropriate.

If a secret is committed accidentally, treat it as compromised and rotate it rather than relying only on deleting it from the latest commit.

---

## Licensing

Licensing is tracked in:

```text
docs/LICENSE_LEDGER.md
```

Do **not** assume that every asset, dependency or piece of content in this repository has the same reuse terms.

No broad public licence grant should be inferred from the existence of this repository or from this README. Review the licence ledger and applicable source/dependency licences before redistributing code or assets.

---

## Name & Content Notice

**Mulligan Hills** is the current project name.

Some character/content concepts developed during production may be provisional, parody-inspired or otherwise subject to legal/IP review before public release. Development content should not automatically be treated as approved shipping content.

Third-party game names referenced in design documents are used for comparative design discussion and inspiration only. Mulligan Hills is not affiliated with or endorsed by those games or their rights holders.

---

## Repository

urlNathanTaylorOps/mulligan-hillshttps://github.com/NathanTaylorOps/mulligan-hills

---

**Mulligan Hills — Build Your Golf Legacy.**

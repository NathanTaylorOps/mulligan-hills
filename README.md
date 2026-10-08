<div align="center">

# Mulligan Hills

### Build Your Golf Legacy

**Golf-course design · Club management · Operational simulation · Golf RPG**

![Status](https://img.shields.io/badge/status-pre--release-orange)
![Godot](https://img.shields.io/badge/Godot-4.7.2-478CBF?logo=godot-engine&logoColor=white)
![Primary Platform](https://img.shields.io/badge/primary%20target-Android-3DDC84?logo=android&logoColor=white)
![Language](https://img.shields.io/badge/language-GDScript-478CBF)

</div>

**Mulligan Hills** is an independently developed, mobile-first golf-course design and management game built using **Godot 4**. It combines creative course construction, operational management, deterministic simulation and character-driven gameplay.

Players develop a golf course into a successful club, making decisions about facilities, staffing, equipment, maintenance, finances, customer satisfaction and long-term growth while designing and playing their own courses.

The project brings together several interconnected systems:

- **Course design and infrastructure:** Terrain modification, land development, construction, facilities, landscaping and course maintenance.
- **Business and operational management:** Revenue, operating costs, staffing, equipment, maintenance capacity, service quality and progression.
- **Customer and stakeholder simulation:** Persistent golfers, satisfaction, membership, relationships, demand and events.
- **Technical systems and product development:** Deterministic simulation, data validation, mobile-first interaction, platform integration and automated testing.
- **Gameplay and progression:** Course construction, golf simulation, club development, tournaments and personal golfer progression.

The primary design target is **mobile**, with Android first and iPhone/iPad support planned, alongside a full desktop experience.

## At a Glance

| | |
| --- | --- |
| **Genre** | Golf-course design / management sim / RPG |
| **Engine** | Godot 4.7.2 |
| **Primary target** | Android, landscape |
| **Additional targets** | iOS/iPadOS and desktop |
| **Project state** | Active pre-release development |
| **Core philosophy** | Creative course building + understandable simulation + character-driven club stories |
| **Campaign direction** | Long-form progression into open-ended play |

## Project Approach

Mulligan Hills is being developed as an integrated simulation product rather than a collection of independent gameplay features.

The development approach emphasises clear system boundaries, documented decisions, reproducible simulation behaviour, measurable performance requirements and structured verification.

Particular attention is given to the relationship between operational decisions and their consequences. Staffing, equipment availability, maintenance quality, facility capability and financial constraints are designed to influence how the club performs, while remaining accessible and enjoyable for players.

The technical architecture separates simulation rules from presentation and platform services, supporting consistent behaviour, testing and future development across mobile and desktop environments.

## Development Status

**Active pre-release development.**

The repository contains implemented simulation components, gameplay systems, technical prototypes, automated tests and platform integration work at different stages of maturity.

The game is not yet a finished or publicly released product. Some capabilities remain under development, and successful subsystem tests do not necessarily establish complete gameplay integration or device-level readiness.

The immediate development priorities are integrated gameplay, reliable saving and recovery, mobile usability, visual quality, performance validation and release preparation.

---

## Navigate This Repository

- **[Gameplay direction](#gameplay-direction)** — planned course design, club operations, golfers and progression.
- **[Art and UX](#art--ux-direction)** — presentation and interaction priorities.
- **[Technology](#technology)** — architecture and platform choices.
- **[Getting started](#getting-started)** — open the Godot project locally.
- **[Verification and CI](#verification-and-ci)** — tests, automation and evidence.
- **[Project documentation](#project-documentation)** — specifications, engineering standards and decisions.

For current build and test results, see [GitHub Actions](https://github.com/NathanTaylorOps/mulligan-hills/actions). A documented feature or workflow is not necessarily integrated or passing.

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

## Gameplay Direction

The following describes intended gameplay, not a checklist of completed or fully integrated features.

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

Run the configured project entry point with **F5**. Use **F6** to run the currently open scene.

> The repository is under active development. A clean checkout may require the same dependency/setup steps used by CI before every test or platform-export path is available locally.

---

## Verification and CI

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

The repository also defines workflows for cross-platform determinism checks, Android debug builds, Windows development builds, iOS/TestFlight preparation and automated screenshots. The presence of a workflow does not establish that its latest run passed or that the corresponding platform is release-ready. Check [GitHub Actions](https://github.com/NathanTaylorOps/mulligan-hills/actions) for current results.

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

See `supabase/README.md` for backend-specific setup information. Android integration notes are in `android/README.md` and `docs/phase0/platform.md`; iOS planning and integration notes are in `ios/README.md`.

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

## Roadmap Direction

The broad direction toward v1 is:

**technical foundation → integrated course builder → club simulation → personal golf/RPG → content and UX polish → device/performance validation → platform integration → balancing/playtesting → release candidate**

Current priorities should be taken from the repository's latest decision/specification documents and active development work rather than this README alone.

---

## Contributing

This public repository is independently maintained. See [CONTRIBUTING.md](CONTRIBUTING.md) for the full development and contribution workflow, [CHANGELOG.md](CHANGELOG.md) for release-level project changes, and [SECURITY.md](SECURITY.md) for security reporting.

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

This repository does not currently grant a general open-source licence. Licensing is tracked in:

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

[NathanTaylorOps/mulligan-hills](https://github.com/NathanTaylorOps/mulligan-hills)

---

**Mulligan Hills — Build Your Golf Legacy.**

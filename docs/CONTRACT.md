# Engineering standards and delivery contract

Mulligan Hills is a mobile-first golf-course design, club-management and golf RPG project built with Godot and typed GDScript. This document defines the engineering standards used to develop, verify and integrate the project. It applies to gameplay, simulation, user interfaces, platform services, assets and supporting tools.

The project is in active pre-release development. An implemented component is not necessarily integrated, device-tested or release-ready. Claims about completion must reflect the available evidence.

## Scope and technical baseline

- **Project root:** `game/`; entry point and configuration are defined in `game/project.godot`.
- **Engine and toolchain:** Use the versions pinned in `tools/ci/versions.env` and documented in `docs/GODOT_VERSION.md`.
- **Primary platform:** Android phones, including lower-end hardware; tablet, iOS/iPadOS and desktop support are additional targets.
- **Simulation:** Preserve deterministic rules for gameplay-critical outcomes.
- **Backend:** Keep account, purchase and other platform-connected functions separate from the local simulation wherever practical.

Product scope and accepted design decisions are recorded in `docs/DECISIONS.md` and the relevant `docs/spec/` files. Earlier Phase 0 technical proofs are retained under `docs/phase0/` as historical engineering evidence, not as a substitute for current integration testing.

## Architecture and code quality

1. Use typed GDScript, `snake_case` for files/functions and `PascalCase` for classes. Project-specific GDScript classes use the `MH` prefix.
2. Keep domain rules and persistent state separate from presentation and platform adapters. Avoid duplicating business rules in UI controllers.
3. In deterministic simulation and rating paths, follow the documented fixed-point/integer conventions. Do not introduce unseeded randomness, unordered iteration, engine-physics dependencies or floating-point-sensitive results without a documented design decision and appropriate verification.
4. Validate data crossing save, network and platform boundaries. Handle missing, malformed, older-version and partially available data explicitly.
5. Prefer cohesive, testable modules with clear interfaces and bounded responsibilities. Changes to shared interfaces require review of affected callers and tests.
6. Maintain compatibility with the supported input methods and performance constraints. Desktop-only behaviour is not sufficient evidence for a mobile-first feature.
7. Protect secrets, credentials, personal data and third-party assets. Follow `SECURITY.md` and `docs/LICENSE_LEDGER.md`.

## Ownership and change control

Changes should have a defined scope, affected paths and acceptance criteria. Coordinate edits to shared modules, interfaces and configuration before parallel work begins. Temporary workstream assignments are not permanent repository architecture.

The relevant documentation is authoritative for its own purpose:

| Reference | Purpose |
| --- | --- |
| `docs/DECISIONS.md` | Recorded product and technical decisions, including supersession |
| `docs/spec/` | Behaviour, data contracts and feature specifications |
| `docs/DEFINITION_OF_DONE.md` | Verification and completion requirements |
| `docs/GODOT_VERSION.md` | Engine and tooling baseline |
| `docs/phase0/` | Historical proof work, measurements and unresolved assumptions |
| `CONTRIBUTING.md` | Contribution, review and pull-request process |
| `SECURITY.md` | Vulnerability handling and sensitive integrations |

When implementation and documentation disagree, investigate the discrepancy. Do not silently treat an older proposal as a current requirement or rewrite an accepted decision without recording the change.

## Verification and evidence

- Add or update subsystem tests for new behaviour and regression tests for defects.
- Run relevant Godot import, gdUnit4, reference-model, determinism, platform-build and data-validation checks as applicable.
- Verify user-facing features through the integrated game flow; use target-device evidence when interaction, rendering or performance is material.
- Report tests that were **not run**, checks that failed and assumptions that remain unverified. A successful local test does not imply successful cross-platform or device verification.
- Do not weaken checks, alter expected results or bypass branch protections merely to obtain a passing build.
- Record reproducible commands, relevant CI links, known limitations and any save-compatibility or performance impact in the change review.

A feature is complete only when the applicable criteria in `docs/DEFINITION_OF_DONE.md` are met. Code presence, an isolated prototype or a passing unit test alone does not establish release readiness.

## Performance and platform considerations

Treat low-end mobile hardware as a design constraint. Assess frame time, memory, asset size, input latency and scaling with course complexity when introducing rendering or simulation work. Keep touch targets, camera controls, text legibility and recovery paths usable on phone screens. Document device-specific limitations rather than presenting desktop behaviour as proof of mobile readiness.

## Historical Phase 0 decisions

The following integration details remain relevant to existing code and tests; they should be verified against the implementation before changes:

- The terrain editor exposes stroke lifecycle and undo/redo operations in `game/terrain/`. Reconcile any differences with `docs/spec/interfaces/terrain.md` rather than assuming the interface specification and code are identical.
- Module tests may be located under `game/tests/` or alongside their subsystem. The test runner must discover the supported `test_*.gd` files.
- Touch-to-mouse emulation is disabled in the project configuration; desktop input support uses the project's input mapping.
- Earlier performance budgets and gameplay thresholds identified as provisional remain subject to measurement and explicit acceptance.

This contract describes engineering practice and current constraints. It does not claim that every planned system is complete or that all validation has passed.

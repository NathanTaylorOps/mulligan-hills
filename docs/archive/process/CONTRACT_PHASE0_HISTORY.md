# Mulligan Hills: Engineering Contract (Phase 0)

Read this fully before writing anything. Every agent works under it.

## Project
Mulligan Hills is a golf course design tycoon for phones (Android first, iPhone later, tablets), stylized 3D, day only, built in Godot 4.x with GDScript. The master plan is the Docs artifact "Mulligan Hills: Master Plan" (project id 5991cb68-b96d-45aa-a0ac-f25408624480). Phase 0 exists to prove the risky technical parts before anything else is built. Gate 0 has 10 proof items (listed in docs/phase0/GATE0.md).

## Environment facts (important)
- Nobody can run Godot 4 in this sandbox: downloads are blocked. Code is validated by CI on GitHub Actions later. Therefore: write small, conservative, typed GDScript; prefer APIs stable across Godot 4.3 to 4.7; mark anything you are unsure about in a Unverified section of your status doc; never claim code was run when it was not. Say "NOT YET RUN" plainly.
- Python 3.11 is available here. Use it for reference implementations and golden test vectors. Network to package registries may be blocked; do not depend on installing anything.
- The manager (Nathan) is not a programmer. Any instruction meant for him must be exact, numbered, copy-paste, with no assumed knowledge.
- Target devices: a budget Android phone (low end), an iPhone, an Android tablet. CI runs on GitHub Actions (Ubuntu and macOS runners).

## Repo layout and ownership
Each agent writes ONLY inside its own paths. Do not edit another agent's files. Do not run git; the lead commits.

| Owner workstream | Paths |
| --- | --- |
| A ci | .github/workflows/, tools/ci/, docs/phase0/ci.md, docs/GODOT_VERSION.md, game/project.godot, game/export_presets.cfg.template, .gitignore, .gitattributes |
| B determinism | game/core/, game/tests/core/, tools/reference/determinism/, docs/phase0/determinism.md |
| C terrain | game/terrain/, game/tests/terrain/, tools/reference/terrain/, docs/phase0/terrain.md |
| D forest | game/render/, game/bench/, game/tests/render/, docs/phase0/forest.md |
| E gestures | game/input/, game/tests/input/, docs/phase0/gestures.md |
| F platform | game/platform/, android/, ios/, docs/phase0/platform.md |
| G animation | game/characters/, tools/animation/, docs/phase0/animation.md, docs/LICENSE_LEDGER.md |
| H spec | docs/spec/, docs/DEFINITION_OF_DONE.md, docs/DECISIONS.md, docs/phase0/GATE0.md |
| I device | docs/phase0/device_runbook.md, docs/phase0/soak_protocol.md |

Shared decisions: the game project root is game/. GDScript classes use the prefix MH. Tests use gdUnit4 under game/tests/<module>/.

## Code rules
- Typed GDScript everywhere.
- Simulation and rating code uses integers and fixed-point only where deterministic outcomes depend on it.
- Every module has a short status summary.
- No invented facts about APIs, plugins, prices or policies.
- Instructions intended for the project manager were written as copy-paste steps.

## Status doc format
1. What was built
2. How it is tested
3. Gate 0 criteria covered
4. Unverified assumptions
5. Risks and follow-ups
6. Manager actions if required

## Definition of done for Phase 0 work
Files exist, typed, self-consistent, tests written, status doc complete, honest about what is unrun.

## Lead decisions after the first Phase 0 round (29 Sep 2026)
- Terrain API in game/terrain/ was authoritative.
- New module paths were established for rating, economy, buildings, save and UI.
- Tests could live under game/tests or beside platform/character modules.
- Touch emulation defaults and score/land/performance placeholders were recorded for the next phase.

> Historical note: this document is preserved to explain the original workstream process. It is not current engineering policy.

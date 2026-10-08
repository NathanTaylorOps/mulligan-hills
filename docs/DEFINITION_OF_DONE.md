# Definition of done and delivery governance

This document establishes evidence-based completion criteria for Mulligan Hills. It applies to code, assets, content, integrated gameplay and release candidates. Its purpose is to maintain a consistent standard of quality, traceability and risk control during pre-release development.

A component is not complete merely because its files exist. Completion requires the relevant tests, integration evidence, review and documented limitations. The standards below should be applied proportionately to the scope of each change; release-specific requirements apply when preparing a release.

## 1. Change management

1. Define the intended outcome, affected modules, acceptance criteria and dependencies before significant changes.
2. Use focused branches and pull requests. Coordinate changes to shared interfaces and files to avoid conflicting work.
3. Record the reason for behaviour or scope changes in `docs/DECISIONS.md` and update the relevant specifications.
4. Review changes independently where practical, including correctness, compatibility, security, performance and user impact.
5. Do not bypass required checks or merge failing work as though it were verified. If an exception is necessary, record its scope, approval, risk and remediation.
6. Report verification precisely: **passed**, **failed**, **not run**, or **not applicable**, with supporting evidence where available.

## 2. Code completion criteria

- [ ] The change meets its documented acceptance criteria and relevant interfaces.
- [ ] GDScript naming, typing and deterministic simulation rules follow `docs/CONTRACT.md`.
- [ ] New behaviour and corrected defects have appropriate automated tests, including edge cases and regressions.
- [ ] Relevant Godot import, unit, schema, reference-model and determinism checks pass; exceptions are recorded rather than hidden.
- [ ] Save compatibility, migrations and malformed-data handling are addressed when persistent data changes.
- [ ] User-facing features are reachable through the intended interaction flow, not solely through isolated test scenes.
- [ ] Platform-specific behaviour is verified on relevant target devices when material.
- [ ] Performance impact is measured against an established budget when applicable.
- [ ] Documentation, known limitations and evidence are updated with the implementation.

A successful subsystem test does not establish that the integrated game is playable or release-ready.

## 3. Art and interface completion criteria

- [ ] Visual assets follow the approved art direction and maintain consistent scale, lighting and readability.
- [ ] Source files, provenance and reuse rights are recorded as required by `docs/LICENSE_LEDGER.md`.
- [ ] Assets import correctly and remain within the applicable performance and memory budgets.
- [ ] Meaningful visual changes are reviewed in the integrated game, including representative mobile screen sizes.
- [ ] Touch interactions, feedback, text contrast and information hierarchy support the intended audience.
- [ ] Motion and animation do not conceal gameplay state or impair responsiveness.

Concept imagery and placeholders are design references, not evidence of final in-engine quality.

## 4. Content completion criteria

- [ ] Gameplay text and data use the documented schemas and validation processes.
- [ ] Copy is consistent, readable and appropriate to the game's fictional setting.
- [ ] Content effects are bounded and consistent with the game rules.
- [ ] Third-party audio, artwork and other material have appropriate licence records.
- [ ] Content requiring store, privacy or intellectual-property review is cleared before release.

## 5. Release readiness

A release candidate requires evidence appropriate to the intended distribution channel:

- [ ] Required CI and integration checks pass on the release commit.
- [ ] No unresolved release-blocking defects remain; any accepted lower-severity issues have documented risk and ownership.
- [ ] Core gameplay is tested from a cold launch through meaningful play, save/reload and recovery scenarios.
- [ ] Relevant device testing covers performance, thermal behaviour, stability and interaction quality.
- [ ] Purchase, entitlement, restoration and account flows are verified where enabled.
- [ ] Privacy, store-policy, support and licence requirements are reviewed against current platform rules.
- [ ] Build identifiers, signing, artifact integrity, deployment and rollback procedures are recorded.
- [ ] Release approval and known limitations are documented.

Proposed quantitative thresholds, such as crash-free rate or device-frame budgets, require measured evidence and explicit acceptance. Do not report provisional targets as achieved results.

## 6. Module coordination

The following domains guide change impact and review. They are not exclusive file ownership assignments.

| Domain | Primary locations | Review considerations |
| --- | --- | --- |
| Build and automation | `.github/workflows/`, `tools/ci/` | Reproducibility, dependency pinning, CI evidence |
| Simulation and rating | `game/core/`, `tools/reference/` | Determinism, numerical correctness, compatibility |
| Terrain and course design | `game/terrain/`, `game/craft/` | Editing lifecycle, save state, usability |
| Rendering and assets | `game/render/`, `game/art/`, `game/bench/` | Visual quality, device performance, licensing |
| Input and UI | `game/input/`, `game/ui/` | Touch and desktop controls, accessibility |
| Characters and gameplay | `game/characters/`, `game/gameplay/` | Persistent state, progression, integrated behaviour |
| Platform and services | `game/platform/`, `android/`, `ios/`, `supabase/` | Security, privacy, account and purchase boundaries |
| Product specifications | `docs/spec/`, `docs/DECISIONS.md` | Consistency, acceptance criteria, traceability |

Shared changes should identify affected consumers and verification responsibilities.

## 7. Pull-request evidence

A substantive pull request should provide:

- **Purpose:** problem, intended outcome and affected behaviour.
- **Scope:** relevant files and systems, including any interface or data changes.
- **Verification:** tests run, results and links to CI or device evidence where applicable.
- **Impact:** user experience, performance, compatibility, privacy and licensing considerations.
- **Limitations:** known issues, unverified assumptions and follow-up work.
- **Review:** approval or documented exception before integration.

## 8. Review checklist

Reviewers should consider whether the change:

1. Solves the stated problem without unrelated modifications.
2. Preserves established architecture, interface and deterministic behaviour.
3. Handles empty, malformed, boundary and legacy inputs safely.
4. Includes meaningful regression coverage.
5. Is reachable and understandable in the integrated game where applicable.
6. Meets relevant mobile performance and usability requirements.
7. Respects security, privacy, entitlement and third-party licence boundaries.
8. Describes testing and limitations accurately.

## 9. Defect classification

| Severity | Definition | Release treatment |
| --- | --- | --- |
| S0 — Critical | Data loss, serious security/privacy issue, payment integrity failure or repeated launch failure | Blocks release; immediate investigation |
| S1 — High | Core gameplay unavailable or severely degraded without a reasonable workaround | Blocks release |
| S2 — Moderate | Material defect with a workaround or limited impact | Fix before release or document an approved exception |
| S3 — Low | Cosmetic or minor usability defect | Prioritise within the normal backlog |

Each defect should include reproducible steps, affected build, expected and observed behaviour, relevant device/environment details and available diagnostic evidence. Severity and remediation priorities should be reviewed as new evidence emerges.

## 10. Relationship to project decisions

This document operationalises the quality and governance intent of decision DEC-041 without changing the recorded decision history. Historical Phase 0 ownership and approval arrangements remain available in the decision log and associated records; current delivery should use the review and evidence requirements above.

# Mulligan Hills — Current Product & Architecture Decisions

This document is the **current-state decision register** for Mulligan Hills. It records the product and architecture choices that are active now, why they matter, and where further validation is still required.

The complete historical decision trail — including superseded choices, review notes, and earlier rationale — is preserved in [the decision history](decisions/archive/DECISIONS_HISTORY_2026-10-07.md). Historical entries remain useful for traceability, but they are not the current product specification.

## Decision status

| Status | Meaning |
| --- | --- |
| **Locked** | Current direction. Change only through an explicit replacement decision. |
| **Active** | Current direction, with implementation or validation still in progress. |
| **Provisional** | Working decision that still depends on measured evidence or release data. |
| **Open** | Deliberately unresolved. Do not infer a final choice. |

## Current decision index

| ID | Area | Current decision | Status | Historical sources |
| --- | --- | --- | --- | --- |
| ADR-001 | Product & platforms | Mulligan Hills is a mobile-first stylized 3D golf-course management game. Android is the first mobile target; iOS follows; desktop is supported alongside mobile. Landscape only. | Locked | DEC-001, 002, 078, 094 |
| ADR-002 | Engine & renderer | Godot 4.7.2 with GDScript. Compatibility renderer is the current renderer. | Locked | DEC-003, 035 |
| ADR-003 | Camera | Gameplay uses a fixed-pitch 3D isometric camera with discrete rotation, zoom and edge-aware pan. Camera state never changes simulation or rating outcomes. | Locked | DEC-004, 085 |
| ADR-004 | Course authority | The course uses one shared persisted world terrain. Hole craft data is a deterministic semantic/rating layer over that same ground, not a second private terrain world. | Locked | DEC-092 |
| ADR-005 | Terrain & elevation | Elevation is gameplay data. Relief affects rating, effective shot distance, landing roll and putting difficulty. | Locked | DEC-091, 092 |
| ADR-006 | Course-building UX | Course building is the primary current UX focus: navigation, sculpting, surface painting, hole design and terrain art. Editing feedback is contextual rather than a permanent construction grid. | Active | DEC-084, 093, 094 |
| ADR-007 | Tee & pin model | One tee box per hole. A hole may define up to four pin positions; changing pin positions between rounds remains part of the design. | Active | DEC-088, 090 |
| ADR-008 | Deterministic simulation | Rating and simulation use deterministic data paths, owned random state and integer/fixed-point techniques where cross-platform consistency matters. Graphics and engine physics are not authoritative gameplay inputs. | Locked | DEC-025, 037 |
| ADR-009 | Personal golf | Players create and progress a personal golfer and play the course they build. Shot play is target/shot-style decision making with attribute-driven execution rather than mandatory reflex timing. | Locked | DEC-072, 076 |
| ADR-010 | Living-club RPG | v1 includes a living club: persistent golfers, visitors, staff, course-condition effects, wildlife/pest interactions, maintenance choices and contextual character interactions. | Locked | DEC-073 |
| ADR-011 | Progression & rewards | Course, club and golfer progression culminate in a long-form career. Achievements can award persistent visible course decorations and building skins without silently changing core economic/rating rules. | Locked | DEC-074, 075 |
| ADR-012 | Campaign pacing | The working campaign target is about 50 running hours to reach 18 holes, all tier-5 buildings and an agreed golfer-career milestone, followed by open-ended play. The final career milestone remains open. | Provisional | DEC-070, 071, 075 |
| ADR-013 | Time controls | A normal game day is 25 real minutes. Current speeds are 1x, 2x and 8x; 1x/2x are free and 8x uses earned tokens. Editing remains available while paused. | Locked | DEC-070, 087 |
| ADR-014 | Buildings & tournaments | The management loop uses ten building categories with tiered progression. Tournaments are a required progression system and tier-5 gate, with circular dependencies explicitly avoided. | Locked | DEC-008, 010, 026, 027, 065 |
| ADR-015 | Monetization | Free demo plus one-time full-game unlock. No ads in v1, no premium currency and no paid skips. Earned tokens may support in-game time acceleration. Final unlock price remains provisional until test data. | Provisional | DEC-006, 007, 028, 064 |
| ADR-016 | Offline & cloud | The game is offline-first. Supabase provides cloud save and online services; cloud conflicts are surfaced to the player rather than silently overwriting a save. | Active | DEC-012, 058, 059 |
| ADR-017 | Entitlement & integrity | Full-game entitlement is tied to the store purchase, verified online and cached as a signed entitlement. Save files never carry purchase entitlement. Competitive online checks begin with validation/rate limits and can add stronger re-simulation where justified. | Active | DEC-029, 030, 036 |
| ADR-018 | Scope boundaries | Shared hole codes/player-made challenge sharing, simultaneous multiplayer, fights and mandatory third-person golf are not v1 requirements. Post-launch expansions remain separate from the current launch baseline. | Locked | DEC-015, 016, 089 |
| ADR-019 | Art direction | The visual target is cohesive stylized 3D and must clearly exceed placeholder/prototype quality. The project is currently heavily procedural; whether final production remains code-only procedural or permits authored assets is intentionally unresolved. | Open | DEC-013, 062, 086 |
| ADR-020 | Visual variety | Placeable/environment categories should provide meaningful type, scale and colour variety while remaining within measured mobile performance budgets. | Active | DEC-079, 080, 081, 082, 083 |
| ADR-021 | v1 scope baseline | The original September scope freeze was expanded by explicit later decisions to include personal golf and living-club RPG systems. Those additions are now part of the v1 product direction; schedule confidence must be re-established through measured integration milestones. | Active | DEC-014, 072, 073, 074, 075, 088, 090 |
| ADR-022 | Privacy & release governance | Analytics is opt-in. Store compliance, account deletion, terms/privacy material, entitlement handling and platform policy checks are release requirements rather than optional follow-up work. | Active | DEC-031, 057 |

## Detailed decision notes

### ADR-001 — Product & platform strategy

Mulligan Hills is a stylized 3D golf-course management game built around a simple product promise: **build the course, play it, and grow the club**.

Mobile is the primary UX target. Android is the first mobile release target, iOS follows, and the same game architecture supports a desktop version. The application is landscape-only.

**Why:** the course editor must feel natural on a phone first without preventing a stronger desktop presentation later.

### ADR-002 — Engine and rendering

The project uses **Godot 4.7.2 / GDScript** and the Compatibility renderer.

Gameplay systems should remain conservative about engine-specific behavior where determinism, portability or platform support matters.

**Why:** one pinned engine/toolchain reduces integration ambiguity and keeps the project focused on a single supported runtime.

### ADR-003 — Camera

The primary course view is 3D isometric with a fixed pitch, discrete rotational views, zoom and edge-aware pan. Optional presentation views may exist, but the game rules never depend on the camera.

**Why:** this preserves the readable management-game presentation while allowing modern 3D terrain and assets.

### ADR-004 — Canonical course and terrain authority

There is one authoritative persisted world terrain. Course-authoring data adds the semantic information needed for rating and gameplay over that same world.

Editing, rendering, rating, shots and save/restore must agree on the same terrain and elevation state.

**Why:** duplicate terrain authorities create visual/gameplay disagreement and make save behavior fragile.

### ADR-005 — Elevation as gameplay

Elevation is not cosmetic. Relief influences shot distance, ball roll, putting difficulty and the rating model.

**Why:** terrain sculpting should create meaningful golf decisions, not just visual variation.

### ADR-006 — Course-building experience

The immediate product focus is the course-building loop: editor navigation, sculpting, surface painting, hole design, validation, practice and terrain art.

The normal course view uses final-style materials. Construction grids and other technical overlays appear only when they are useful for an active editing tool.

**Why:** the course view should remain visually dominant and editing should feel direct, recoverable and touch-friendly.

### ADR-007 — Tee and pin model

Each hole uses one tee box and may store up to four pin positions. Pin variation across rounds remains part of the intended course-management experience.

**Why:** one tee keeps authorship readable while multiple pins add replay variety without multiplying hole definitions.

### ADR-008 — Deterministic core

Authoritative rating/simulation logic is independent of graphics, camera state and nondeterministic physics. Deterministic random state and integer/fixed-point techniques are used where cross-platform reproducibility matters.

**Why:** the same course should produce the same authoritative result across supported devices and CI.

### ADR-009 — Personal golf

Personal golf is a core v1 system. The player creates and develops a golfer, trains attributes and plays the course they built.

Shot interaction emphasizes strategy: choose a target and shot style, inspect risk/reach feedback, then let golfer attributes drive execution.

**Why:** the player should care about the course both as an architect/manager and as a golfer.

### ADR-010 — Living club

The course is intended to feel inhabited rather than operate as a static spreadsheet. Persistent golfers, staff, visitors, maintenance, course condition, wildlife/pests and contextual interactions contribute to the club simulation.

**Why:** recurring characters and visible cause/effect create the RPG layer around the management game.

### ADR-011 — Progression and visible rewards

Progression spans the course, club and personal golfer. Achievements and milestones may grant persistent visible decorations and skins.

Cosmetic rewards do not silently change building tier, footprint, economic gates or official rating rules.

**Why:** progression should be visible without turning cosmetics into hidden balance modifiers.

### ADR-012 — Campaign pacing

The working target is roughly **50 running hours** to reach 18 holes, all tier-5 buildings and a golfer-career milestone, followed by open-ended play.

The exact final golfer-career milestone remains open and the complete RPG path still requires integrated simulation and playtesting.

**Why:** the campaign needs a meaningful long-form arc without making the sandbox finite.

### ADR-013 — Time and speed

A normal game day lasts 25 real minutes. Supported speeds are 1x, 2x and 8x. The 8x mode uses earned tokens; no real-money time-skip purchase is required.

Editing remains available while paused.

**Why:** time pressure should not punish creative course design.

### ADR-014 — Buildings and tournaments

The management progression uses ten building categories with five tiers. Building gates are data-driven and designed to prevent reversible/circular progression exploits.

Tournaments are a required v1 system and remain the prestige gate for top building tiers.

**Why:** management progression needs a clear climax tied to the quality and maturity of the club.

### ADR-015 — Monetization

The current model is a free demo with a one-time unlock for the full game. v1 has no ads, premium currency or paid skips.

The final price remains provisional until conversion data exists.

**Why:** monetization should be easy to understand and should not distort the simulation.

### ADR-016 — Offline-first cloud model

Core play works offline. Supabase supports cloud save and online services. Cloud conflicts are resolved explicitly by the player rather than by automatic destructive overwrite.

**Why:** mobile connectivity is unreliable and local progress must remain trustworthy.

### ADR-017 — Entitlement and online integrity

Unlock entitlement comes from the app-store purchase rather than from the save file. Online verification produces a signed cached entitlement for offline use.

Competitive submissions use server-side validation and rate controls, with stronger verification reserved for cases where the value justifies the infrastructure.

**Why:** purchase state and competitive trust should not depend on editable local save data.

### ADR-018 — Scope boundaries

The current v1 does **not** require shared-hole UGC, simultaneous multiplayer, fights with golfers or mandatory third-person golf.

Future expansions can add broader content after the core course/club experience is proven.

**Why:** these systems carry disproportionate moderation, networking or production cost relative to the current core loop.

### ADR-019 — Art direction

The visual target is cohesive stylized 3D. Prototype geometry, generated thumbnails and flat placeholder materials are not the final quality bar.

The production method is still open: the historical code-only procedural-art rule is under review because visual quality and mobile performance must take priority over process purity.

**Why:** the project needs a repeatable art pipeline, but the pipeline must serve the quality target rather than constrain it.

### ADR-020 — Visual variety within performance budgets

Trees, vegetation, paths, turf and placeable categories should provide meaningful variety. Reuse, batching, instancing and measured scene budgets are part of the implementation strategy.

**Why:** visual variety matters to a course-builder, but mobile performance is a hard constraint.

### ADR-021 — Current v1 baseline

The original September scope freeze was later expanded through explicit decisions. Personal golf, living-club RPG systems and the richer course-building experience are now part of the v1 direction.

This does **not** mean the old schedule estimate remains valid. Schedule confidence must be rebuilt from measured integration milestones and device testing.

**Why:** scope changes should be explicit without pretending their schedule impact does not exist.

### ADR-022 — Privacy and release governance

Analytics is opt-in. Account deletion, privacy/terms material, platform purchase compliance, entitlement restoration and applicable store-policy checks are release requirements.

Character names, branding and other potentially sensitive public-facing IP remain subject to pre-release review or replacement.

**Why:** release readiness includes policy, privacy and ownership obligations, not only code completion.

## Open decisions

Only genuinely unresolved items belong here:

1. **Baseline Android device:** select and record the exact low-end/reference device used for performance acceptance.
2. **Final unlock price:** set from closed-test conversion evidence; the current price is provisional.
3. **Post-launch expansion monetization:** paid versus free remains undecided.
4. **Final golfer-career milestone:** define the career milestone required alongside 18 holes and tier-5 club completion.
5. **Final art production policy:** decide whether production remains fully procedural/code-generated or allows authored assets where required to reach the visual-quality target.
6. **Remaining balance values:** any parameters explicitly marked provisional in their owning gameplay/economy specifications remain subject to simulation and playtesting.
7. **Release clearance and policy checks:** complete formal branding/trademark and applicable store/privacy review before public release.

## How decisions change

A current decision is changed by replacing or amending the relevant ADR in this document and recording the superseded state in the historical archive. Do not keep contradictory active decisions in parallel.

Decision records describe **intent**. Implementation status and verification status are separate:

- **Decision** — what the project intends.
- **Implemented** — what currently exists in code.
- **Verified** — what has been exercised successfully on the relevant runtime/device.

Those three states should not be treated as interchangeable.

## Historical record

The full original decision log through 7 October 2026 is preserved unchanged in:

[docs/decisions/archive/DECISIONS_HISTORY_2026-10-07.md](decisions/archive/DECISIONS_HISTORY_2026-10-07.md)

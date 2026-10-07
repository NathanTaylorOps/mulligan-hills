# Mulligan Hills architecture

Status: current architecture overview.

Mulligan Hills is structured so game rules remain testable and deterministic while Godot scenes handle presentation, input and platform integration.

## Core principle

There is one authoritative gameplay state for each domain. Rendering and UI may present that state, but they do not create parallel gameplay models.

## Course authoring and terrain

- MHCraftHole owns the deterministic semantic authoring grid for a hole.
- MHCraftConvert converts authored data into the canonical gameplay/rating definition.
- MHCraftTerrainBridge synchronizes semantic hole edits with the shared persisted world terrain.
- Shared terrain is the world authority for elevation and visible ground.
- Relief used by rendering, rating, aiming and ball behavior must remain consistent.

## Rating and simulation

Authoritative rating and simulation use deterministic inputs and owned random state. Rules do not depend on camera position, frame rate, presentation-only geometry or nondeterministic engine physics.

Reference implementations under tools/reference/ provide independent checks for deterministic subsystems.

## Session orchestration

MHGameSession coordinates major domains such as economy, staff and customer progression. It should remain an orchestrator rather than becoming the home of each domain's calculations.

Preferred direction:

    domain state -> pure/domain effects -> session orchestration -> presentation

## Persistence

The save layer validates schema, checksums and cross-domain invariants before accepting restored state.

Persistence changes should move together:

    schema -> validator -> serializer -> restore -> reader/migration logic -> regression tests

Entitlements and store receipts remain separate from save data.

## Platform and backend

Billing, integrity, cloud, analytics and account services sit behind platform/service adapters. Gameplay code should not call native plugins or backend endpoints directly.

Native asynchronous operations require explicit timeout, error and lifecycle behavior.

Supabase provides cloud-save, account, remote-config, analytics and entitlement-related server components. Local/fake-backend validation is not equivalent to staging or production verification.

## Authority matrix

| Concern | Authority |
| --- | --- |
| Product/architecture decisions | docs/DECISIONS.md |
| Current implementation state | source + tests + docs/STATUS.md |
| Terrain elevation | shared persisted terrain |
| Hole semantics | canonical craft/course definition |
| Rating/simulation outcome | deterministic core |
| Save validity | save schema + runtime validators |
| Purchase entitlement | store/server entitlement path |
| Visual appearance | render/UI layer |
| Verification claims | exact-SHA evidence |

## Constraints to preserve

1. Do not introduce a second hole or terrain authority.
2. Do not let presentation-only state mutate progression.
3. Do not make graphics quality affect gameplay outcomes.
4. Do not silently repair corrupt persisted state into a different valid state.
5. Do not add platform-specific behavior directly to domain logic.
6. Do not treat historical test evidence as proof for a newer commit.

## Current pressure points

- The course editor/practice panel remains too large and should continue moving toward smaller controllers/renderers.
- Real multi-hole world placement is not complete; authored holes still share a development origin/window.
- Mobile render cost needs measured device evidence before visual density increases aggressively.
- Platform/backend interfaces require staging and real-device validation.

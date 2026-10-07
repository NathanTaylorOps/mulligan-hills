# Mulligan Hills engineering principles

This document defines the evergreen engineering contract for the repository.

## 1. One source of authority per domain

Do not create parallel gameplay models for convenience.

- Shared terrain owns world elevation.
- Canonical craft/course data owns hole semantics.
- Deterministic core owns rating/simulation outcomes.
- Save validators own persisted-state acceptance.
- Store/server entitlement owns purchase state.
- Presentation owns visuals only.

## 2. Deterministic core stays deterministic

Authoritative simulation/rating code must not depend on camera state, frame rate, unordered presentation state or nondeterministic physics.

When cross-platform reproducibility matters, use the established deterministic primitives and reference tests.

## 3. Evidence beats assertion

Use the terms precisely:

- **implemented** — exists in source;
- **verified** — executed successfully with evidence;
- **accepted** — meets the relevant product/UX/device gate.

Do not carry a historical PASS forward to a newer commit.

## 4. Persistence changes are cross-system changes

Any persisted field change must update the appropriate schema/validator/serializer/restore/migration or reader-capability logic and include regression coverage.

Reject impossible restored states rather than silently inventing a replacement state.

## 5. UI is an adapter, not the domain

UI should emit intent and render state. Domain rules belong in domain/session/controller layers.

Avoid increasing responsibility in large presentation classes when a smaller controller/service boundary can be introduced safely.

## 6. Platform seams fail safely

External/native operations need explicit timeout, error and lifecycle behavior. Gameplay must not hang forever waiting for a plugin callback or network response.

## 7. Mobile constraints are measured

Do not optimize or increase visual density from intuition alone. Profile target hardware and record frame time, memory and sustained behavior where relevant.

## 8. Changes stay reviewable

Prefer focused commits and integration slices. A change should state:

- what authority/domain it changes;
- what files are affected;
- what test proves it;
- what remains unverified.

## 9. Current documentation wins

Use, in order:

1. source/tests for actual implementation behavior;
2. DECISIONS.md for product/architecture intent;
3. STATUS.md and VERIFICATION.md for current evidence;
4. detailed specs;
5. archived historical notes.

Historical workstream/agent instructions are not active engineering policy.

The original Phase 0 contract is preserved at docs/archive/process/CONTRACT_PHASE0_HISTORY.md.

# Interface contracts

These documents describe intended module boundaries and public contracts. They are secondary to current runtime code and tests when an old proposal has drifted.

## Contract hierarchy

1. Current code and regression tests — what the product actually does.
2. DECISIONS.md — product/architecture intent.
3. Interface document marked CURRENT — intended public boundary.
4. PROVISIONAL interface notes — proposed change, not yet a runtime contract.
5. Historical/archive material — context only.

## Status labels

Every interface document should use one of:

- **CURRENT** — reconciled with runtime code/tests.
- **PROVISIONAL** — design proposal awaiting implementation or integration evidence.
- **HISTORICAL** — superseded; retained only for traceability.

Old Gate 0, workstream-owner and "nothing has run" wording should not be interpreted as current status unless the individual file has been refreshed.

## Design rules

- Keep public APIs small.
- Prefer typed domain boundaries.
- Keep platform/plugin dynamics behind adapters.
- Keep simulation/rating independent of presentation.
- Persistent interfaces must state version/restore behavior.
- A public interface change requires consumer regression coverage.

## Reconciliation priority

Reconcile interfaces in the same order as the active stabilization spine:

1. terrain/course authoring;
2. rating and play context;
3. save/session;
4. staff/customer/economy;
5. platform services;
6. UI shell.

Where an interface document disagrees with source today, treat that as documentation debt rather than changing working code solely to match an obsolete proposal.

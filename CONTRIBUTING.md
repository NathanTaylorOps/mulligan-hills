# Contributing to Mulligan Hills

Mulligan Hills is under active development. Contributions should protect the deterministic core, canonical course state and save integrity while keeping changes reviewable.

## Before editing

Read docs/README.md, docs/ARCHITECTURE.md, docs/DECISIONS.md, docs/STATUS.md, docs/CONTRACT.md and docs/DEFINITION_OF_DONE.md. Then inspect the current source and tests for the subsystem you are changing.

## Change philosophy

Prefer a small vertical integration slice over a broad partial rewrite. A good change has one clear authority, includes the regression that proves it, preserves save compatibility or changes it deliberately, distinguishes implementation from verification, and does not make UI/rendering the gameplay source of truth.

## Testing

Run the narrowest relevant checks first, then the broader gate. Current verification constraints and evidence rules are in docs/VERIFICATION.md.

## Documentation

Update current docs only when the current contract changes. Historical investigation logs belong under docs/archive/ rather than the main navigation path.

## Pull requests

Use the repository PR template. State what was actually run and what remains unverified.

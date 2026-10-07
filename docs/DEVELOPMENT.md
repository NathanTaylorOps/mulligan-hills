# Development guide

## Working model

1. Inspect the current branch and recent commits before editing.
2. Identify the authoritative domain for the change.
3. Reuse existing state and validation paths rather than creating a parallel model.
4. Make the smallest coherent integration change.
5. Add regression coverage with the implementation.
6. Review the diff for stale assumptions and persistence impact.
7. Record what was run versus what still needs runtime/device evidence.

Do not hard-code an evergreen document to one temporary development branch. The active integration branch may change.

## Local project

Project root:

    game/project.godot

Current engine pin:

    Godot 4.7.2

Run from the repository root on Windows PowerShell:

    godot --path ".\game"

## Verification layers

Use the appropriate level of evidence:

- static/schema checks;
- Godot import and automated tests;
- live UI probe;
- graphical desktop acceptance;
- physical Android acceptance;
- backend/store staging.

See VERIFICATION.md.

## High-risk change checklist

Before calling a foundational change complete, search for old assumptions across the repository.

Examples:

- one hole -> multiple holes;
- one pin -> rotating pin set;
- transient golfer -> persistent customer;
- local-only -> cloud-synced;
- nonpersistent -> saved state.

Tests should deliberately make entities different enough that accidental use of index 0/default state is visible.

## Repository hygiene

- Keep commits focused.
- Do not force-push shared published work as routine cleanup.
- Preserve unrelated contributor changes.
- Keep generated outputs out of source unless they are intentional fixtures/goldens.
- Put historical handovers and incident evidence under docs/archive/ or docs/verification/history/.
- Keep current product truth in the top-level docs index.
- Keep presentation demos separate from the canonical player-built course path.
- Preserve deterministic simulation, exact relief, ownership validation and save compatibility.

## CI/tooling

Pinned tooling lives in tools/ci/versions.env. CI scripts live under tools/ci/ and workflows under .github/workflows/.

Current CI/runtime status is recorded in STATUS.md, not inferred from the presence of workflow files.

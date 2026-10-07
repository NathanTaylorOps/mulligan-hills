# Mulligan Hills status

Mulligan Hills is in pre-alpha / active development. This file separates implemented, verified and planned work.

## Current vertical spine

    EDIT -> BUILD -> PLAY/PRACTICE -> SAVE/RESTORE

The course editor supports terrain sculpting, surface painting, tee/pin authoring, validation, deterministic rating and practice on authored relief. Management, customer, staff and personal-golf systems exist at varying levels of integration.

## Recent stabilization

Source-level work has corrected active-hole terrain/aiming selection, hard-coded Hole 1 labels and score selection, the regular-to-member visit mismatch, customer restore invariants, completeness in customer reactions, presentation-only golfer progression, and save reader capability downgrade behavior.

## Current blocker

GitHub Actions runs on the development branch have been failing before any job step is allocated. Observed workflow metadata showed no runner assignment and zero executed steps. Until hosted runner allocation/Actions availability is restored, current HEAD cannot be declared green.

Broad feature expansion remains behind docs/QUALITY_GATES.md.

## Implemented but not yet fully verified

- three-hole active-context regressions;
- customer/staff/economy save integration;
- current editor interaction batch;
- Android toolchain assumptions;
- backend/store integration against real staging services;
- real-device performance and touch acceptance.

## Known structural work

- real per-hole world placement rather than one development origin;
- decomposition of the oversized editor/practice panel;
- dirty/chunked rendering if profiling shows full redraw cost is material;
- formal slot identity/index contract across multi-hole systems;
- player-facing explanation of course-condition effects;
- full EDIT -> BUILD -> PLAY -> customer progression -> SAVE -> RELOAD integration coverage.

The project is not release-ready. See VERIFICATION.md for the evidence model.

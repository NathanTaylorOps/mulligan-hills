# Mulligan Hills quality gates

## Stabilization gate

Broad feature development resumes only after all of the following are true on the same exact commit:

1. GitHub Actions jobs start and produce diagnostics.
2. Godot import and automated tests pass.
3. Live UI smoke probe passes.
4. Multi-hole regression proves Holes 1/2/3 use their own relief, score, pin and active context.
5. Customer/staff/economy save round-trip passes.
6. EDIT -> BUILD -> PLAY -> customer progression -> SAVE -> RELOAD passes as a cross-system test.

## Feature gate

A substantial feature is complete only when its authoritative owner is clear, persistence impact is covered, domain rules have tests, an integration boundary is exercised, recovery/error paths are handled and any mobile performance impact is measured where relevant.

## Platform gate

Platform/service work is complete only after native/API assumptions are verified against the pinned version, timeout/failure behavior is explicit, lifecycle interruption is handled and real sandbox/staging evidence exists.

## Release-candidate gate

A release candidate requires green CI/determinism, save roundtrip, graphical acceptance, physical Android acceptance, sustained performance/thermal soak, backend staging, purchase/restore/entitlement validation, release-policy/privacy/legal completion and no open severity-0/1 defects.

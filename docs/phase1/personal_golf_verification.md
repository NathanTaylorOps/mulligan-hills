# Personal golf envelope independent verification

Date: 2026-10-05. Separate DEC-041 static specification/code/test review. No implementation edits, official rating changes or Godot execution.

## Disposition

The reported specification/range issues are resolved in the final inspected revision. No remaining concrete blocker identified for this envelope-only reference. No flight, geometry, RNG, Luck, runtime or playable-game certification is implied.

## Findings

- Corrected Recovery guarantee: case 6 now explicitly separates normalized lie spread from absolute error at a fixed reachable target. Carry-limited shots may gain absolute error as they travel farther. `lie_spread_pm` exposes the multiplier; exhaustive Recovery tests cover reachable absolute error and overreach multiplier for all three bad lies. The originally reported deep-lie example is therefore an allowed outcome, not an unresolved mismatch.
- Corrected tiny-distance edge: final available carry is now at least 1cy in specification and code; an accepted base-1/deep input is explicitly tested.
- Lie/style container values are explicitly rejected before membership operations. Invalid boolean pressure is also covered.

## Evidence and consistency

Independently reran `python3 tools/reference/personal_golf/selftest.py` after the fixes: **10 tests PASS**. Reproduced the original carry-limited Recovery example separately. Scalar/profile rejection, copied profile, Power/Accuracy/Touch/Composure checks, legal style/lie combinations and ordinary pure-repeatable output match the written formulas. Integer operation order matches the specification, including pressure and safe-recovery factors. Tests exhaust their sampled attribute ranges, not all accepted distance/lie combinations. The CI workflow now invokes this same standalone checker; remote CI success is not established by local execution. Module status accurately preserves envelope/runtime limits.

The model is accurately labelled envelope-only with provisional balance. Seven stored attributes do not imply implemented Shaping or Luck effects; there is no next random draw or settlement in this code. Fixed flight/outcome vectors, cross-platform typed port, geometry/penalties/cup capture, saved profile, meaningful styles and replay-safe rewards remain future work. Camera/visual humour authorization does not establish any related runtime implementation.

# Personal shot reference independent verification

Date: 2026-10-05. Separate DEC-041 static/reference review. No implementation edits, Godot execution or official rating changes.

## Disposition

Reported strict-input gaps are corrected in the final inspected revision. No remaining concrete blocker identified for the Python shot reference. No typed-port/runtime, persistent golfer, training, match settlement or playable-game certification is implied.

## Finding

Original feature-type and integer-valued-float failures corrected: wrapper now guards slot/elevation/type/shape/tree representation and exact integer coordinates/counts before official validation/construction. Independently inspected regressions for float tee, tree points, rectangle coordinates and tree count, plus earlier malformed feature/slot/shape cases. Official validator remains unchanged.

## Evidence and consistency

Independently ran `python3 tools/reference/personal_golf/test_shot.py`: **12 tests PASS**, including all twelve checked-in golden cases. Seeded PCG streams are independent of preview, indexed by committed shot/channel, and no shared RNG state is retained. Club search, envelope scales, floor noise, direction/rdiv, tree cutoff/backoff, water/OB stroke-and-distance and sampled putt capture follow the appended formulas. Outcome generation copies geometry/profile and returns a separate result. Existing checked cases support reproducibility, not exhaustively every geometry/start/seed combination.

Final follow-up independently ran **14 tests PASS**, retaining twelve golden cases. Inspected exact inclusive rectangle/circle ground-segment intersection added between putt samples and the zero-width hazard regression; this closes the sampling gap without changing official geometry or existing goldens. Slot/elevation/ambiguous tree-shape regressions remain reference-only evidence.

After the exact-integer guards, independently reran the same suite: **14 tests PASS**. Rectangle segment orientation uses sign comparisons rather than products of cross products; this is equivalent for the inspected intersection predicate. A later fixed-width typed port still needs its own arithmetic bounds/parity validation; Python integer success is not engine evidence.

Tested ordinary tree-backed DEEP continuation separately; no rejection found in the sampled seeds. Putt sampling and slow-finish capture are explicitly provisional. The single-shot API does not count completed-round strokes, enforce pickup/terminal state, save outcomes or settle rewards. Its simplified water policy is separately versioned rather than silently modifying official AI backtracking. Shaping/Luck, curve/roll/wind/mishit and terrain-height flight remain absent.

Golden generation is a regression oracle for a later independently checked port, not an independent proof of the generator's rules. The local rating/RNG modules are lead-reported unchanged baseline dependencies; no new official golden claim is made. CI is configured to run envelope and shot tests, but a fresh remote pass is not established by local results. Device/runtime completion and merge certification are withheld.

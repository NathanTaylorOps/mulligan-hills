# Mulligan Hills documentation

This directory separates current product truth from historical implementation notes.

## Start here

| Document | Purpose |
| --- | --- |
| [Architecture](ARCHITECTURE.md) | System boundaries, sources of authority and major data flows |
| [Decisions](DECISIONS.md) | Current product and architecture decisions |
| [Status](STATUS.md) | What exists now, what is verified and what is blocked |
| [Roadmap](ROADMAP.md) | Now / next / later development sequence |
| [Verification](VERIFICATION.md) | Evidence model and current verification state |
| [Quality gates](QUALITY_GATES.md) | Conditions required before broad feature development and release |
| [Open decisions](OPEN_DECISIONS.md) | Deliberately unresolved choices only |
| [Development](DEVELOPMENT.md) | Working practices and local/CI validation |
| [Definition of Done](DEFINITION_OF_DONE.md) | Completion criteria for code, UX, persistence and releases |
| [Visual direction](VISUAL_DIRECTION.md) | Current visual-quality and mobile-performance direction |

## Technical specifications

- docs/spec/data/ — versioned schemas, examples and validation tooling.
- docs/spec/interfaces/ — interface/design contracts.
- docs/spec/rating/ — rating and simulation specifications and reference material.
- docs/spec/ — detailed gameplay/system specifications.

## Historical material

The docs/phase1/ directory contains implementation notes from rapid development and individual files may describe an older checkpoint.

The docs/phase0/ directory is historical proof-stage material. Current verification and architecture live in the top-level documents above.

Historical handovers, old verification reports, retired scope discussions and superseded process documents belong under docs/archive/.

## Documentation rule

Every document should be treated as one of: Current, Provisional, or Historical. If a historical document conflicts with current code, tests, DECISIONS.md or STATUS.md, the current sources win.

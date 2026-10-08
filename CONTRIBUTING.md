# Contributing to Mulligan Hills

Mulligan Hills is an actively developed pre-release commercial game. Contributions should preserve the project's product decisions, deterministic simulation requirements, mobile performance goals, and documentation discipline.

## Before changing code

Read, in order:

1. `README.md`
2. `docs/CONTRACT.md`
3. `docs/DECISIONS.md`
4. the relevant document under `docs/spec/`
5. the tests for the subsystem you intend to change

A later accepted decision may supersede an older proposal or decision; confirm its status and scope in the decision register. Do not silently revive rejected or superseded designs.

## Development environment

The main project is `game/project.godot` and is pinned to Godot 4.7.2-stable (standard build, not .NET). Toolchain details live in `tools/ci/versions.env` and `docs/GODOT_VERSION.md`.

## Code standards

- Use typed GDScript.
- Use snake_case for files, variables and functions.
- Use PascalCase for classes.
- Prefix project GDScript classes with `MH`.
- Keep simulation-critical logic deterministic.
- Do not use `randf()`, unordered iteration, engine physics or floating-point-dependent result logic in deterministic core simulation without an explicit architectural decision.
- Validate data crossing save, network and platform boundaries.
- Keep platform-specific behaviour behind the existing adapters/services.
- Prefer small, testable domain objects over UI-owned game rules.

## Tests

Gameplay changes should include or update tests.

The project uses gdUnit4, with tests primarily under `game/tests/`. CI also runs independent Python reference checks and cross-platform determinism verification.

Before merging, applicable project import, unit and determinism checks should pass. Report failed or unrun checks explicitly; do not describe a change as verified without supporting evidence. Do not weaken a test merely to make a change green; fix the behaviour or document an intentional decision change.

## Product and scope changes

If a change alters player-facing rules, progression, economy, simulation behaviour, platform policy, content scope or a previously locked decision, update the appropriate specification and decision record with the implementation.

Code and documentation should not knowingly describe different games.

## Performance

Mobile is the primary target. New rendering, simulation, UI or content systems should be evaluated for their impact on lower-end Android hardware rather than judged only on a development PC.

Avoid unbounded object counts, unnecessary per-frame allocation, excessive draw calls and systems whose cost scales invisibly with course size.

## Commits

Prefer focused commits with imperative subjects, for example:

```text
feat: add cart path occupancy rules
fix: validate restored golfer associate IDs
test: cover equipment assignment cleanup
docs: record terrain elevation decision
refactor: separate golfer state from presentation
```

Avoid generic messages such as `updates`, `fix stuff` or `changes`.

## Pull requests

A pull request should explain:

- what changed;
- why it changed;
- the relevant decision/specification;
- how it was tested;
- player-facing effects;
- save compatibility implications;
- performance implications where relevant;
- screenshots/video for meaningful UI or visual changes.

Keep unrelated cleanup out of feature PRs where practical.

## Assets and third-party material

Do not add assets, code, audio, fonts, trademarks or other third-party material without confirming reuse rights and updating `docs/LICENSE_LEDGER.md` where required.

Do not commit material copied from reference games.

## Secrets

Never commit signing credentials, private keys, service-role keys, access tokens or production secrets. If a secret is committed, rotate it immediately; deleting the latest copy is not sufficient.


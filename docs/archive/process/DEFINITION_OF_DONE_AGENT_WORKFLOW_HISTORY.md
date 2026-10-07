# Definition of done, module ownership and branching rules

Owner: workstream H. Applies to every agent and to Nathan. Reason (DEC-041): agents overwrite each other, and "done" claims have been false. Nothing counts as done because an agent says so. Done means the checks below have evidence and a separate verifier agent has confirmed them.

## 1. Universal rules
1. One task, one branch, one PR. A task has a written goal, the files it may touch, and the checklist it will be judged by.
2. Evidence beats assertion. Every "done" links to: the CI run, the test list, the on-device video (where required), and the ticked checklist.
3. Honesty rule (CONTRACT.md): anything not run is written "NOT YET RUN". A PR that claims a run without a link is rejected.
4. The author never verifies their own work. A verifier agent (fresh context, sees only the task, the diff, the evidence and this document) ticks the checklist independently and records PASS or FAIL with reasons.
5. Nothing merges while CI is red. No one bypasses branch protection, including the lead.
6. Instructions for Nathan are exact, numbered, copy-paste, no assumed knowledge.

## 2. Definition of done: code
A code task is done only when ALL of these are true:
- [ ] The files touched are inside the task's owned paths (see section 6). No edits to another module's files.
- [ ] Typed GDScript, MH prefix, snake_case files, no floats in `game/core/` and sim/rating paths (CI grep check passes).
- [ ] Public API matches `docs/spec/interfaces/<module>.md`; if it does not, an interface change proposal is merged first.
- [ ] Unit tests written for new behaviour, plus a regression test for every bug fixed. gdUnit4 `test_*.gd` under `game/tests/<module>/`. All tests pass in CI (Linux and macOS jobs).
- [ ] Golden/determinism tests unchanged, or changed with an explicit note, new golden files and a bumped `sim_version`/`rating_version`.
- [ ] Data changes validate: `python3 docs/spec/data/validate.py` passes; strings pass the string checks.
- [ ] Lint/format check passes and no new warnings from the Godot script analyser in CI.
- [ ] Performance budget respected where one exists (frame time, memory, APK size), with the number in the PR.
- [ ] Reachable in the game: a feature is done only when a player can reach it from the UI. An on-device video (screen recording on the benchmark phone) shows the feature working from a cold launch, including one failure or edge case. Non-UI modules substitute a CI log of the contract tests plus the device-run evidence file when a device item exists.
- [ ] Status doc updated with what was built, tested, not run, unverified.
- [ ] PR checklist complete (section 5) and verifier agent has recorded PASS.

## 3. Definition of done: art
- [ ] Follows the written style guide: one palette, one light direction, one detail level per asset class.
- [ ] Budget met: triangle count, texture size, draw calls and file size within the asset-class budget table (proposed in the style guide, measured by the import validator script).
- [ ] Imports cleanly through the validator (naming, scale, pivots, materials, LOD levels, no missing textures) and loads in Godot in CI.
- [ ] Screenshot on the benchmark phone at both quality tiers, next to the approved concept, in the PR. Video for animated assets.
- [ ] Source files stored (Git LFS or the agreed store) and every third-party asset has a `docs/LICENSE_LEDGER.md` entry with source URL, licence, date and receipt reference.
- [ ] Nathan approval recorded for kit pieces, hero tiers (4 and 5) and golfer animation. Batched into the weekly review slot.
- [ ] Colorblind-safe check for anything that carries gameplay meaning.

## 4. Definition of done: content (text, events, audio, store copy)
- [ ] Text lives in the keyed string table with `ctx`, `max` and placeholders; length and placeholder checks pass; status `approved` by Nathan for release builds.
- [ ] Voice guide followed: plain sentences, no em dashes, no emoji, no real people or brands, no "SimGolf" terms, fictional sponsors only.
- [ ] Data-driven content (cards, commissions, regulars) validates against its schema and its effects stay inside bounds.
- [ ] Advisor and complaint text maps to rating reason codes; coverage table shows no reason code without text.
- [ ] Audio: licence ledger entry, loudness within the audio guide, loops clean, file size within budget. AI-generated audio only with a recorded plan tier and receipt.
- [ ] A 10-minute read-aloud pass done per batch and recorded.

## 5. Definition of done: a release (internal, closed test, production)
A release candidate is done only when:
- [ ] Trunk CI is green on the release commit; version and build number bumped; `git tag` created by the lead.
- [ ] Full test suite, golden files and the economy simulation targets pass.
- [ ] Device matrix run on: the benchmark phone, one iPhone (once iOS is in scope), one Android tablet: cold start, 20 minute play, 20 minute soak with fps and temperature, save kill test, upgrade-from-previous-build test, demo to unlock to restore test.
- [ ] No open S0 or S1 bugs. Any S2 has a written waiver from Nathan.
- [ ] Crash-free sessions at least 99% over the previous test round (closed test onwards); crash dashboard checked.
- [ ] Store checklist: privacy policy matches SDKs used; Data Safety and age rating answers match `analytics_catalog.json`; account deletion works in-app and via the web page; Restore button works; terms and support email live; billing library and target API meet the store's current requirements (verify at the source).
- [ ] Analytics consent respected (nothing sent before consent); remote config kill switches tested on and off.
- [ ] Rollback rehearsed: previous build can be re-promoted; staged rollout percent and the halt procedure written down.
- [ ] Licence ledger complete; open-source notices file generated.
- [ ] Signed artifact sha256 recorded in the release note; the exact commit is reproducible from CI.
- [ ] Verifier agent PASS, then Nathan's written go.

## 6. Module ownership
Every path has exactly one owner. Only the owner (or an agent working under the owner's task) edits it. Cross-module needs go through the interface docs or an interface change proposal.

| Module | Paths | Interface |
| --- | --- | --- |
| A ci | `.github/workflows/`, `tools/ci/`, `game/project.godot`, export presets template, `.gitignore`, `.gitattributes`, `docs/phase0/ci.md`, `docs/GODOT_VERSION.md` | n/a |
| B determinism, core sim, rating | `game/core/` (`sim/`, `rating/` proposed), `game/tests/core/`, `tools/reference/determinism/` | `core_sim.md`, `rating_engine.md` |
| C terrain | `game/terrain/`, `game/tests/terrain/`, `tools/reference/terrain/` | `terrain.md` |
| D render | `game/render/`, `game/bench/`, `game/tests/render/` | none (consumes snapshots) |
| E input | `game/input/`, `game/tests/input/` | gesture events to UI shell |
| F platform | `game/platform/`, `android/`, `ios/` | `platform_services.md` |
| G characters/animation | `game/characters/`, `tools/animation/`, `docs/LICENSE_LEDGER.md` | none |
| H spec | `docs/spec/`, `docs/DEFINITION_OF_DONE.md`, `docs/DECISIONS.md`, `docs/phase0/GATE0.md` | all interface docs |
| I device | `docs/phase0/device_runbook.md`, `docs/phase0/soak_protocol.md` | n/a |
| Phase 1 (proposed) | `game/economy/`, `game/buildings/`, `game/save/`, `game/ui/` (owners assigned when Phase 1 starts) | `economy.md`, `buildings.md`, `save.md`, `ui_shell.md` |

Shared files (data under `game/data/`, `docs/CONTRACT.md`) are owned by the lead; changes to data files need a PR with the schema check passing and the data owner of the consuming module as reviewer.

## 7. Branching and merge rules (many parallel agents)
1. Trunk-based: `main` is always releasable-in-principle and always green. No long-lived branches.
2. Task branches: `task/<workstream>-<short-name>`, for example `task/c-stroke-undo`. Life target under two days of work; split larger tasks. Rebase on `main` before opening the PR; if a rebase conflicts, the author resolves it, the reviewer re-checks.
3. Frozen interfaces: after Gate 0 the docs in `docs/spec/interfaces/` and `docs/spec/data/` are frozen. Changes go through the interface change proposal in `interfaces/README.md`. Before Gate 0 they are DRAFT and changes still need the owner and consumers to be named in the PR.
4. CI-gated merges: branch protection requires: tests pass on Linux and macOS, schema validation, no-float check, string-literal check, lint, and the verifier checklist status. Squash merge, one commit per task, message `<module>: <what> (task id)`.
5. Ownership check: CI fails a PR that touches paths outside the declared owner paths in the PR template (path filter in `tools/ci/`, workstream A).
6. Nobody merges their own work unreviewed. Minimum: one reviewer agent plus the verifier agent. Nathan is asked only for decisions, approvals and device tasks, batched into one weekly review slot (target 2 hours), never per PR.
7. Agents do not run git force operations; the lead commits and merges (CONTRACT.md).
8. Secrets never enter the repo (keystores, API keys, service accounts). CI secrets are stored in the CI secret store; the keystore backup procedure is in the device runbook.
9. Determinism-sensitive paths (`game/core/`, `game/terrain/` edit tools, `docs/spec/data/`) require a golden test run in the PR description.

## 8. PR template (install as `.github/pull_request_template.md`, owned by workstream A)
```
## Task
Task id / link:
Workstream (A..I or module):
Owned paths touched (list):  <!-- CI checks this -->

## What changed and why (3 lines max)

## Evidence
- CI run URL:
- Tests added or changed:
- Golden/determinism impact: none / changed (attach new goldens and version bump)
- On-device video (link) or "not applicable because ...":
- Performance numbers (fps, ms, MB) where a budget exists:
- Data validation (`validate.py`) output: pass

## Interfaces
- Public API changed? no / yes (link to interface change proposal)

## Not run / unverified (be plain)

## Checklist
- [ ] Only owned paths touched
- [ ] Typed, no floats in core paths
- [ ] Tests pass on Linux and macOS
- [ ] Docs and status doc updated
- [ ] Definition of done section for this task type ticked

## Verifier agent result: PASS / FAIL (name, date, notes)
```

## 9. Review checklist (reviewer and verifier agents)
1. Scope: does the diff do only what the task says? Any file outside the owned paths?
2. Contract: does it obey `docs/CONTRACT.md` and the interface docs (names, signatures, signals)?
3. Determinism: any float, `randf`, `Time`, `OS`, `delta`, trig call, Dictionary iteration, thread race or physics use in sim/rating/terrain edit code?
4. Errors: bad input returns an error code, never a crash, NaN, hang or partial state.
5. Data: hard limits enforced on load; every integer within +/-2^53; no unbounded loops on untrusted sizes.
6. Tests: do they fail without the change? Do they test the edge (empty, max, malformed)? Is the golden file untouched or intentionally updated?
7. Reachability: can a player reach it in the UI? Is there video proof?
8. Performance: any per-frame allocation or per-touch mesh rebuild? Budget respected?
9. Security and privacy: no secrets, no PII in logs or analytics, no entitlement in saves, no client-trusted scores.
10. Strings: no literal user text in scenes or code; keys exist.
11. Licences: every third-party asset or plugin has a ledger entry.
12. Honesty: "NOT YET RUN" used where true; unverified assumptions listed.

## 10. Bug triage severities
| Sev | Meaning | Examples | Response target | Release rule |
| --- | --- | --- | --- | --- |
| S0 | Data loss, crash on launch or loop, purchase broken (unlock not granted, double charge), security or privacy breach, determinism break that changes saved scores | Save corrupted after kill; unlock not restored; analytics sent without consent | Stop other work; fix within 24 hours; hotfix path; use kill switch if live | Blocks any release; if live, halt rollout |
| S1 | Core loop broken or badly degraded, no workaround: cannot build, place, rate or upgrade; frame rate under budget on the benchmark phone; wrong gate math; wrong economy result | Terrain stroke lost on undo; tier gate accepts unmet requirement; fps 15 on soak | Fix within 3 days | Blocks release |
| S2 | Feature wrong with a workaround, visual defects that hurt readability, rare crash with no data loss | Heatmap legend wrong; toast shows wrong text; colourblind palette unreadable on one screen | Fix within the current milestone | Release needs Nathan's written waiver |
| S3 | Cosmetic, minor polish, typos | Slight misalignment; low-value animation glitch | Backlog, batch fix | Does not block |
Triage rules: severity is set by the verifier agent or the lead, not the author; a bug that reproduces on the benchmark phone but not in the editor is judged on the phone; every S0 and S1 fix ships with a regression test; every bug report includes build sha, device, steps and the save (with player consent) when relevant.

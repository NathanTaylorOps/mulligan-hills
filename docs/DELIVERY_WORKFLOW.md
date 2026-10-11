# Delivery workflow

Mulligan Hills uses GitHub as the **live work record**, with version-controlled specifications as the **durable technical reference**. This document describes the intended workflow for new work. Historic plans, branch discussions and decisions remain important evidence; they should not be silently discarded or rewritten.

## Where information belongs

| Record | Purpose | Minimum content |
| --- | --- | --- |
| Epic issue | Why an outcome matters and how completion will be judged | Product goal, audience, scope, non-goals, linked feature issues and measurable outcome |
| Feature issue | One capability a player can observe or use | Player-facing behaviour, supported input methods, acceptance criteria, dependencies and validation |
| Task issue | A concrete step that delivers an approved feature | Implementation scope, affected interfaces, validation plan, done criteria |
| Defect issue | A reproducible gap between expected and observed behaviour | Environment/build, repro steps, expected/actual result, severity, evidence and regression test |
| Pull request | A review of **how** scoped work was implemented | Linked issue, focused diff, test evidence, impact, risks and follow-ups |
| Decision register / specs | Durable rules and rationale | Accepted design, constraints, contracts, decision supersession and technical reference |
| Release | Verifiable delivery record | Version, commit, artifacts, required checks, completed issues/PRs and known limitations |

A feature should have **one player-observable capability**; if it describes multiple distinct actions or an internal subsystem, split the feature. Put required substrate work in technical tasks. Do not invent tasks to satisfy a hierarchy: small features may have no child tasks.

## From proposal to completion

1. **Define the outcome.** Review existing issues, active PRs, specifications, `docs/DECISIONS.md`, and code before filing new work. Avoid duplicates and assumptions about implementation status.
2. **Write the issue.** Explain who experiences the outcome, what they can do or perceive, constraints, acceptance criteria and how to demonstrate success. Connect dependencies and relevant DEC IDs.
3. **Plan the implementation.** Identify affected interfaces, save/data migration, simulation determinism, platform requirements, accessibility, licensing and performance implications. Only create task issues when helpful.
4. **Implement on a scoped branch.** Keep reviewable commits; coordinate shared-file edits. Changes with materially distinct player outcomes should normally use separate PRs.
5. **Review against evidence.** Link the issue using closing syntax only when the PR fulfills its acceptance criteria. Report tests as passed, failed, not run or not applicable. An automated green build does not imply device verification.
6. **Verify integrated behaviour.** Confirm the path from the normal game entry point. For mobile-relevant functionality, record target device, OS, build, input, performance and observed result. Include screenshots or gameplay video for meaningful UX/visual claims.
7. **Merge and record.** Merge after required review and checks. Update issues with actual status, decisions and known follow-ups. Do not call unfinished or untested work shipped.
8. **Release deliberately.** Link a version to a specific commit, artifact and validation record; summarise delivered capabilities, fixes and known limitations. Do not publish a release simply because a milestone is named.

## Status vocabulary

Status should describe evidence, not optimism:

- **Planned** — defined, not implemented.
- **In implementation** — code or assets are being developed.
- **Implementation complete** — scoped change exists; integration/verification may be missing.
- **Automated verified** — specified tests pass on a named commit; not proof of live playability.
- **Integrated verified** — player reaches and uses the capability through the normal game flow, with evidence.
- **Device verified** — verified on named target hardware/build; only for actually tested platforms.
- **Released** — included in an identified distributable build with traceable release evidence.
- **Blocked** — a named dependency or failure prevents the next verification gate.

Do not use a universal "done" label as a substitute for these distinctions. Statuses should be represented using existing GitHub issue/project facilities when available; this document does not claim those facilities have already been configured.

## Pull request review

Use `.github/PULL_REQUEST_TEMPLATE.md` and `docs/DEFINITION_OF_DONE.md`. Every substantive PR should make it easy for a reviewer to answer:

- Which issue and player outcome does this change address?
- Is the diff reasonably scoped, and does it conflict with other active branches?
- What actually ran (commands, CI links, commit hash, device/build), and what remains untested?
- Are save migration, determinism, security, platform integration and low-end Android performance addressed where relevant?
- Does changed gameplay work in the integrated game, not just a test scene?
- Are visual examples authentic in-engine captures rather than unattested concept renders?
- What risks, regressions, deferred work or exceptions remain?

The issue contains evolving product discussion; PR review focuses on the change and its evidence. Record material feedback in the relevant GitHub thread, then update the authoritative design/decision document if the accepted behaviour changes.

## Existing work and migration

Do **not** close or rewrite the existing open PRs purely to fit this process. First reconcile PRs #1–#5 with main, identify changes already implemented and mark conflicting dependencies. See #11 and its linked workstreams #12–#15. Use the findings to establish a nonduplicative player-capability backlog.

This process does not supersede `docs/CONTRACT.md`, `docs/DECISIONS.md`, `docs/DEFINITION_OF_DONE.md`, `CONTRIBUTING.md`, or `docs/spec/`. Where they disagree, create an explicit review item rather than silently choosing whichever text is newer.

## First integrated playable gate (proposed)

The first playable milestone is not complete until a tester can use the normal launcher to enter the game, shape/build a playable golf hole, exercise at least one meaningful club-operation interaction, play or observe a verified shot/round, save, exit, reload and recover the authored state. Record critical usability defects and the save/reload behaviour. Android readiness additionally requires real-device testing and representative performance evidence; desktop success alone does not establish it.

This is an **acceptance goal**, not a statement that the milestone has passed.

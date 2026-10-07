# Definition of Done

"Done" means the relevant behavior is implemented, integrated and evidenced. The checklist is intentionally stricter for persistent, mobile or platform-facing changes.

## Code/domain change

- [ ] Ownership and dependency direction remain clear.
- [ ] Invalid inputs and boundary cases are handled.
- [ ] Domain behavior has automated regression coverage.
- [ ] No presentation-only state becomes gameplay authority.
- [ ] Static/type/import issues are resolved.
- [ ] Relevant automated suite passes on the exact commit.

## Persistent-state change

- [ ] Schema or accepted shape is updated where required.
- [ ] Serialization and restore agree.
- [ ] Reader/migration behavior is explicit.
- [ ] Impossible states are rejected.
- [ ] Round-trip regression exists.
- [ ] Older supported saves remain covered.

## UI/editor change

- [ ] Touch and desktop interaction do not conflict.
- [ ] Cancel/undo/recovery behavior is defined.
- [ ] Empty/error/blocked states are understandable.
- [ ] No stale hard-coded single-hole assumptions remain.
- [ ] Graphical behavior is checked, not inferred from headless tests.
- [ ] Physical-device touch acceptance is performed when the change materially affects mobile interaction.

## Rendering/performance change

- [ ] Gameplay result is independent of graphics tier.
- [ ] Cost is measured on representative hardware where material.
- [ ] Sustained behavior is checked for expensive/editor-heavy changes.
- [ ] Visual fallback/quality tiers remain coherent.

## Platform/backend change

- [ ] Version/API assumptions are verified.
- [ ] Timeout, retry and failure behavior are explicit.
- [ ] Lifecycle interruption is handled.
- [ ] Real sandbox/staging integration has evidence.
- [ ] Offline/reconnect path is covered where relevant.
- [ ] Secrets are never committed.

## Product/content change

- [ ] Current decision/scope classification is clear.
- [ ] Copy does not claim unimplemented behavior.
- [ ] Third-party/IP provenance is known.
- [ ] Any release-sensitive legal/store review remains clearly separated from engineering verification.

## Release candidate

- [ ] Quality gates pass.
- [ ] No open severity-0/1 defects.
- [ ] Save/recovery path verified.
- [ ] Android physical-device acceptance complete.
- [ ] Backend/store staging complete.
- [ ] Release policy/privacy/legal checks complete.
- [ ] Build/version/commit are recorded.

Evidence may be CI artifacts, exact-SHA logs, device results or staging records. A written claim without evidence is not a verification result.

The original Phase 0/agent-workflow version is preserved under docs/archive/process/.

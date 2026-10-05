# One-hole prototype independent verification

Date: 2026-10-05. Separate verifier under DEC-041 and `docs/DEFINITION_OF_DONE.md`. Static review of the current uncommitted primitive course/save/practice increment; no implementation edits or Godot execution.

## Disposition

No remaining concrete blocker identified in the inspected narrow increment after the corrections below. Completion/merge certification is withheld: Godot analyser, gdUnit4 CI and device evidence are absent.

## Corrected findings inspected

- S1: finalization now marks the primitive course reader 3 before capture validates its source. The actual scene finalization/save/restore regression checks this boundary and preserved cash/practice state.
- S2: course version, slot and world numeric values are checked before conversion; parcels must form complete nonoverlapping world coverage. Exact yard/dm conversion and owned-land geometry checks precede purchase.
- S2: the development scene checks the panel's supported layout profile before setup. Other valid shapes/origins are refused without overwriting their saved geometry.
- S2: practice restoration accepts the official tree interception/backoff deep lie. The serialized practice record has twelve fields and checks geometry hash, scalar types and basic terminal state.
- S2: finalize, restart and shoot refuse modal execution. Opening practice cancels world input and the world predicate suppresses terrain gestures while the panel is visible.
- Test collection assertions now use array/dictionary assertions rather than object assertions.

## Final malformed-data corrections

- S2 corrected: `MHSessionSave.restore` now checks `runtime.practice.slot_id` with `is_int_value` before conversion; malformed identity is refused.
- S2 corrected: the practice branch in `MHSaveGame._validate_runtime` now checks the reader's integer type before conversion using short-circuit evaluation. Both corrections independently inspected; runtime regression execution remains pending.

## Evidence and limits

Independently ran `python3 docs/spec/data/validate.py`: exit 0, **RESULT: ALL PASS**. This checks schema/catalogue fixtures and existing negative cases, not GDScript execution. Inspected new geometry, seeded flight/next-shot, putting, malformed practice, unsupported profile and scene checkpoint tests; these remain **NOT YET RUN** in Godot.

Submission validates and rates before charging. Capture checks the document/session geometry equality and performs a full restoration check before the existing world/blob save path. Restore creates a separate session, restores official ratings without a new charge/reward and retains the separate content-addressed ledger policy. Disk-write failure may retain changed in-memory gameplay while preserving the previous committed checkpoint; this review does not establish power-loss durability.

Scope is an exact flat short-par-3 development prototype with aim controls and automatic flight. It is not finished phone interaction, a golfer avatar/career, XP/rewards/stakes, played tournaments, arbitrary hole authoring or legacy polygon conversion. No timing bar/swipe control or full playable-game certification is implied. Minor state validation does not prove that every accepted practice history was reachable; player results do not award anything or affect official ratings in this increment.

Final draft-preview delta inspected: design changes redraw the draft; shoot refuses while a draft is displayed; successful finalization clears preview and starts a round on the committed geometry. No additional concrete blocker found. Draft preview is transient and is not itself a saved finalized hole. Independently reran the schema validator after adding `one_hole_save.example.json` and its reader/version/skill/ambiguous-shape negative cases: **ALL PASS**. Inspected `one_hole.md` and the controls research scope language: both distinguish the aim/automatic-shot prototype from the unimplemented golfer career and proposed controls. Research-source accuracy was not independently re-browsed in this code review. No runtime certification added.

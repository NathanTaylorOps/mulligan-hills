# Live construction: independent static verification

Verifier: separate agent `/root/verify_session`, 5 October 2026. Reviewed the uncommitted session checkpoint, live construction scene/sink, reader-2 schema/runtime validation, adapter history queries, router gating, shell regions, loan-result correction and integration tests against existing APIs, then independently inspected the fixes below. No implementation files edited.

## Disposition: static findings corrected; completion not certified

No unresolved concrete implementation blocker found in the revised zero-finalized-hole scope. Original findings and independently inspected corrections:

1. **S1 corrected, exact terrain/accounting snapshot pairing.** Height-only FNV pairing could combine old JSON with new paint. Reader-2 runtime now carries `terrain_bytes_hash`, defined explicitly as SHA256 of lowercase hexadecimal text of the entire encoded blob. The store fills this from the actual saved bytes, checks it when choosing blob candidates and importing, and preserves legacy height-only matching for documents without runtime. The new paint-only regression injects AFTER_BLOB_WRITTEN, confirms unchanged height hash but changed full digest, then requires recovery of the previous exact blob/timestamp. NOT YET RUN in Godot.
2. **S2 corrected, malformed capture input.** Capture normalizes/validates the source and calls `_live_shape` before accessing nested club/course/world/sim/progress values. The new malformed-source regression checks wrong top-level shapes and an empty course world. NOT YET RUN in Godot.
3. **S2 corrected, redundant world state.** Restore compares official world day/minute with the restored clock and every supplied parcel ownership flag with land state. The inconsistency regression now includes world minute and parcel-ownership mutations. NOT YET RUN in Godot.
4. **S2 corrected, stale router pointer state.** `cancel_world_input()` clears mouse mode, UI mouse region and touch cache before cancelling the gesture machine. Blocked predicates/input, focus notifications and live-scene suppression invoke it. The regression checks a rotate press followed by a blocked release and checks both caches and predicate suppression. NOT YET RUN in Godot.

## Reviewed strengths and API checks

- A restored session is constructed separately and accepted only after validation/checksum, ledger generation equality and accounting checks; no running session is partly replaced on refusal.
- Ledger generations are written separately before the world save, addressed by canonical-content SHA256 and retained for older checkpoints. This protects the old ledger/world pair against a failed later write, subject to the terrain-pairing finding above. Power-loss/fsync durability and account-wide reward rollback are not established.
- Fractional cents, economy debt/member/carry state, clock remainder/prepaid credit, tiers, land and bridge progress are represented in the optional runtime block. Finalized-hole saves are explicitly refused rather than silently erased.
- Loan success now checks a nonnegative lent amount, matching `take_bank_loan()`'s amount-or-negative-error contract.
- Inspected terrain editor/sink, dirty chunk flush, camera, picking, history counts, SaveResult/Store and ledger APIs match their existing signatures. No concrete typed API mismatch identified; this is not a Godot analyser result.
- Hidden overlay regions are excluded; the editor history adapter disallows undo/redo during an open stroke. Scene input is gated to the editor with no modal. Runtime checks are still required for event ordering, modal transitions and raw touch/desktop handling.

## Evidence and scope limits

Verifier independently ran `python3 docs/spec/data/validate.py`: exit 0, **RESULT: ALL PASS**, including the reader-2 fixture and negative reader/loan/pause/cents/speed/ledger-hash cases. This validates the JSON Schema/catalogues, not GDScript execution or actual torn-file recovery. New digest API documentation checking was performed by the lead; this verifier inspected the explicit algorithm and its use, but did not independently browse API documentation.

Final additions independently inspected: the live-scene smoke test isolates both store and ledger directories, adds the real scene to the tree, routes pause/editor history/purchase intents, paints through the live sink, saves through `save_now`, restores the resulting session and decodes its terrain to compare paint. Its existing typed methods match the inspected APIs. It remains NOT YET RUN and does not prove raw touch, rendering, a second scene cold launch or finalized-hole conversion. Restore now rejects a nonzero paid ledger, consistent with DEC-064. The status document accurately distinguishes this ground/accounting increment from finished holes, golfer gameplay, production identities and device layout; no new scope/typing blocker identified in those final additions.

Godot import/analyser, gdUnit4 Linux/macOS, save-kill/torn-write tests and device interaction are **NOT YET RUN** for this revision. No runtime PASS is claimed. This is an isolated zero-finalized-hole terrain/accounting integration scene, not a completed golfer game or a complete polygon/dm-to-RHI hole editor. Staffing/pace, personal golf/career, finalized holes, production save migration and full gameplay reachability remain unfinished. DEC-041/Definition of Done completion and merge certification are withheld.

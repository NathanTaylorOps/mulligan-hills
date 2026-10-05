# CI pacing assertion recovery: independent verification

Date: 2026-10-05. Separate DEC-041 review of the two test changes and determinism workflow trigger expansion. No production edits or local Godot execution.

No concrete blocker identified. The speed test now checks the existing locked 25-minute-day whole-token quotes (13 for one accelerated day, 25 for two), accepts one day with balance 15 and rejects two, retaining the no-spend/cash assertions. These match `speed_tokens_for_days`'s ceiling division of 1500000000 microseconds by 120000000 per token.

The autosave test explicitly asserts the locked 1500000000-microsecond day and steps 1500 one-second slices, below the clock's suspension threshold. That reaches exactly 660 game minutes. The existing policy counts its initial hour-zero save and hours 1 through 11, giving twelve saves. This does not establish every autosave event/store lifecycle or resource cleanup.

Determinism push paths now include all `game/tests/**` and `tools/reference/**`, retaining existing core/CI/workflow paths and branch exclusion. Main CI, APK and screenshots already trigger on pushes without equivalent path restrictions; the expanded paths therefore request the fourth workflow for these test/reference changes. Documentation-only determinism filtering remains intentional.

Lead-reported predecessor evidence at a1d0037: 984 tests, zero errors, two failed assertions; APK/screenshots succeeded. This verifier did not independently retrieve those logs or certify that remote results. `ci_recovery.md` correctly treats the assertion fixes as awaiting new CI, missing determinism as unverified and reported orphan resources as a separate unresolved concern. Local parser/diff PASS is lead evidence only. No green-suite, lifecycle-cleanliness, device, merge or completed-game certification is claimed.

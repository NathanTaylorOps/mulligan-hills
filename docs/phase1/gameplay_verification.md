# Foundation static verification

Verifier: separate agent `/root/verify_session`, 5 October 2026. Read DEC-041, `docs/DEFINITION_OF_DONE.md`, `docs/CONTRACT.md`, and the lead handover. Reviewed the session, live adapter, gameplay tests, and the additive mandatory-loss API with its Python mirror. No implementation files edited by this verifier.

## Disposition

Static review only; completion certification withheld. Godot import, analyser, gdUnit4 Linux/macOS tests, determinism CI and device evidence are **NOT YET RUN** for this foundation revision. Queued repair workflows are not evidence for the new foundation files. A third-party parser does not establish Godot typing correctness.

No unresolved concrete implementation blocker was found within the reviewed foundation scope after the revisions below. This is a static-review disposition only and does not satisfy the Definition of Done.

## Independently reviewed corrections

- Original S1 dead-hole gate bug: rounded score 25 could count official `score_pm=249, dead=true` toward gates. Revised eligibility uses the official dead flag; a 249/250 regression is present. Test execution remains NOT YET RUN.
- Original S1 mandatory-loss bug: any unpaid tournament loss immediately set bankruptcy, bypassing minimum-arrears/upkeep-duration policy. Revised settlement calls `MHEconomy.incur_loss`, which preserves unpaid debt and invokes the existing policy. Negative amounts reject before mutation. Python mirror matches; verifier independently ran `python3 tools/reference/economy/selftest.py`, which printed `economy selftest OK`. GDScript regressions remain NOT YET RUN.
- Existing course slots cannot be removed or substituted. The new successful official-course test checks cost, adapter results, result-copy isolation and rejected slot substitution. NOT YET RUN.
- Factory initialization explicitly checks `MHRParams.ensure_loaded()` before course rollup can access parameter tables. This matches the existing boolean API.
- The guessed reputation achievement conversion was removed. Its unresolved scale is now explicitly deferred instead of silently making an existing threshold unreachable.
- S2 recognized-intent routing bug corrected: `tournament_host` now initializes a handled refusal with reason `recovery` before checking bankruptcy. The verifier inspected the corrected branch and `test_recognized_rejected_intent_does_not_fall_through`, which also checks that an unknown intent remains unhandled. Test execution is NOT YET RUN.
- No concrete typed API signature mismatch was found in the reviewed foundation paths. This is static inspection, not an analyser result.

## Explicit integration gaps

The foundation is not a playable or shippable loop. Remaining work includes UI/3D-editor reachability; terrain/save geometry conversion to RHI; validated save/autosave wiring and kill/rollback tests; account-wide reward persistence; authoritative staffing and pace; reputation achievement scale; balanced-hole axis semantics; completed-round statistics; tutorial completion signals; and later commission/card integration. Tournament entry remains blocked by zero staffing/pace rather than invented eligibility. Daily and tournament integration regressions still require implementation and execution before an end-to-end completion claim.

DEC-041/Definition of Done PASS is not granted. CI evidence, required golden checks, and applicable device evidence must be reviewed independently before merge or completion certification.

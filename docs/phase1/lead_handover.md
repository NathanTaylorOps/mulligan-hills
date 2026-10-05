# Temporary lead handover (5 October 2026)

## Purpose and scope
Repair phase1 CI, verify the DEC-069 economy, and connect the existing modules into a live loop. Nathan authorises work directly on phase1; main is untouched until all four workflows pass and independent verification is complete. No spending, new accounts, or public publishing is authorised.

## Verified baseline
phase1 ff0125be3173585721f193302e83e16c349d9330: import passed; 940 test cases executed, nine failing cases / 15 assertion failures. Determinism, screenshots/bench, and Android export passed. Main c9f6799 remains green.

## First repair
Updated stale start-cash and tournament-money assertions to DEC-065/069. Updated the gallery affordability expectation (its sample Clubhouse costs more than sample cash). Tested achievement filtering on an explicit mixed-category input rather than obsolete sample catalogue counts. The daily board retains attempts, so two attempts produce two rows while completion and streak remain once per day. A finished tournament record remains until acknowledged, as MHTournamentState documents; the bridge test now verifies both stages.

No shipping rules or rating goldens changed in this repair. Python economy selftest passes. GDScript repair NOT YET RUN until the next CI run.

Repair pushed as c72ce1c. All three triggered jobs remained queued with no runner assigned; determinism was not triggered by test-only paths. The next economy/core change triggers all four workflows. Do not infer green from queued jobs.

## Current checkpoint

Economy audit/renovation correction pushed as f029fcf. Full simulation re-run, Python self-check and schema validation pass. Goldens retain identical numerical content. `docs/phase1/economy_audit.md` records the historical failed earned-token hours assumption. The 12-minute proposal was withdrawn before implementation; Nathan subsequently approved DEC-070/071: 25-minute days and about 50 running hours.

Live session and adapter foundation is in `docs/phase1/gameplay.md`. It coordinates clock hours, cash, purchases, official ratings, daily submissions and tournament settlement, but scene/editor and validated autosave wiring remain unfinished. Independent static review found two S1 bugs, corrected with tests; reputation achievement scale is explicitly deferred rather than using a guessed conversion. No end-to-end completion or device sign-off claimed.

## Next work and risks
- Economy re-run complete: median 49.6 normal-speed running hours; 92.6% of non-novice modelled players finish by day 150. Pauses/design time and real staffing gates remain outside the model. Demo building progression is extremely short.
- Build the live adapter and loop, hourly income/autosave, purchases and daily tournament/progression updates.
- Money boundary: economy cents; UI, tournament and save cash whole dollars. Preserve fractional cents in an optional validated economy save block.
- No real staff source currently exists; do not manufacture staff to bypass tournament gates.
- Existing status documents contain stale NOT YET RUN claims and obsolete open questions; use CI evidence and newest locked decisions.

## For Nathan
Device checks remain unrun: install a green Android debug APK; run Sim hash first, then Benchmark Quick 60s. Low-end phone purchase, Supabase setup and official trademark search remain Nathan's tasks.

## Approved pacing checkpoint

DEC-070/071, clock compatibility, Python/Godot regressions and editor pause control are updated. Python checks pass; Godot CI remains pending. Research proposals in `activities_research.md` are not implemented or automatically added to frozen v1. `pacing_verification.md` records separate review with completion certification withheld.

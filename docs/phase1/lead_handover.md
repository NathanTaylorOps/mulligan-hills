# Temporary lead handover (5 October 2026)

## Purpose and scope
Repair phase1 CI, verify the DEC-069 economy, and connect the existing modules into a live loop. Nathan authorises work directly on phase1; main is untouched until all four workflows pass and independent verification is complete. No spending, new accounts, or public publishing is authorised.

## Verified baseline
phase1 ff0125be3173585721f193302e83e16c349d9330: import passed; 940 test cases executed, nine failing cases / 15 assertion failures. Determinism, screenshots/bench, and Android export passed. Main c9f6799 remains green.

## First repair
Updated stale start-cash and tournament-money assertions to DEC-065/069. Updated the gallery affordability expectation (its sample Clubhouse costs more than sample cash). Tested achievement filtering on an explicit mixed-category input rather than obsolete sample catalogue counts. The daily board retains attempts, so two attempts produce two rows while completion and streak remain once per day. A finished tournament record remains until acknowledged, as MHTournamentState documents; the bridge test now verifies both stages.

No shipping rules or rating goldens changed in this repair. Python economy selftest passes. GDScript repair NOT YET RUN until the next CI run.

## Next work and risks
- Re-run the economy; the saved report's 12.1 minute/day timing assumes speed-ups without respecting an earned-token budget. Demo building progression is extremely short.
- Build the live adapter and loop, hourly income/autosave, purchases and daily tournament/progression updates.
- Money boundary: economy cents; UI, tournament and save cash whole dollars. Preserve fractional cents in an optional validated economy save block.
- No real staff source currently exists; do not manufacture staff to bypass tournament gates.
- Existing status documents contain stale NOT YET RUN claims and obsolete open questions; use CI evidence and newest locked decisions.

## For Nathan
Device checks remain unrun: install a green Android debug APK; run Sim hash first, then Benchmark Quick 60s. Low-end phone purchase, Supabase setup and official trademark search remain Nathan's tasks.

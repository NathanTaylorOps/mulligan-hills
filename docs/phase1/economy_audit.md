# Economy audit: 5 October 2026

## Verdict

DEC-069's game-day target passes the assumed player model. The 20–30 real-hour target is NOT verified with earned-only speed-ups and fails for most modelled competent players at normal speed. Do not describe the rebalance as finished or tune locked prices without Nathan approving a new decision.

Re-ran `python3 sim.py all 60` after correcting the renovation gate to the locked tier-5 requirement. Output is `tools/reference/economy/sim_report.txt`. Sixty players per skill profile, twenty per non-default weighted habit cell, 400 game days. Weighted competent population excludes novice; results depend on assumed skill growth, purchase behaviour and tournament eligibility. They are simulations, not measured retention.

## Findings

- 84.7% of the competent population finishes in days 100–150; 92.6% by day 150.
- At 1x, only 40.2% finishes inside 20–30 hours. The full-population figure is 34.2%.
- The assumed 60% 1x / 25% 2x / 15% 4x mix gives 82.1% of competent players inside 20–30 hours, but consumes 3 tokens/game day: 300–450 tokens over 100–150 days. The bot's 12 initial tokens plus two/week are not connected to clock drain. Actual rewards are two/real-day login, three/challenge completion and one/achievement, not free speed-ups.
- Reported hours exclude editing time and pauses; the skill curve grows with game days rather than design actions. The model assumes staff and pace gates are satisfied. These remain material limitations even after timing is corrected.
- At $50,000 starting cash the bot buys all seven demo building steps on day 2. This does not measure the fun or duration of designing nine holes. A demo-specific cash reduction would be a new decision, not an authorised silent change.
- One sped-up day costs 7.5 tokens at 2x/4x/8x. Time saved is 7.5/11.25/13.125 minutes respectively; the old report incorrectly said 15 minutes for all speeds.

## Corrections made

The report now shows actual 20–30-hour shares at 1x alongside the explicitly unfunded speed-mix sensitivity, and quantifies token demand. Renovations now require every building at tier 5, exactly as DEC-069 says; the interrupted implementation and its test had tier 4. Python and GDScript regressions cover that boundary. Regenerated economy goldens are numerically unchanged.

Runtime economy params now have a generated identical copy in `docs/spec/data/economy_params.json`; `gen_golden.py` writes both, and `validate.py` checks their equality. All pre-existing catalogue/spec copies still match.

## Proposed decision for Nathan (NOT locked)

Proposed DEC-070: reduce the normal-speed game day from 15 real minutes to 12, keeping 660 game minutes and the DEC-069 prices. This makes days 100–150 exactly 20–30 hours of running time, without needing speed tokens. In this assumed population, the corresponding completion share is 84.7%. It changes DEC-052, so Nathan must approve it before code or locked decisions change. Editing/pauses still need playtesting, and a funded token-clock model remains necessary.

Alternative: retain the 15-minute day and accept 25–37.5 running hours for days 100–150. That changes DEC-066's hours target instead. Rebalancing prices to finish earlier also changes DEC-069 and requires a separately simulated proposal.

## Validation

Python economy selftest: PASS. Full simulation: completed. JSON schema/catalogue validation: ALL PASS. Regenerated golden numerical equality: PASS. Godot is unavailable locally; GitHub import/tests are the authority. No main merge or device sign-off claimed.

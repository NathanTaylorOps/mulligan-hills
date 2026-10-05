# Live gameplay coordinator

Status (5 October 2026): foundation implemented; NOT a finished playable game. Godot execution is CI-only. Static GDScript parsing passes; schema validation and Python economy self-check pass. Independent static review found dead-hole rounding and premature bankruptcy bugs; both corrected with regressions. CI evidence pending.

## Ownership and interfaces

`game/core/gameplay/mh_game_session.gd` owns the clock, economy, land, earned-token ledger, progression bridge, official rating results and 14 daily course-score samples. `game/ui/adapters/mh_live_game_state_view.gd` implements the existing read-only UI contract. Cash/income/upkeep are whole dollars converted from integer cents; scores stay in tenths/permille where the contract requires them. No sample numbers or paid-token products.

`advance(delta_us, unix_now)` consumes every clock hour exactly once, then requests autosave only after accounting reaches the final clock position. Multiple clock events coalesce to one consistent save request; the new suspension cap advances at most 52.8 game minutes. Daily login uses UTC days; income and score-history samples use game days. Pausing stops accounting. `handle_intent` rechecks price, gates, demo restrictions and affordability; forged button prices cannot change the charge. Land purchase is checked before money or ownership changes. Course submission validates RHI, slot uniqueness, parcel/demo caps and the tournament lock before rating or spending; existing slots cannot be demolished. Dead eligibility comes from the unrounded official rating, not its rounded display score.

Daily submission rates the actual RHI hole with the daily seed before consuming an attempt and grants completion/achievement tokens idempotently. Tournament settlement uses the existing deterministic evaluator and normal mandatory-loss/bankruptcy policy. Finished events remain until acknowledged. `MHEconomy.incur_loss(cents)` is additive and mirrored in Python; it carries an unaffordable mandatory loss into debt without inventing a second bankruptcy threshold.

## Remaining integration work

- Wire a playable 3D course/editor scene and MHUIShell to the session; gallery is still a gallery. No launcher game entry added yet.
- Connect hourly autosave to a validated slot document, preserve fractional cents/accounting state, and keep the token ledger/prepaid clock credit outside importable save slots. There is deliberately no unvalidated checkpoint workaround.
- Translate dm/polygon course saves and terrain edits into RHI geometry. They are different formats and must not be passed straight into the rating engine.
- Define real staffing and pace eligibility sources. Current staff and pace are zero, so tournament entry remains blocked. Never manufacture values to bypass the gates. Propose a product decision before adding recruitment/wages or a pace formula.
- `golfers_finished` requires actual completed rounds, not economy arrivals. `best_axis` needs its intended balanced-hole definition clarified. Tutorial completion needs the shell completion signal. Commission/card stats remain owned by those later modules.
- Reputation achievement scale is unresolved: the economy uses a 0..1000 demand multiplier starting at 1000, while the catalogue's great_name threshold is 500. Dividing by ten makes that achievement unreachable; using the raw multiplier grants it at startup. The session does not feed reputation achievements until the intended progression quantity is defined.
- Account-wide reward claims and save rollback need a persistence audit before shipping daily/achievement token rewards.

## Tests and evidence

`game/tests/gameplay/test_game_session.gd` covers live money conversion, exact hour/day accounting, pause, once-per-UTC-day login, forged land prices, unaffordable land atomicity, rejected tier gates, invalid and successful official course submissions, slot persistence, the dead-hole 249/250 boundary and small mandatory-loss debt. These are NOT YET RUN in Godot. Additional daily/tournament and save-kill regressions are required before claiming end-to-end completion.

No new engine APIs beyond repository-proven signals, RefCounted and collection operations. The third-party parser does not verify Godot 4.7.2 typing; GitHub import/tests remain authoritative. Phone checks are still required under DEC-041.

## DEC-070/071 pacing update

Normal-speed day: 25 real minutes; income still arrives on each game hour. Paused accounting remains stopped. The editor toolbar exposes the existing pause/resume intent, and regression tests cover toolbar toggling and successful course submission while paused. These tests await Godot CI; actual playable scene/editor/save wiring remains open. Target: about 50 running hours, excluding paused design work.

# DEC-070/071 independent pacing review

Verifier: separate agent `/root/verify_session`, 5 October 2026. Scope: current uncommitted pacing diff, clock/tests, clock snapshot conversion, economy token estimates and Python mirror/golden, gameplay boundary regressions, editor pause intent, and the completed regenerated report/audit and research scope. Implementation files were not edited by this verifier. The campaign report was excluded while incomplete, then reviewed after the lead confirmed regeneration finished.

## Disposition

No concrete correctness blocker found in the reviewed pacing delta. This is **static review plus the Python checks below**, not completion certification. Godot import/analyser, gdUnit4 on Linux/macOS, CI golden checks and device validation are **NOT YET RUN** for this revision. The earlier live-scene/save-wiring gaps remain open.

## Checks executed independently

- `python3 tools/reference/clock/check_clock_vectors.py`: exit 0; `clock boundary vectors OK (13 scenarios + legacy fraction)`.
- `python3 tools/reference/economy/selftest.py`: exit 0; `economy selftest OK`.
- Parsed the old/new economy golden JSON: only `speed_tokens` changes semantically. New days 0..12 values are `0,13,25,38,50,63,75,88,100,113,125,138,150`, matching ceiling of 12.5 tokens per boosted day. Economy scenarios and rating/simulation goldens were not changed by the reviewed pacing delta.
- Parsed the old/new three economy parameter JSON copies: each is semantically unchanged; their diffs reorder object keys only. Locked DEC-069 prices were not retuned.

## Static findings

- Clock duration is 1,500,000,000 real microseconds per 660 game minutes: 25 real minutes at 1x and 26.4 game seconds per real second. Integer accumulation preserves slicing equivalence. Hour and day event generation/order is unchanged; updated expected boundaries match the new denominator.
- A 120-second suspension adds 52.8 game minutes, at most 53 crossed minute boundaries including an existing remainder. Suspension remains capped, at 1x, without token drain. At the new pace it cannot cross two hourly boundaries; existing autosave coalescing remains harmless.
- Legacy snapshots without `real_us_per_day` are interpreted with the previous 900,000,000 denominator. Conversion scales the fractional-minute remainder into the new denominator and truncates less than one accumulator unit. The largest accepted multiplication is below signed 64-bit capacity. Unsupported periods or invalid accumulator ranges reject before mutation. The added half-minute regression checks the subsequent hour boundary.
- Token drain rates remain 1/2/4 tokens per real minute at 2x/4x/8x. Each full boosted day therefore uses 12.5 tokens, with whole-token prepayment accounted for by clock credit. Runtime and Python estimates agree for the checked range.
- Gameplay tests now advance 750 two-second frames for a normal day. The hour-boundary test correctly requires three seconds from minute 59. Course submission while paused is checked to preserve pause state.
- Editor pause button emits the existing `toggle_pause` intent, refreshes between existing pause/resume string keys, and registers an input-exclusion region through `region_buttons()`. HFlowContainer permits toolbar wrapping. This code does not make the previously unwired live editor/session integration complete; phone layout, pause routing and actual editing while paused still need runtime/device evidence.
- DEC-071's about-50-hour target corresponds to 120 normal-speed running days. The simulator now labels normal-speed hours and distinguishes its unfunded speed-mix sensitivity. Population weights and campaign timing remain model assumptions, not observed playtests. Pauses and creative editing add elapsed playtime.

## Evidence limits and scope

The Python clock checker verifies boundary arithmetic, not actual Godot event emission or ledger integration. Updated Godot tests supply that intended coverage but remain unexecuted.

## Completed report and final documentation review

The completed `sim_report.txt` agrees numerically with `economy_audit.md`: non-novice weighted completion is 84.7% during days 100–150 and 92.6% by day 150; the 40–60-hour diagnostic window is 79.8%, below 80%. All-player completion is lower (72.0% during days 100–150, 78.7% by day 150, 67.9% in the diagnostic window). Novice models never clear tier 5. Reported finisher days 94/119/153 convert to 39.2/49.6/63.8 normal-speed hours. Profile casual/competent/expert medians 52.5/45.4/39.2 hours and demo last-purchase day 2 agree. Boost costs and the explicitly unfunded speed sensitivity agree with the reviewed clock math.

Interpretation finding sent to the lead: `sim.py` computes completion shares using profile/habit weights, but `fin_days()` concatenates raw finisher samples without those weights (60 samples in casual cells, 20 in other habit cells). The 119-day/49.6-hour median is therefore a **pooled sampled-finisher median**, not a weighted-population median. The audit/report must preserve that distinction; this does not invalidate the independently weighted completion percentages. The verifier reviewed the completed output and calculation code, but did not independently repeat the full simulation.

The audit correctly limits the evidence: assumed population/skills/habits, skill growth by days, assumed staff/pace, exclusion of pause/design time, unfunded boost sensitivity, and demo purchase timing rather than design time. Timing does not prove fifty hours of enjoyable gameplay.

The added `test_editor_pause_routes_to_live_clock_and_can_resume` builds the editor on a live view, routes its actual pause button signal into the session, checks paused state and Resume text, then checks resumption. It is statically consistent with `MHScreen.setup/send` and the live clock API; execution is NOT YET RUN. It does not prove the full scene, terrain editing while paused, save behavior, touch exclusion or phone layout.

DEC-070/071 and `activities_research.md` keep a 25-minute normal-speed day, free design pause, hourly income and an approximately 50-running-hour target. Research explicitly labels activity/minigame ideas as proposals requiring a scope decision, separates source examples from design inference, and does not silently expand frozen v1. This verifier checked that framing, not the linked source content.

DEC-070 permits free pause while designing and keeps income/autosave hourly. DEC-071 authorizes pacing and a research shortlist; it does not add features to frozen v1. No 12-minute-day implementation is present in this diff. Completion or merge approval under DEC-041/Definition of Done is withheld pending the required evidence.

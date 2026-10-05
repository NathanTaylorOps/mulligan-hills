# Economy audit: 5 October 2026

## Current verdict: DEC-070/071

Nathan approved a 25-minute normal-speed day, free pause while designing, hourly income, and about 50 running hours to an 18-hole course with all ten buildings at tier 5. DEC-069 prices are unchanged. The pooled sampled-finisher median is 119 days / 49.6 hours (not a weighted-population percentile). This supports the timing choice, not a claim that fifty hours of gameplay is fun.

Ran `python3 sim.py all 60`; complete output: `tools/reference/economy/sim_report.txt`. Sixty runs per profile, twenty per non-default weighted habit cell, 400 days. Population weights, design-skill growth and buying habits are assumed, not observed players.

## Results

- Non-novice weighted population: 84.7% finishes during days 100–150; 92.6% by day 150. This exceeds the original greater-than-80% game-day criterion.
- Pooled sampled-finisher day p10/p50/p90: 94/119/153; normal-speed running hours: 39.2/49.6/63.8. Casual median 52.5 hours; competent 45.4; expert 39.2.
- A diagnostic 40–60-hour window contains 79.8% of non-novice modelled players, not over 80%. This window is not a new locked target; do not report otherwise.
- Hours exclude pauses and creative editing. Skill grows with days rather than actual design actions. The bot assumes staff and pace requirements are met; the real session still has no authoritative staffing or pace source. Novice bots never clear the final rating gate.
- Hourly income arrives every 25/11 minutes: approximately 2 minutes 16 seconds at 1x.
- A boosted day costs 12.5 tokens at all three speeds, with prepaid fractional credit retained. Time saved: 12.5 / 18.75 / 21.875 minutes at 2x / 4x / 8x. The report's mixed-speed sensitivity requires 500–750 tokens over days 100–150; it is explicitly unfunded and is not the campaign baseline.
- The bot buys the demo's seven building steps by day 2 at the locked $50,000 start. This does not measure nine-hole design time. Demo pacing still needs playtests; no cash reduction was made.

## Historical correction

The earlier 15-minute-day audit found the 20–30-hour target failed at normal speed. A 12-minute proposal was withdrawn before implementation. DEC-070/071 supersede that hours calibration. The prior renovation correction remains: all buildings must be tier 5, as DEC-069 specifies.

## Validation and remaining work

Python economy selftest and full simulation PASS. Clock boundary vectors PASS. Schema/catalogue validation ALL PASS; runtime/spec parameter copies remain identical. Golden semantic changes are only time-speed token estimates. Godot import, tests, end-to-end play and device pacing remain pending CI/device evidence. Scene/editor/save integration remains unfinished; no main merge or completion sign-off claimed.

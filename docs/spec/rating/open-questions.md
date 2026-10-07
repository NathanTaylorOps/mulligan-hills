# Rating engine: open questions that need a human playtest or a device

Status: provisional calibration and device/playtest questions. Everything in `rating-engine.md` and `golfer-sim.md` is a specification checked only against a Python reference model. The numbers below are starting values, not tuned values. Each item says what to test, who can do it, and what result would change the spec. "Needs device" means it cannot be answered without running the GDScript on a phone; nothing has been run on a phone.

## A. Things only a person can judge (playtest)

1. **Tier gate values (32 / 42 / 52 / 62 average hole score).** The reference model rates a plain wide hole about 37 and a hole with a real choice 55 to 65. Question: can a real designer reach 62 on 18 holes with reasonable effort, and does 42 arrive too easily? Test: 5 people design a 6 hole and then an 18 hole course in the closed test, record `course_x10` and time spent. Change gates if fewer than 1 in 4 testers reach tier 4 within the target session time set by the economy workstream. Tuning is data only (`params.json`).
2. **Does a plain hole at 37 feel fair to the player?** The player sees 0 to 100 per hole. A hole a beginner thinks is fine shows 37. Test: show 10 first-time players their first three holes and ask if the score matches their feeling. If not, consider a display curve (display only, never stored) rather than changing weights.
3. **Weights (Accuracy 25, Imagination 35, Length 20, Beauty 20, Fairness multiplier 40 to 100 percent).** Test: rank 12 holes by feel with 5 designers and compare with `score_pm` order. Change weights if rank correlation is weak. Watch that Beauty at 20 percent does not feel dominant on a poor hole (the `PQ + 300` cap is the guard).
4. **Imagination is the least trustworthy axis.** It uses a geometric corridor count (2 corridors 800, 3 or more 1000) plus a temptation term. In the reference model temptation (`risk_pm`) is rarely above the floor, so most of the difference between good holes comes from corridors. Needs: 10 designed holes of these types: dogleg with corner hazard, par 5 with a lay-up decision, par 3 with bunkers around the green, split fairway, island green, tree-lined narrow hole. Question: does the score order match what golfers say is interesting? The planner lattice (28 aim points along the line to the green) does not model a dogleg well; a bend needs waypoint aims. This is the largest known gap.
5. **Beauty content.** What players find beautiful is art direction: tree spacing, water shape, flower colour. The engine only rewards presence, saturating counts and relief. Test: show pairs of holes with equal play but different decoration and see whether the higher Beauty matches preference. Also decide whether Beauty may use per-object art value (a rare tree species) later.
6. **Duplicate thresholds (dup factor starts at similarity 700, reaches 0.4 at 1000).** Real courses have similar par 3s. Test with the hole template copy and mirror feature: how often does an honest design get flagged (RC061, RC062)? If more than 1 in 6 honest holes are flagged, raise the start to 750 or 800.
7. **Complaint feed wording thresholds.** The trigger levels for RC021 to RC027 (forced 100 and 300 permille, pickup 30 and 100) are guesses. Test: players read the text for 20 generated holes and mark which complaints they consider fair.
8. **Tournament parameters.** Checkpoint every 3 game days, 8 checkpoints, application at sustained 52.0, prestige 400 for a pass, cooldown 30 and 60 days, 24 pros. These depend on how long a game day lasts in real time (the economy review assumed 18 seconds, unconfirmed). Test with the economy simulation, then with the closed test.
9. **Is calm-only official rating acceptable?** It keeps gates stable, but a hole exposed to wind is not rewarded or punished. Playtest question: do players expect wind to matter to the score? If yes, consider a second reference condition at low weight, at the cost of time.
10. **Pace standards (420 / 560 / 720 seconds) and the 15 percent tolerance.** They came from typical round lengths, not data. Test with the tee sheet and queue prototype once it exists.

## B. Things that need a device or CI

11. **Speed.** The reference model needs about 50,000 to 62,000 ball-flight evaluations per hole and about 0.7 to 0.8 s of Python per hole on a desktop. Target: 250 ms per hole and 5 s per 18 hole course on the benchmark phone. Unknown for GDScript. Test: Gate 0 benchmark. If missed, use the levers in `golfer-sim.md` section 14 (coarser cache cell, 5 lateral columns, preview mode). Each lever changes the results and needs a version bump.
12. **Bit-identical results on Android, iPhone and desktop.** Test: run fixture 08 (hash vectors, golden sim hash) on each. Risks to watch: integer division semantics (`/` truncates in GDScript, spec needs floor: `fdiv`), signed 64-bit wrap in the 32-bit hash multiply, any accidental float from `/` on an int in a mixed expression. None of this has been run.
13. **Seed noise.** Hole scores move about 25 permille (standard deviation) between epochs; a full 18 hole course moves about one point. Question: does a 2 to 3 point flicker on a hole card at season change annoy players? If yes, raise `N` to 180 or 240 for official runs (cost x1.5 or x2), or show ratings rounded to 5.
14. **Preview mode accuracy (N = 30).** Measure how often the live preview differs from the official rating by more than 5 points on the same hole. If often, the editor should show a range or label it an estimate.
15. **Memory.** The cost table cache holds one entry per band, 4 yard cell and lie; not measured on device.

## C. Model realism (calibrate against a golf-knowledgeable reviewer)

16. Reference scoring on a 400 yard par 4 (calm, no hazards): band A about 4.1, C about 4.4, E about 5.4, F about 6.1 strokes. A real 40 handicap averages closer to 6.5 or more. Question: is the low end too kind? Changing dispersion at low skill changes Accuracy and all gates.
17. Driver carry by band (253 yards at skill 930, 170 at skill 140), chip and pitch dispersion (`short_game_mult`), putting make rates (`putt_p1_base`), three-putt rates. These are plausible but unsourced. No real golf statistics were used; do not describe them as sourced.
18. Trees are 2 yard circles that intercept the flight line for the first part of the flight. There is no tree height, no canopy and no punch-out recovery choice beyond the aim lattice.
19. No slope, no green speed, no lie roll, no elevation effect on distance ("plays like"), no rough grass length, no fairway firmness. Decide which of these the player must feel; each adds a table and changes the version.
20. Wind and rain factors (8 permille per mph along, 6 across, 4 percent per rain level) are round-number guesses.

## D. Design decisions still open for other systems

21. Tier 5 tournament pass value (prestige 400) and the VIP donor mechanic. The contradiction review found the donor mechanic missing from the plan; this spec only defines prestige without tier 5 inputs.
22. Whether a hole counts toward the size gate only when not dead (`score_pm >= 250`). Proposed here; the economy workstream must agree.
23. Whether the game displays the per-axis formula. The reviewer notes the formula becomes public once the advisor explains it. This spec accepts that: nothing in it depends on secrecy except `save_secret`.
24. Server verification budget: how many entries per day the server can re-simulate (each is about 1 to 2 hole ratings), and which are sampled. Owned by the backend.


## Elevation (answered, DEC-091)

Q19 said slopes had no effect. Superseded: a hole may include `relief` {x0, y0, step, cols, rows, z[]} (yards, heights in mm, row-major, nodes at x0 + i*step). When present the engine derives tee and green height from it and:

- plays-like distance: delta = (z(aim) - z(ball)) / 10 centiyards, clamped to +-50% of the shot; the club is chosen for distance + delta and the ball travels distance - delta on the ground;
- roll: on landing (not after a tree hit, not into bunker, water or OB) the ball rolls down the local slope: roll = -gradient (mm per yard, per axis) x 3 x lie factor (tee, fairway, fringe 1.0; rough 0.35; deep 0.12; green 1.5) x (2.0 - club loft), capped at 4 yd per axis; it can roll into water or off the course;
- putting: slope = half the sum of |gradient| at ball and cup (mm per yard); one-putt chance falls by 1% per mm/yd (max 40%), three-putt chance rises by 0.5% per mm/yd (max 30%), plus 0.25% per mm of downhill drop (max 15%);
- axes: Imagination elevation and Beauty relief use max(|green z - tee z|, 60% of relief range);
- validation: E04 missing key, E05 more than 16384 nodes, E06 wrong z length, E07 non-integer, E08 out of range (|z| > 40 m, step > 64, origin beyond 1200 yd), E09 fewer than 2 columns or rows or step < 1;
- the content hash covers the relief only when present, so flat holes keep their hashes.

Constants are in params.json under `relief`. Reference: tools/reference/rating/rating_core.py (Hole.z_at, grad_l1, land, putt_count). Not modelled yet: aim compensation for cross slopes, bounce, green speed, lie angle (uphill/downhill lie penalty).

# Between-purchase activities: research and proposal

5 October 2026. Nathan requested mechanics/minigames that fit Mulligan Hills, after approving 25-minute days and an approximately 50-hour campaign. Research complete; proposals NOT IMPLEMENTED. Nathan clarified the intended golfer RPG, playable competition, celebrity residency, wildlife, staffing/maintenance and visual rewards after this first research pass; see `rpg_scope.md`. DEC-014 freezes v1 scope: new systems need an explicit scope decision. Durations/effort below are design estimates, not measured playtests. Existing module capability does not mean the playable scene is connected.

## Updated recommendation after Nathan’s clarification

Golfer training and personally playing the course are central to the intended product, alongside building it. The earlier recommendation below prioritized the narrower frozen implementation and must not be read as making the golfer RPG an optional side activity. Prioritize a controllable hole, meaningful attribute training and career/club reward feedback before expanding the volume of management activities. Their launch classification must be reconciled with DEC-014/039 through the proposals in `rpg_scope.md`.

## Original course-management research

Make improving the player's actual course the main activity. Provide fast feedback, a useful next objective and visible finances. Prototype course diagnosis, constrained design briefs and tournament readiness before adding an unrelated activity. Fifty hours must come from decisions and creative work, not fifty hours waiting for money. Free pause remains available; saving/quitting must not depend on finishing a 25-minute day.

## What the sources establish

- [GolfTopia, developer Steam page](https://store.steampowered.com/app/1144020/GolfTopia/) emphasizes golfers' opinions and thoughts attached to locations. Its course-building feedback is relevant; its fantasy machinery is not a recommendation for our tone.
- [Golf Story, official developer page](https://sidebargames.com/golfstory/) combines golf with challenges, puzzles and variants such as long drives and mini golf. This establishes useful examples, not proof that those features would improve our tycoon.
- [Planet Coaster 2 management deep dive, Frontier](https://www.planetcoaster.com/en-US/news/2024-09-25/deep-dive-mastering-management) describes accessible management tools, pinned objectives, guest feedback, staff management and notifications. Our proposed equivalent is one accessible club-management panel, with editor alerts linking to the affected hole.
- [USGA: improving pace and golfer experience](https://www.usga.org/content/usga/home-page/course-care/green-section-record/58/21/improving-pace-of-play-and-the-golfer-experience.html) and [R&A course guidance](https://www.randa.org/nb-NO/pace-of-play/manual/3-the-golf-course) connect layout, appropriate tees, difficulty and flow with playing pace. This makes course-flow problems a coherent management activity. DEC-052's tee interval remains locked; varying it would require a decision.
- [USGA: hole location](https://www.usga.org/content/usga/home-page/course-care/forethegolfer/2018/hole-location--location--location.html) supports the realism of pin-placement decisions. Our current circular green model has no independent pin/slope model, so this is an extension, not a cheap interface change.
- [Topgolf official games](https://topgolf.com/us/miami-doral/play/games/) illustrates target-based golf challenges and differing skill levels. Use the principle, not their brands or exact scoring systems.

Recommendations below are our inference from those mechanics and the existing repository. They are not measured market demand or guarantees of fun.

## Recommended course and management work

| Activity | Player's meaningful choice | Estimated session | Implementation fit |
|---|---|---|---|
| Course doctor | Inspect a troublesome hole, identify a harmful bunker or route, edit it, compare official before/after results | 2–5 min | Existing rating reasons/shot records help; diagnosis presentation and live editor wiring still needed |
| Design brief | Build a hole under constraints: short par 3, safe novice route, attractive risky shortcut, limited land | 3–8 min | Reuse commission/daily concepts; template delivery and completion UI remain work |
| Design lab | Predict different skill groups' routes, run a preview, move a hazard and compare | 2–5 min | Reuse deterministic rating; same seed for comparisons. Preview scores must never unlock progress |
| Tournament preparation | Pin the readiness checklist, fix weak holes and resolve missing requirements before entering | 3–6 min | Existing gates/tournaments help; real staff and pace sources are still missing |
| Member/service decisions | Respond to a club request with a real cash/service tradeoff | 1–3 min | Prefer existing event cards; persistent individual golfer relationships would be a substantial new system |
| Staff allocation | Allocate limited marshals, maintenance and service staff against forecast problems | 1–3 min | New authoritative recruitment/wages/assignment rules needed. Do not manufacture staff numbers |
| Land masterplan | Fit the next holes and walking routes before committing parcel money | 3–10 min | Existing editor/land systems; useful while saving for a purchase |
| Signature-hole makeover | Improve framing and scenery while preserving playable routes | 3–10 min | Procedural art and editor fit; avoid rewards for tree spam or an endless decoration checklist |

Course doctor should show the reason for a bad result immediately. Design lab should show a fair comparison, not encourage repeatedly rerolling a score. Rewards must reuse approved once-only/capped rules; no repeatable cash faucet. Keep visitors' feedback concise and tied to a location/action rather than a stream of identical complaints.

## Golf minigames: intended RPG scope, pending launch reconciliation

| Idea | Why it fits | Estimate | Main cost/limit |
|---|---|---|---|
| Predict the shot | Pick a club/landing zone, watch the golfer execute, learn how design changes choices | 30–60 sec | Needs explicit planner inputs and result UI; no betting or cash farming |
| Nearest-pin practice | Five balls at a target with a personal best | 60–90 sec | Player aiming/power, shot interface, camera and feedback are new work; current AI simulation is not a ready player-control system |
| Three-shot rescue | Solve an awkward situation on the player's own hole; choose safe layup or risky approach | 1–2 min | Could begin as a planning challenge with AI execution, but new intent/validation hooks are needed |
| Putting trail | Three short greens with a precision challenge | 2–3 min | Requires a putting/control model beyond the existing rating geometry; higher effort |
| Daily pin setup | Trade fairness/difficulty against wear and event requirements | 1–2 min | Requires independent pin placement, green geometry and rating changes; defer |

The clarified vision prioritizes hands-on nearest-pin/accuracy, putting and recovery practice with attribute growth. Predict-the-shot can supplement learning but cannot replace controlling the golfer. Personal grounds maintenance is part of Nathan’s clarified intent. Make it optional and offer employee delegation; avoid mandatory repeated chores, cooking meters, energy bars and random-reward grinding.

## Interface and playtest proposal

One easily reached club panel: pinned objective, hourly income/net costs, next purchase and estimated affordability, tournament readiness, staff and prioritized notifications. Staff remains visibly unavailable until a real model exists; do not display invented values. Editor should keep the objective, cash and pause control within reach. Urgent alerts should offer a direct route to their cause.

Test whether a player can find worthwhile optional work every 2–4 active minutes, whether results are understandable immediately, and whether they can stop mid-day without losing work. These are prototype criteria, not new locked balance targets. Observe actual unprompted play; do not infer fun from bots or elapsed timers. After Nathan’s clarification, start with a controllable player-built hole, an attribute-training challenge, a rival match and a visible reward; build course diagnosis, briefs and readiness alongside the core loop. No feature above is silently added to v1.

## Verification and open questions

Research uses primary developer/governing-body pages. Sources demonstrate mechanics, not their suitability for a 50-hour mobile game. Existing live scene/save/editor integration and staffing/pace rules must be completed before this can be honestly playtested. Need player evidence for frequency, mobile UI burden and campaign duration including paused design time. Godot/device tests NOT YET RUN for the current pacing revision.

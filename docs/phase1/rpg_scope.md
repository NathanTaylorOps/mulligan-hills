# Golfer and club RPG: scope reconciliation

Status: 5 October 2026. Nathan approved “must ship” after reviewing PROP-11–14. Requirements are now locked as DEC-072–075. New mechanics NOT IMPLEMENTED. Those entries explicitly amend the scope/cut/campaign decisions; numerical mechanics and the final career milestone remain proposed/open.

## Product intent

Create and control a golfer. Improve skills/attributes through small golf minigames and playing the course being built. Compete personally in tournaments and high-stakes private matches against fictional in-game pros. Develop a club with RPG progression, celebrity visitors who can buy homes and become VIP members, positive/negative animal encounters, hired/placed pest-control staff, personally controlled or delegated grounds maintenance, funny interactions and trophies/achievements that produce visible course upgrades and building skins.

No online opponent requirement was requested. Private matches here mean NPC pros, with in-game stakes; no new real-money purchase is implied. Celebrity/pro naming remains fictional. All art remains procedural, offline play remains required, days remain day-only and tokens remain earned-only under the existing decisions.

## What exists and what does not

Inventory checked against the full phase1 GitHub tree at `999ac8a746ee620dfb0c23769ab9661a56931dcf` and the locally materialized core sources/status documents. Art, terrain, character, render and input files are absent from this partial checkout: the remote tree verifies those paths exist, while their capabilities below are documented foundations from the status files, not newly inspected implementation or runtime evidence. “Foundation” does not mean connected, playable or verified on a phone.

| Requirement | Existing foundation | Missing behavior |
| --- | --- | --- |
| Designed player golfer | Procedural golfer looks, poses and figures | Character creation UI, persistent identity, controllable golf and career save |
| Skill/attribute growth | Fixed AI skill bands and shot calculations | Player attribute model, XP/training rules, attribute-specific shot behavior |
| Play built course | Course editor, geometry/rating, prototype shot sim | One authoritative geometry conversion, player shot intent, aiming/power/camera/round state |
| Play tournaments | Hosting requirements, deterministic field results, settlement | Human-controlled entry/round score, legitimate rank integration, resume mid-round |
| Private pro matches | Tournament NPC skill distributions | Named rival roster, invitations, match formats, agreed stakes, escrow and settlement |
| Club RPG | Club levels, monotone stats, achievements, building tiers | Complete live presentation and reward consumption; tuning high-level reachability |
| Celebrities/home buyers | Celebrity/VIP cards, Homes building | Persistent visitor identity, satisfaction, finite home occupancy and VIP residence rules |
| Animals/pests | Narrative encounter cards | Placed/visible animals, gameplay encounter state, population/coverage simulation |
| Employees | Maintenance building and tournament staffing gates | Recruitment, wages, roles, zones, capacity and deterministic work scheduling |
| Personal maintenance | Course editor and procedural world art | Maintenance tools/actions, grounds condition state, player control and delegation |
| Funny golfer interactions | Golfer figures/poses and event narrative | Context triggers, scene actions, short dialogue, cooldowns and presentation |
| Trophy/skin rewards | Achievement catalogue and level unlock IDs such as plaques, flags and cart paint | Trophy/reward catalogue, ownership vs selection, procedural variants and live application |

`MHShotSim` is a prototype using Q16.16 metres and skill 0..100; rating `MHSIM-1.0.0` uses centiyards and skill 0..1000. Neither can be silently substituted for the other. Rating putting is probabilistic, not interactive putting physics. `MHTournamentSim.run_field` simulates the whole field; it does not accept a personally played round. Current live-session staff/pace gates remain blocked rather than invented.

## Approved proposals: locked by DEC-072–075

The following original proposal text is retained for rationale. Launch classification is now decided: all listed requirement groups must ship. Read DEC-072–075 for the authoritative outcome; no further launch permission is needed.

### PROP-11: launch golfer career and control

Amend DEC-014/039 to treat a create-and-control golfer career, attribute training, play on the built course, personal tournament participation and NPC private matches as launch requirements. Preserve tournament hosting and its building gates (DEC-010/027). Personal golf is no longer the first cut among later additions. Re-estimate delivery only after the one-hole control prototype; do not carry forward an old schedule as if this is free scope.

Tradeoff: this materially increases implementation, mobile controls, saves and testing. Nathan’s intended game needs this identity; a narrower course-only launch would be a different product. This proposal adds scope openly rather than claiming the systems were already implemented. If scope must stay fixed in size, Nathan must select replacements explicitly; no features are removed here.

### PROP-12: living club and delegated work

Record celebrity satisfaction → home purchase → VIP membership, finite home occupancy, beneficial/nuisance wildlife, employee hiring/zone placement for grounds maintenance and pest control, optional personally controlled maintenance, and contextual funny golfer interactions as product requirements. Launch inclusion is now locked by DEC-072/073; narrative cards remain a foundation, not a substitute. Preserve DEC-027: a VIP donor is not a mandatory tier-5 gate. Home capacity stays within DEC-056’s working 5–6 slots until that decision is revised; do not create unlimited celebrity homes.

### PROP-13: visible earned rewards

Trophies/achievements unlock earned procedural course decorations and building visual variants. Visual variants do not silently change economic tier, footprint, rating or progression gates. Ownership is saved separately from the currently selected appearance; rewards are granted once, persist on reload, and previews show both locked requirements and earned items. Preserve DEC-062; no imported art or paid cosmetics are introduced. Any economic effect needs a separate balance decision.

### PROP-14: campaign success definition

Retain the about-50-hour working target and 25-minute day, but expand the campaign-completion definition beyond 18 holes/all tier-5 buildings to include an agreed golfer-career milestone. The milestone remains undecided: top tournament win, final rival victory, or another measurable finish. Keep club and career progress visible independently. The current 49.6-hour pooled economy-model median is only the building/course path; it cannot validate the complete RPG campaign. Measure active play and paused design time separately before calling the overall campaign calibrated.

## Recommended first playable slice

1. Create a procedural golfer, save the look, then aim and play one saved player-built hole. Provide a novice-safe line and optional risk. Confirm controls on Nathan’s S22 Ultra before adding many modes.
2. Give a short accuracy challenge and a completed-hole result meaningful, bounded training progress. Show precisely what improved. Persist progress and resume the round safely.
3. Challenge one fictional rival on that hole. Accept the stake up front, then play; settle once, with replay/reload protection. Practice remains free. A loss must not bypass the existing recovery rules.
4. Unlock and visibly apply one trophy/course decoration and one building appearance. Prove a save/reload retains ownership and selection without changing tier or score.
5. Add one celebrity visit/home outcome, one beneficial and one nuisance animal encounter, and one hired maintenance/pest-control employee assigned to an area. Personal maintenance and delegated work operate on the same grounds-condition state.

These are acceptance stages, not five independent features to code simultaneously. Finish live scene/course/save integration first; without it, the prototype cannot test the promised game.

## Proposed golfer design: parameters and choices NOT LOCKED

Start with four understandable attributes: Power, Accuracy, Short Game and Putting. Personal form/confidence could be added later if it creates a distinct choice rather than another grind bar. Keep human input and character ability distinguishable: good input helps, while attributes bound carry, dispersion and control. Avoid leveling that makes input irrelevant or forces a grind before a player can hit a reasonable shot.

| Training | Proposed benefit | Suggested round length |
| --- | --- | --- |
| Target drive | Accuracy, with power improvement tied to controlled distance rather than maximum-distance spam | 60–90 seconds |
| Chip to zones | Short Game; different lies and safe/risky landing choices | 60–90 seconds |
| Putting ladder | Putting; clear distance/direction feedback | 60–120 seconds |
| Recovery challenge | Short Game/Accuracy plus learning strategic layups | 1–3 minutes |
| Actual round | Progress from meaningful play across relevant shot types | Depends on hole count; measure, do not promise a full round fits a 25-minute day |

Repeated practice remains available, with diminishing XP for identical easy drills. Better/different challenges should be worthwhile without an energy timer or real-world daily grind requirement. Numerical XP, caps, attribute-to-shot formulas, equipment effects, match stakes and payouts require a Python mirror and explicit balance review. These proposals are not the existing AI skill formula.

## Clock, economy and save boundaries that must be resolved

- Whether club time runs, pauses or advances by shot while personally playing must be decided. Do not assume an 18-hole round lasts one game day. Free design pause remains locked.
- Hosted tournament bookkeeping and personal competition are distinct. Define how a player's actual score replaces one field entry, qualifying rules, abandonment and tie breaks. Snapshot and lock competition geometry so a hole cannot change mid-match.
- NPC stakes use earned game cash. Agree an affordable stake, reserve it atomically and settle once. No reload rerolls, double prizes, crediting arrivals as finished golfers, or invented staff to enter a tournament.
- Career save additions need schema/migration/defaults for existing slots. Active rounds must restore without re-awarding XP, trophies or cash. Cloud conflicts remain explicit; clock/RNG units and compatibility need golden tests.
- Maintenance costs, employee wages, celebrity payments and career prizes change income/progression. The current economy report excludes them; rerun a joint model before claiming they preserve the target.
- Animals/humour can be visual-only or gameplay-affecting; decide per interaction. Cosmetic callbacks must not consume authoritative sim RNG or alter official rating. Gameplay events use seeded integer state and bounded effects.
- Reward skins must use the procedural building pipeline, preserve budgets and remain visibly readable on a phone. Existing palette contrast concerns and low-end draw-call budgets still apply.

## UI recommendation

Keep a reachable golfer card (attributes, training, next rival), club panel (objectives, finances, staff, notifications), competition card (play vs host), and trophy room (earned/locked rewards and appearance selection). Link a visitor complaint or pest alert directly to the affected area. Limit urgent interruptions; comedy should enrich observation, not repeatedly steal control mid-shot. Show real data and unavailable systems honestly.

## Status and verification

Static inventory complete. No new Godot API introduced by this document. No new mechanic or data schema implemented. CI results must be checked at each push; queued runs provide no runtime verification. A joint campaign model, input prototype, save compatibility, end-to-end scene and on-device proof remain required. Separate verifier review is required before completion/merge certification under DEC-041.

## Implementation order after launch approval

1. Complete the existing live course/editor/session and validated hourly save integration; resolve geometry/units explicitly and preserve determinism goldens.
2. Specify and prove one controllable saved hole, golfer identity and resume-safe round state on Android. Do not create a second unrelated golf engine to bypass the existing geometry issue.
3. Add attribute training and actual-round progress, then one NPC private match with atomic stake/reward settlement and one personally played tournament integration.
4. Connect trophy ownership/selection to procedural course art and building skins; add celebrity/home/VIP and wildlife behavior with deterministic state.
5. Implement staffing/area coverage and shared personal/delegated maintenance conditions; jointly rebalance wages/prizes/visitors/XP and test the full career/club loop.

This sequence does not downgrade any must-ship requirement. Schedule estimate remains pending measured implementation/prototype evidence. Do not promise the previous DEC-040 delivery range. A proposed career endpoint is winning a major on the built course plus defeating the final named rival; it remains a recommendation, not an additional locked gate.

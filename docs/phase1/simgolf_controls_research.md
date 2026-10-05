# Personal golf controls: SimGolf research and proposed direction

Date: 5 October 2026. Nathan requested SimGolf mechanics research during the one-hole prototype. This is a control-design proposal, not a new locked decision. DEC-072 still requires a controllable golfer, training, progression, personal tournaments and private NPC matches.

## What the 2002 Sid Meier game did

Research specifically concerns **Sid Meier's SimGolf (2002)**. The separate 1996 SimGolf has MouseSwing/three-click controls and is not the reference Nathan means.

A contemporary [GameSpot review](https://www.gamespot.com/reviews/simgolf-review/1900-2843958/) describes choosing a stroke type and a target/trajectory to set the shot's strength. It describes ten golfer abilities, checked by the game according to the shot situation, and character advancement through play. Competition winnings feed course development. This is evidence for decisions and character ability driving golf within the management game; it is not evidence of a timing-bar requirement.

A [first-hand player review](https://gamefaqs.gamespot.com/pc/480860-sid-meiers-simgolf/reviews/93023) identifies straight, left-to-right, right-to-left, spin and punch choices, followed by clicking a target and seeing the intended path. It reports skill increases for design accomplishments and strong shots, and skill losses for poor play. The [2002 strategy guide](https://gamefaqs.gamespot.com/pc/480860-sid-meiers-simgolf/faqs/16147) explains developing the golfer to suit the course, using practice to learn shots and entering matches/tournaments. The [archived controls sheet](https://oldgamesdownload.com/readme/sid-meier-s-simgolf-windows-controls-english/) documents a golfer-trajectory toggle and direct access to financial, membership and accomplishment reports; it does not specify the full shot interaction.

No original full manual was obtained in this research. Control descriptions are corroborated accounts, not a claim that every original implementation detail has been verified. No game binary or third-party assets were imported.

## Recommendation for Mulligan Hills

Use **choose target -> choose shot style -> review likely outcome -> commit -> watch**. Touch sets/moves the target; confirmation is a separate large button. The character chooses an appropriate club and executes automatically. Swing reflex, swiping speed and timed bars should stay out of this prototype.

The player should understand the consequences of their choice: intended path, reachable distance, likely landing area and lie/hazard warnings. A landing area is an honest uncertainty estimate, not a promise of the outcome. Show why a shot missed in plain language without exposing implementation numbers. One button returns the camera to the golfer; allow short or skipped animations. Save after each committed shot. Keep design and play modes distinct, so a terrain tap cannot accidentally commit a shot.

Introduce shot styles gradually: start with straight and a safe recovery option; curved/high-spin choices follow once geometry and skills support them. This is an implementation sequence, not permission to remove personal golf or the locked launch requirements. Existing official rating is frozen; introducing player shot styles needs a separate specified player-flight model/reference if the official AI cannot model them. Do not silently change rating goldens or pretend the current straight-flight prototype implements draw/fade/backspin.

Training can use the same controls: nearest-the-pin, accurate landing zones, safe recovery routes and choosing between risk/reward targets. Objectives can vary terrain, lie and route instead of creating several unrelated control systems. Progress should reflect meaningful completion and a bounded training reward, with protection against replay/quit exploits. Exact skill names, XP rates, training caps and reward rules are still open.

Improve on the frustrating parts reported by players: free design pause already exists; competition designs must be frozen; score feedback should explain causes; poor shots need useful recovery choices. I recommend against random permanent skill loss for a single bad shot. That is a proposed progression rule, not something already locked or implemented.

## Current code and next step

The development one-hole panel uses buttons to move an aim and commits automatic integer flight, with no timing bar. Club choice is automatic; practice has fixed scalar skill, no career rewards, a simplified individual putt and a saved round. It supports neither varied shot styles nor a finished golfer avatar. Numeric/button aiming, instant ball relocation and flat primitive shapes are technical proof controls only.

Next control increment: tap-to-aim on the exact hole, visible path and reachable landing preview, camera follow, then skill-specific shot choices. Measure whether players understand risk without a tutorial wall before widening content or adding animation detail. Proposed DEC wording if Nathan accepts: 'Personal golf uses target and shot-style decisions with automatic execution driven by golfer attributes; no mandatory timed/swipe swing. Training shares those controls.' This remains a proposal.

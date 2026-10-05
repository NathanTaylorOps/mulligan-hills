# Personal golfer controls and attributes: implementation proposal

Date: 5 October 2026. DEC-072/075/076 requirements are locked. This document proposes the detailed mechanics; attribute names, thresholds, coefficients and progression rates are **working choices, not locked decisions**. No player attribute or shot-style behavior below is implemented by the current fixed-skill practice prototype.

## Player loop

Choose a target on the saved course, review reach/path/risk, choose a shot style and confirm. The golfer automatically selects the appropriate club and executes based on attributes and the lie. Confirm consumes a single shot; tapping, inspecting and previewing consume nothing. Separate design and play modes prevent an input doing two jobs. Practice can be restarted freely. Competitive rounds must use an immutable course snapshot, player profile and event conditions.

Outcome presentation reports the useful cause: landing lie, distance remaining, penalty, tree collision, overreaching or poor recovery. Do not reveal the next seeded random draw in previews. Attributes affect the simulated outcome; animations display the result rather than engine physics deciding it. Saving the committed result precedes competitive payout or XP settlement. Resume cannot reroll a committed stroke.

## Proposed attribute responsibilities

All proposed stored attribute values are integers 0–1000, matching the precision of the rating engine's skill bands but **not replacing those bands**. Initial values and progress costs require reference simulation before adopting a default. Use seven explicit attributes rather than repeatedly converting one skill value.

| Attribute | Gameplay responsibility | Training objective |
| --- | --- | --- |
| Power | Available carry on long full shots; does not grant universal accuracy | Reach safe distant landing zones |
| Accuracy | Lateral dispersion for full straight shots | Place shots inside fairway targets |
| Touch | Short-distance carry/depth control, putting dispersion and spin stopping control | Closest-to-pin and putting targets |
| Recovery | Carry, dispersion and mishit consequences from rough, trees and sand | Escape difficult lies into a safe zone |
| Shot Shaping | Reliable fade/draw/punch execution; deliberate curve differs from random error | Route around an obstacle |
| Composure | Bounded competitive-pressure dispersion/mishit modifier | Complete scored sequences under match conditions |
| Luck | Bounded chance of favourable random encounters, story outcomes, interactions and golf breaks | Progression source remains open; do not pretend a skill drill trains random fortune |

No permanent attribute loss for one unlucky shot is proposed. Failed training should give feedback without consuming a scarce training purchase. Gains must have a cap and reasonable diminishing returns so repeatedly restarting one trivial drill is not optimal. Nathan requested Luck on 5 October 2026. Include it in the personal golfer design; exact coefficients, growth and event rules remain proposals. Luck must have understandable effects rather than an unexplained universal score bonus.

## Luck: encounters and golf breaks

Luck applies to eligible positive random actions, stories and interactions, including favourable celebrity/VIP encounters, animal interactions and golfer/environment incidents. Eligibility still depends on the course, club reputation and event conditions. Luck cannot force a celebrity to buy a home or bypass membership requirements. Club-wide events use the owner golfer's Luck; snapshot that value when an event starts. Whether a future club trait also affects these events remains open.

For golf, propose occasional favourable breaks on an otherwise valid shot: a helpful bounce or a better recovery outcome within the shot model's legal bounds. Do not erase a committed penalty, turn an impossible shot into a hole-in-one, or add hidden strokes to an opponent. Power, Accuracy, Touch and route selection continue to determine ordinary execution. Exact eligible break types require the personal-golf reference before implementation.

Display Luck and explain a triggered benefit in the result/event message. Preview may report general chances or a Luck modifier, never the upcoming random result. Use independent deterministic random channels for events and golf breaks, with stable event/shot IDs. Inspection, pause, save/reload and reconnect cannot reroll or award the same benefit twice. Cap the modifier; rewards from favourable stories still obey their own unlock and settlement rules. Luck changes neither official course rating nor official rating simulation goldens.

Reference tests must check that greater Luck does not lower eligible positive-event probability, never creates an ineligible event, remains bounded at 0/1000 and produces reproducible saved outcomes. Event probability and reward magnitude need separate caps so repeated easy events do not become an unlimited cash/XP source.

## Shot styles and rollout

| Style | Intended choice | Meaningful cost or constraint |
| --- | --- | --- |
| Straight | Normal full shot to chosen target | Baseline dispersion and obstacle interception |
| Safe recovery | Short controlled escape from a bad lie | Gives up distance to reduce danger |
| Punch | Low route under branches | Reduced carry and different tree-interception height |
| Fade / draw | Curve in either direction around an obstruction | Shaping-dependent error; curved route must be checked, not just endpoint |
| High spin | Short approach with stronger stopping control | Carry/lie restrictions; Touch and Shaping requirements |
| Putt | Ground target from green | Touch-dependent directional/depth error and cup capture |

Straight and individually controlled putting come first, then safe recovery, followed by the styles requiring curved/height/roll calculations. This sequence does not remove any launch requirement. Avoid dummy style buttons that merely rename the same shot. Power is primarily the chosen target distance and available carry, not a separate timing meter. Manual club selection may remain unnecessary unless testing identifies a useful choice that target/style controls cannot express.

## Deterministic simulation boundary

Create a separately versioned personal-golf reference/model. Reuse established integer math, hashes, units and validated geometry. Do not modify official rating MHSIM/MHRATE definitions or regenerate their goldens merely to add player controls. Personal golf should agree on lie/hazard/geometry interpretation while being free to add the specified shot-style model under its own version.

Before implementation, reference tests must establish:

1. Increasing Power cannot reduce clear-ground available carry; Accuracy cannot increase baseline lateral spread.
2. Recovery changes bad-lie effects without granting a fairway bonus; Touch changes short shots/putts without extending maximum driver carry.
3. Style changes are observable in actual path/roll, not just naming; mirrored fade/draw behavior is symmetric in mirrored geometry.
4. Pressure is bounded, never a hidden compulsory handicap. Exact pressure triggers remain open.
5. Cup capture, stroke penalties and pick-up policy are explicit and separately tested. The current perfect aimed practice putt is a prototype, not the final rule.
6. Every random value derives from round seed and committed shot index; previews do not peek or advance that sequence. Save/reload produces identical next-shot outcomes.
7. Course mutation invalidates practice geometry; competing on a changed course is refused rather than silently accepting an easier hole.

Landings, lies, path interception, carry, penalties and score use integers/fixed-point. World/render transforms and camera easing may use floats at the boundary. Add a field for model version to resumable player rounds when behavior changes, and either migrate or refuse unsupported versions without altering the file.

## Progression and settlement

Training gives one-time/completion-aware XP or capped repeatable practice credit; exact rules remain open. Ordinary played rounds, personal tournament finishes and rival matches can advance the corresponding attributes. Completion IDs and awarded/settled flags must survive saving. Cosmetic reward ownership and selected appearance remain distinct under DEC-074.

Before private match entry, verify unlocked access, compatible immutable course and sufficient earned in-game cash. Hold the agreed stake once; final result pays once; interruption resumes the match. Defeat cannot charge the stake twice. No real-money stake, paid token, online opponent or account requirement is introduced. NPC pros need differentiated strengths so safe play, course knowledge and specialist training matter.

## Prototype acceptance before expanding

A player can identify the ball, target, likely path and danger without reading developer numbers. Recentring and overview must be easy to find. The same target/profile/seed yields the same committed result across supported platforms. Saving mid-round retains ball, strokes and the next draw. A few unfamiliar players should find at least two understandable choices on a meaningful test hole; the current 60-yard developer hole proves integration, not tactical depth.

Do not claim the about-50-hour full campaign is calibrated until career XP, training time, match income and pause/editing time are modeled alongside the existing economy. The agreed final career milestone remains open under DEC-075.

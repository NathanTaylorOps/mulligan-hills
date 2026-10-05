# Open questions for Nathan

Written 29 Sep 2026 by workstream H from the specs and data files. Each question has plain choices and a recommended default. If you do not answer, the default stays in the data files as a placeholder and nothing is locked. Answers should be recorded as `DECISIONS.md` entries by the lead. Reply with the question number and letter, for example "Q3 B".

Not covered here because they need real-world facts rather than a choice: the named low-end benchmark phone model (see DEC-046 and `docs/phase0/GATE0.md`), business entity and trademark advice, and the store Data Safety mapping (legal advice).

## A. Score gates

**Q1. Which numbers gate building tiers 2 to 5?** The average hole score needed to buy a tier. Two specs disagree today: `docs/spec/data/buildings.json` uses 25 / 30 / 36 / 42 (0 to 100 scale); the rating spec (`rating-engine.md` 7.2, `params.json`) proposes 32 / 42 / 52 / 62. The rating spec measured a plain wide hole at about 37 and a hole with a real choice at 55 to 65.
- A. 32 / 42 / 52 / 62 (rating spec, tuned to the reference model).
- B. 25 / 30 / 36 / 42 (current building data, easier).
- C. Keep both as placeholders until the closed test shows how many players reach tier 4.
- Recommended: A for the data files, then adjust after playtest (open-questions.md item 1 says change them if fewer than 1 in 4 testers reach tier 4 in the target session time).

**Q2. Does a hole count toward the hole-count gate (6 / 10 / 14 / 18) when it is "dead" (score below 25)?**
- A. No, only valid holes with score 25 or more count (stops padding with junk holes).
- B. Yes, any valid hole counts.
- Recommended: A.

**Q3. Should the number the player sees be the raw hole score?** A plain hole shows about 37 out of 100, which may feel harsh.
- A. Show the raw score (0 to 100).
- B. Show a display-only curve (stored score unchanged).
- Recommended: A for now; revisit after the 10-player test in open-questions.md item 2.

## B. Economy numbers

**Q4. Start cash and the first purchase.** Economy rebalance (DEC-066, `docs/phase1/economy.md`): start cash 50,000 dollars; first holes cost 5,000 growing 10 percent each; parcels 8,000 growing 15 percent per parcel; building prices follow the payback targets 10/12/16/50/80 days (first Clubhouse tier costs a few hundred dollars).
- A. Keep 40,000 and tune with the economy simulation (DEC-023).
- B. Lower start cash so the first purchase lands within about 5 minutes of play (economy interface rule).
- Recommended: A until the economy simulation exists, then let the simulation set it.

**Q5. Building cost curve across tiers.** Data uses multipliers 1, 2, 4, 8, 14 (DEC-023). The old plan used 1, 2.5, 6, 14, 32.
- A. 1, 2, 4, 8, 14 (current).
- B. 1, 2.5, 6, 14, 32 (old plan; 83 percent of spend in tiers 4 and 5, with payback of 200 to 3000 days).
- Recommended: A.

**Q6. Green fee range for players.** Placeholder 5 to 250 dollars.
- A. 5 to 250.
- B. 5 to 100 (harder to break the economy).
- Recommended: A, since remote config can clamp it later.

**Q7. How long is one game day in real time?** The economy and tournament checkpoints assume 18 seconds at 1x speed (unconfirmed).
- A. 18 seconds at 1x.
- B. 30 seconds at 1x.
- C. 60 seconds at 1x.
- Recommended: A (matches the save and tournament assumptions), confirm on device in Phase 1.

**Q8. Bankruptcy behaviour.**
- A. Recovery offer (rule when cash and income cannot cover upkeep), no game over outside Tycoon mode.
- B. Hard game over in Tycoon mode only.
- C. No bankruptcy at all.
- Recommended: A.

**Q9. Are post-launch expansions paid or free (DEC-015)?**
- A. Free.
- B. Paid separately.
- C. Decide after launch.
- Recommended: C (does not block v1).

**Q10. Demo content.** Demo allows 9 holes, Clubhouse to tier 3, Pro shop and Driving range to tier 2 (PROP-06).
- A. Keep as is.
- B. Demo also allows Restaurant tier 1.
- Recommended: A.

## C. Land classes

**Q11. How many parcels and holes per parcel?** Data: 3 holes per parcel, start with 2 parcels, maximum 9, 16 parcels maximum in the course format.
- A. 3 holes per parcel, start 2, max 9.
- B. 2 holes per parcel, start 3, max 9 (finer land buying).
- Recommended: A.

**Q12. Do heavy buildings need one extra parcel (PROP-10)?** Heavy: Driving range, Pool and spa, Lodging, Homes, Landmark. Tier 5 needs 7 to 8 parcels.
- A. Yes, heavy buildings need one more parcel at tiers 2 to 5.
- B. No, all buildings use the same parcel requirement.
- Recommended: A.

## D. Analytics and privacy

**Q13. Analytics consent, by region.** Today the spec (PROP-04) uses the strictest reading: no events are created or stored before the player agrees, everywhere, and the code default is off (`MHAnalyticsService.enabled = false`). Legal advice is still needed for the store Data Safety form.
- A. Opt-in consent everywhere (strict, simplest, fewer data).
- B. Opt-in in the EU, UK and Australia; opt-out with notice elsewhere.
- C. No analytics in v1 (crash reports only, if any).
- Recommended: A. The game is adults-only declared, and one rule everywhere is the least work to get right.

**Q14. Where does the consent screen appear?**
- A. After the player has reached the editor and made the first stroke (spec rule: land in the editor in under 30 seconds).
- B. On first launch before anything else.
- Recommended: A.

## E. Save safety versus Ironman

**Q15. Is Ironman in v1?** RESOLVED: cut (DEC-058). Spec: one slot, autosave only, no manual backup or export, cloud copy is upload-only backup (PROP-07). It conflicts with the general rule "never lose a player's save".
- A. Include Ironman as an option; the cloud copy can restore only after the local file is missing.
- B. Include Ironman, but keep one hidden automatic backup the player can restore once.
- C. Cut Ironman from v1.
- Recommended: C for v1 (saves the work of a second rule set and protects reviews); if you want it, choose B.

**Q16. Cloud save conflict.** When the cloud copy has a higher revision than local.
- A. Always ask the player, showing day, cash, holes and time for both (current spec).
- B. Newest wins automatically.
- Recommended: A.

**Q17. A mid-day quit resumes at the start of that day (PROP-02).**
- A. Yes, no mid-day state saved (18 seconds lost).
- B. Save mid-day state.
- Recommended: A.

## F. Supabase and backend

**Q18. Supabase plan at launch.** The Master Plan launch checklist says free tier while its risks table says paid or keep-alive. Free projects can pause after inactivity.
- A. Free tier for the closed test, upgrade to the paid tier before public launch.
- B. Paid tier from the start.
- C. Free tier at launch with a scheduled keep-alive request.
- Recommended: A. Check the current pricing and pause rules on the Supabase site before deciding; the cost figures were not verified here.

**Q19. Is the daily challenge in v1?** Kept in v1 per DEC-016, though the pre-mortem suggested cutting it. Server checks are bounds and rate checks only (DEC-036).
- A. Keep, with remote kill switch on.
- B. Cut from v1.
- Recommended: A (already decided in DEC-016; asked here only because the plan text disagrees).

## G. Terrain and data details (technical, choose or delegate)

**Q20. Terrain surface list.** The course schema names 11 surface types (rough, fairway, first cut, green, fringe, tee, bunker sand, water, path, waste, dirt). The built terrain paints only 4 (fairway, rough, sand, green).
- A. Keep 4 paint layers for Phase 0 and derive the others from objects and shapes in the course data.
- B. Extend the terrain splat to more layers now.
- Recommended: A.

**Q21. Course and terrain hash.** Terrain saves use a 32-bit FNV-1a checksum of the heights.
- A. Keep the 32-bit hash for Phase 0 and add sha256 when leaderboards need tamper checks.
- B. Switch to sha256 now.
- Recommended: A.

**Q22. Store product id.** Code and platform status doc use `mh_full_unlock`; an older interface draft said `mh_unlock_full`. The id cannot be changed after creation in the stores.
- A. `mh_full_unlock` (code).
- B. `mh_unlock_full`.
- Recommended: A.

**Q23. Android package id / iOS bundle id.** Placeholder in code: `com.mulliganhills.game`.
- A. Keep.
- B. Choose another after the trademark check.
- Recommended: B if the trademark advice is not yet back; the id cannot be changed after publishing.

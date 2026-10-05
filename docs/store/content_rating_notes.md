# Content rating and target audience notes

Status: DRAFT 2026-10-04. These are my notes on how to answer the questionnaires truthfully for what the repository contains. **The answers are Nathan's declarations, made in the consoles, and must match the final build.** Re-answer if content changes. I cannot see the questionnaires from here, so question wording below is paraphrased (VERIFY each one in the console).

## What the game contains (checked against the repository on 2026-10-04)
- A stylized 3D golf course design and club management simulation. Characters are generic golfers.
- No violence, blood, weapons, horror, or fear content. Golfers can lose balls, hit trees, and miss putts; that is the only "conflict".
- No sexual content, nudity, suggestive themes.
- No profanity. Player text input does not exist (club names are presets, DEC-016/DEC-043); there is no chat. A keyword search of `event_cards.json`, `game/data/*.json` and `game/ui/mh_strings.gd` for alcohol, gambling, tobacco, fighting, death and swear words found nothing (2026-10-04, simple word search, not a content review). Content writers must re-check the 40 event cards and the clubhouse and restaurant text when they are final.
- No gambling, no real money wagering, no random-chance paid items (no loot boxes, no gacha). The one purchase is a fixed unlock. Event cards and tournaments use in-game randomness but cost no real money. If paid tokens ship (DEC-053) they buy only time speed ups and bankruptcy recovery, with a fixed price and fixed amount.
- No ads.
- No user-to-user communication. The daily leaderboard shows a preset club name and a score. No sharing of user-made content in v1 (DEC-016).
- No location access. No camera or microphone. Local notifications only.
- Real-world references: fictional courses, sponsors and brands only (DEC open item 9). A tournament ladder named local / regional / national / major does not name real tournaments; confirm the final names do not use real event trademarks (for example the names of real major championships).

## Google Play: content rating (IARC questionnaire)
Category: **Game**. Proposed answers: violence No; blood No; sexuality No; profanity No; controlled substances (alcohol, tobacco, drugs) No *unless a restaurant or clubhouse card mentions alcohol; check at content freeze*; gambling and simulated gambling No (a golf course management game with no betting or casino mechanics); fear / horror No; user-generated content shared with others No (presets only); users can interact or exchange content No; shares user location No; allows purchases Yes (the unlock; tokens if shipped); unrestricted internet access No; digital purchases Yes.
Expected outcome: the lowest age tier (IARC "3+" / ESRB "Everyone" / PEGI 3 are my expectation, not a promise: the system decides). The system may add an "In-app purchases" notice and "Users interact" is not triggered.
Action: Nathan completes it in Play Console > Policy > App content > Content rating, with the email he uses for the account; save the certificate PDF in the release folder.

## Google Play: target audience and content
Choose **18 and over** only (DEC-006 "adults-only audience declaration"). Effects (VERIFY): the app is not in the Designed for Families program; Play's Families policies do not apply; the child-directed data rules are not triggered; the store will not show it as a kids' app. Choosing an adult-only target age while the content rating is "Everyone" is allowed. Also answer "does your app appeal to children?" truthfully: a cartoon style 3D game might. Answer honestly; the console may then require more (VERIFY). Lawyer question: children's privacy law exposure (open question in `open_questions.md`).

## Apple App Store: age rating
Fill the Age Rating questionnaire in App Store Connect (new questions were introduced in 2025; VERIFY the current form). Proposed answers: Cartoon or fantasy violence None; realistic violence None; sexual content or nudity None; profanity or crude humor None; alcohol, tobacco or drug use None; mature or suggestive themes None; horror or fear None; medical themes None; gambling None (simulated gambling None); contests None; unrestricted web access No; in-app purchases Yes. Expect a low rating (4+). Whether to also set a manual higher rating or a "made for adults" position is Nathan's choice; keep it consistent with Play's 18+ audience statement (Apple has no direct equivalent of the Play target audience choice: VERIFY).

## Other ratings (only if you sell in those regions through the store)
Google Play's questionnaire produces ratings for ESRB, PEGI, USK, ClassInd and others automatically (IARC). Australia: the Play questionnaire includes the Australian Classification Board system (VERIFY). Do not apply separately for national classification unless a lawyer says so (for example Germany, South Korea game rating requirements can differ: VERIFY, open question 9).

## Consistency checks (do before every submission)
- Play target audience 18+ equals Apple choices equals the text in the privacy policy section 8 equals terms section 1.
- Screenshots show no real brands, no alcohol, no gambling, no violence.
- The store description does not promise anything the rating questionnaire denied (for example "bet", "wager", "casino").

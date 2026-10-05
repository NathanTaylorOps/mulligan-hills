# Closed test: recruiting and keeping 12 testers for 14 days

Status: DRAFT 2026-10-04. Why this exists: a new personal Google Play developer account (created after 2023-11-13) must run a closed test with at least 12 testers opted in for 14 continuous days before it can apply for production access (source: `docs/phase0/platform.md` section 4, from Google's help page; **VERIFY the current numbers and whether your account type is affected before you rely on this**, because Google has changed these rules before). The 14 days start counting only when at least 12 are opted in, and a tester who leaves can break the count. So plan for **20 to 25 sign-ups to keep 12 or more opted in the whole time.**

## 1. What a tester needs (put this in the invite)
- An Android phone or tablet with a Google account (Gmail) that is the main account on the device (internal and closed testing identify testers by Google account).
- 5 minutes to install, then 10 to 20 minutes of play on 3 or more different days.
- No payment: license testers get free test purchases (`docs/phase0/platform.md` C). Nathan adds the testers that will try the unlock purchase to the license tester list.
- To stay opted in for 14 days and not uninstall in the first few days. They can uninstall after day 14.
- Privacy: tell them exactly what the test build collects (usage statistics are off unless they switch them on; cloud features create an anonymous account) and that you keep their Gmail address only in the tester list and your recruitment tracker, and delete both after the test (say so, and do it).

## 2. Where to find 20 to 25 people (order = cheapest first)
| Source | Target sign-ups | How |
| --- | --- | --- |
| Personal circle: family, friends, colleagues and former colleagues from your work and Navy network who own Android phones | 8 to 12 | Direct message with the invite text below. Ask each for one more person (a friend who plays games) |
| Golf people: golf club members, driving range regulars, local golf Facebook groups or club newsletters (ask the committee first; do not spam) | 3 to 5 | Short post with the same text; golfers are the real audience |
| Tycoon and simulation game communities (subreddits and Discords for management or tycoon games, read the rules; many ban self-promotion without permission) | 3 to 5 | Offer a genuine devlog post with a screenshot and the invite link; accept the rules of each place |
| Tester-swap communities for Play closed testing (for example subreddits and Discord servers set up for swapping app tests: search "Android closed testing"; names and rules change; VERIFY each is real and read the rules) | 3 to 6 | You test their app, they test yours. Reciprocal testers often stay opted in; do the swaps promptly |
| Paid testing services | 0 | Not recommended: low quality feedback, may breach the store's rules on incentivised testing (VERIFY policy before any paid or incentivised recruiting) |

Do not use: bots, purchased reviews, fake accounts, or friends' accounts you control. Do not offer money or in-game advantages for staying opted in without checking the policy first (VERIFY).

## 3. Mechanics in Play Console
1. Create a Google Group or an email list of testers (Testing > Closed testing > your track > Testers). A Google Group makes adding people easy (testers join the group, no console edit needed). Name it e.g. `mulligan-hills-testers`.
2. Copy the **opt-in link** (web link or Play Store link) from the track page. Testers must open it **while signed in with the tester Google account**, press **Become a tester**, then install from the Play Store link.
3. Keep a tracker (spreadsheet, template in section 6): name or handle, Gmail, source, date invited, date opted in (Play Console shows the count), device, Android version, still opted in (check weekly), feedback received.
4. Check the opt-in count in the console every day for the first week. If it drops under 12, recruit immediately; the clock effectively resets for the missing days.

## 4. Timeline (T = the day the closed track is first available to testers)
| When | Task |
| --- | --- |
| T minus 28 to T minus 14 | Play account created and verified; first internal build tested on both phones; the privacy policy URL is live; draft invite and tracker ready |
| T minus 21 | Start recruiting. Goal: 25 names with Gmail addresses by T minus 7 |
| T minus 10 | Submit the closed track for review (the first review can take days; VERIFY). Add every tester to the list or group |
| T minus 3 | Reminder message to all names: "the link goes live on <date>" |
| T (day 0) | Send the opt-in link to everyone. Ask for opt in and install within 48 hours. Record the count |
| Day 1 to 3 | Chase the missing ones personally. Goal: 12 opted in by day 3, 20 by day 7. The **14 days count from when 12 are opted in** (check how the console shows it; VERIFY) |
| Day 3, 7, 10 | Short messages to the group: what to try today (see section 5), thank you, one question |
| Day 5 to 7 | Ship the first update from feedback (Google wants evidence you used the test; VERIFY). Tell testers "update available, please install" |
| Day 14 or the day the count is complete | Thank everyone. Ask them to stay opted in until production access is granted if you can (not required, but a drop below 12 before you apply might matter; VERIFY) |
| Day 14 plus | Apply for production access in the console. Answer the questions honestly: how many testers, how you recruited, what feedback you got and what you changed |
| After production approval | Tell testers; offer credit in the devlog (only if they want it) |

## 5. What to ask testers to do (and what to learn)
Each message gets ONE task so people actually do it.
- Day 0: install, finish the tutorial, paint one hole. Learn: does it install on their phone; how long to the first stroke (target under 30 s, DEC-032).
- Day 2: build your first building. Learn: is the first reward within 20 minutes; confusion points.
- Day 4: close the game completely, open it again, check your course is there. Learn: save safety.
- Day 6: try the daily challenge and look at the board. Learn: does the backend work for strangers.
- Day 8: try cloud save on a second device if they have one (or tell us "no second device"); learn about the conflict prompt.
- Day 10: reach the demo limit if you can and tell us how it felt. Learn: demo wall reaction (DEC-028), willingness to pay.
- Day 12: unlock the full game with the test purchase (license testers only) and then press Restore after a reinstall.
- Day 13: the feedback form (below).
Feedback form (keep it to 8 questions or fewer, a Google Form, no personal data beyond what they choose):
1. Phone model and Android version. 2. Did it install and run smoothly (1 to 5)? 3. Did you understand what to do in the first 10 minutes? 4. What was the best moment? 5. What was the most confusing or annoying moment? 6. Did the game ever crash, freeze or lose progress? What happened? 7. At what price, if any, would you buy the full game after this demo (options: under $2, $2 to $3.99, $4 to $4.99, $5 to $6.99, I would not buy)? 8. Anything else.
Careful with the price question: with 12 to 25 testers this is a weak signal (DEC-006: price provisional). Treat it as colour, not data.

## 6. Message templates
Invite (edit freely, keep it short and honest):
```
Hi <name>, I'm testing my first mobile game, Mulligan Hills, a golf course design tycoon for Android. Google needs 12 people to try it for two weeks before I can release it, so I'd really appreciate your help.
What it takes: an Android phone, 3 or 4 short play sessions (10 to 20 minutes) over two weeks, and staying signed up as a tester until <date>. I'll send one small task per message.
It's free. The only data it collects is optional anonymous usage statistics (off unless you switch them on), and I'll use your Gmail address only to add you as a tester and delete it when the test ends.
If you're in: open this link on your phone while signed in with your Gmail, press "Become a tester", then install: <link>. Thanks! Nathan
```
Nudge at day 3 for the not-yet-opted-in:
```
Hi <name>, quick reminder: the test link is open. It takes 2 minutes: <link> (press "Become a tester" first, then install). Reply if anything doesn't work and I'll sort it.
```
Weekly thanks plus task: one line of thanks, what changed in the new build, today's task.

## 7. Tracker columns
`name or handle | gmail | source | date invited | opted in (Y/N, date) | device and Android version | install ok | days active | still opted in (weekly check) | feedback received | follow-ups`

## 8. Risks
- Dropouts: the 12 people must STAY. Recruit double, check the count daily in week 1.
- Quiet testers: Google may care about real engagement; a tester who never opens the game is a risk. The daily challenge and a daily-use reason help (earned tokens for daily login exist in the design, DEC-053).
- Bad first impressions: do not start the 14 day clock with a build that crashes. Run the internal track on both phones first.
- Tester privacy: keep only what you need; delete the list after.
- Review wait for the closed track and for the production application are outside our control. Do not plan a launch date before both are done.

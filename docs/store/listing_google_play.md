# Google Play listing draft (en-US; copy for en-AU)

Status: DRAFT 2026-10-04. Text below is written to be pasted into Play Console > Grow > Store presence > Main store listing. Limits quoted are the limits I know (VERIFY in the console, they change). Features marked **[CONFIRM SHIPS]** must be removed if cut (DEC-039 lists the cut order: weather, photo mode, daily challenge, pace stat, ...).

## Basics
| Field | Value | Limit / note |
| --- | --- | --- |
| App name | `Mulligan Hills: Golf Tycoon` (27 characters) | 30 characters. Name is conditional on trademark clearance (DEC-001, `trademark_checklist.md`). Fallback: `Home Links: Golf Tycoon` |
| Short description | `Design golf holes, build a club, host tournaments. Free demo, one-time unlock.` (78) | 80 characters |
| App category | Game > Simulation | VERIFY the category list at upload |
| Tags | Simulation, Strategy, Sports (pick what the console offers) | |
| Contact email | a support address on a domain or Gmail you control (open question 5) | Required, shown publicly |
| Website | optional: GitHub Pages devlog | |
| Privacy policy URL | `https://<your-site>/privacy` (open question 3) | Required. Must be the lawyer-reviewed text |
| Price | Free, with in-app purchase. Product `mh_full_unlock`, 4.99 USD (provisional, DEC-006; fallback 3.99) | Price can be changed later; a free app cannot be turned into a paid app (VERIFY) |
| Contains ads | No | DEC-006 |
| In-app purchases label | Yes. Play shows a price range on the listing automatically | If token packs go on sale, they appear here too (open question 1) |

## Full description (limit 4000 characters; this draft is about 2,500)
```
Design the course. Build the club. Make the golfers talk about it.

Mulligan Hills is a golf course design tycoon. You start with a patch of land and a shovel. You shape the ground, place tees and greens, plant trees, dig water and bunkers, and send golfers out to play what you built. Every hole is rated, and the rating decides who comes, what they pay, and what you are allowed to build next.

DESIGN EVERY HOLE
- Paint fairways, rough, sand and water straight onto a 3D course with your finger.
- Raise and lower the ground, rotate the camera, and undo anything. One finger paints, two fingers move the view.
- Watch golfers play your hole and see where they succeed, struggle and lose balls.

A SCORE YOU CAN TRUST
- Each hole earns a score from 0 to 100, with clear reasons: accuracy, imagination, length, beauty and fairness.
- Fix what the advisor points out, or ignore it and design the hole your way. The score tells you how golfers felt about it.

GROW A CLUB
- Ten buildings, five tiers each: clubhouse, pro shop, driving range, restaurant, pool and spa, cart barn, maintenance, lodging, homes and a landmark.
- Buy land parcels to grow from a small plot to a full 18 hole course.
- Set your green fee, welcome members, and keep the books out of the red.

HOST TOURNAMENTS
- Climb from local events to regional, national and major tournaments, and unlock the top tier of every building.

EVERY DAY SOMETHING NEW
- Event cards and commissions keep each season different.
- A daily challenge gives everyone the same brief. Compare scores on the daily board. [CONFIRM SHIPS]
- Achievements to collect as your club grows.

PLAY YOUR WAY
- Plays fully offline. Cloud save is optional, and if your phone and the cloud disagree, the game always asks you which save to keep.
- No ads. No pop ups. Cash is earned in the game and never sold.
- Phone and tablet layouts, left handed mode, text size, and colour options.

FREE DEMO, ONE UNLOCK
The free demo gives you the full design tools, nine holes and several hours of play, and your saves carry straight into the full game. Unlock the full game once, with no subscription, to build all 18 holes, upgrade every building and host tournaments. Restore your purchase any time on a new phone.

PRIVACY
Usage data is off unless you switch it on. No account, name or email is needed to play. You can delete your cloud data inside the app at any time.

Mulligan Hills is a work of fiction. Courses, clubs, sponsors and characters in the game are made up.
```
Notes on the text:
- "Left handed mode", "text size" and "colour options" are in the Settings screen plan (`docs/phase1/ui.md`); CONFIRM SHIPS.
- "several hours" is DEC-028 "about 2 to 3 hours"; adjust after the closed test.
- Do not add competitor names, "best", "#1", download counts or ratings claims (Play metadata policy, VERIFY).
- If paid tokens ship (DEC-053), add one honest line under "PLAY YOUR WAY": `Optional token packs speed up time and help you recover from bankruptcy. Tokens never buy cash or progress. You also earn tokens by playing.` and delete "Cash is earned in the game and never sold" only if that sentence becomes untrue (tokens do not sell cash, so it stays true).

## Release notes (first closed test build, 500 characters max)
```
First test build of Mulligan Hills. Thank you for testing! Please try: designing a hole, watching golfers play it, buying your first building, and closing and reopening the game. Use Settings > Send feedback for anything odd. Known: art and sounds are still placeholders.
```
(Edit "Send feedback" to the real menu text, and the last line to the truth.)

## Graphic assets (all procedural art, DEC-062; nothing here exists yet)
| Asset | Size and rule (VERIFY in console) | Plan |
| --- | --- | --- |
| App icon | 512 x 512 PNG, 32 bit, under 1 MB | Rendered from the same procedural pipeline; test at 48 px |
| Feature graphic | 1024 x 500 PNG or JPEG | Course vista, logo left, no text smaller than 24 px, no store badges |
| Phone screenshots | 2 to 8, 16:9 or 9:16, 320 to 3840 px per side | See list below. CI already has a screenshots workflow (`.github/workflows/screenshots.yml`) |
| 7 inch and 10 inch tablet screenshots | recommended, same rules | Needed because tablets are a target (DEC-002) |
| Promo video | optional YouTube link | Skip for the closed test |

Screenshot list (caption text is added in the image, 3 to 6 words):
1. The editor with a half painted hole: "Paint the course yourself".
2. Golfers on a finished hole: "Watch them play it".
3. The rating panel with the five axes: "A score with reasons".
4. The build menu with tier pips: "Ten buildings to grow".
5. The land screen with parcels: "Buy land, build bigger".
6. The tournament screen: "Host real tournaments".
7. Daily challenge screen: "A new brief every day" [CONFIRM SHIPS].
8. The save conflict prompt: "Cloud save that asks first".
Rules: screenshots must show the real game (no mock ups that look like features that are missing), no device frames needed, no personal data, no store ratings.

## Store settings to set at the same time (details in `content_rating_notes.md`, `data_safety.md`)
Target audience 18 and over (DEC-006); ads: none; app access: all features available without a login (no special access instructions); content rating questionnaire; data safety form; privacy policy URL; account deletion URL (`web/delete-account.html` once hosted); in-app product `mh_full_unlock` active; countries: choose at the release step (open question 9); pricing template.

# Trademark and name clearance checklist: Mulligan Hills (fallback Home Links)

Status: DRAFT 2026-10-04. **This is a checklist for a human and an IP lawyer. It is not a clearance opinion, and nothing here says the name is available or safe.** DEC-001: the name is locked *conditional on clearance*; no branding spend before it passes. The Android package id (`com.mulliganhills.game`) and the product id cannot change after the first Play upload (DEC-060, Q23): the check must finish BEFORE the first upload.

## 0. What I did and did not do
- Did: one casual web search on 2026-10-04 for "Mulligan Hills" golf game app and "Home Links" golf game. Not a clearance search. It does not search trademark registries, does not cover phonetic or foreign variants, and a web search misses unregistered and registered marks alike.
- What it showed (pointers only, from search result titles; I did not open or verify the pages): several golf-related apps and games use "Mulligan" or "Mulligans" in their names, for example "The Mulligan App" (Google Play), "Mulligan Pro" (App Store), "Mulligans Golf Game" (Steam), "Mulligan: The Golf App" (a website). No result for the exact name "Mulligan Hills" appeared in those first results. For "Home Links" no exact-name game appeared, but the word "Links" is crowded in golf apps, and a St Andrews Links app uses the phrase "Home of Golf".
- Reading (mine, not legal advice): "Mulligan" appears to be a crowded term in golf software, so the added word "Hills" and the overall look carry the weight. A lawyer must judge how close those marks are in sound, look and meaning, and how the relevant registers treat them. "Home Links" has a similar descriptive-term problem in a different direction. The fallback is not automatically safer.

## 1. Define the claim
| Item | Value |
| --- | --- |
| Mark (word) | MULLIGAN HILLS (standard characters). Possible later: logo |
| Fallback | HOME LINKS |
| Goods and services (Nice classes) | 9 (downloadable game software and mobile apps); 41 (providing online non-downloadable games; entertainment); consider 28 only if merchandise; 35/42 not needed |
| Where you will sell | Start list in `open_questions.md` 9; at least Australia, USA, UK, EU, Canada, New Zealand |
| Owner | the business entity chosen (DECISIONS open item 8). A trademark must be filed by the right owner |

## 2. Searches to run and record (date, who, search string, result, link or screenshot)
Do each for the exact mark and for variants: MULLIGAN HILLS, MULLIGAN HILL, MULLIGAN HILLS GOLF, MULIGAN HILLS, MULLIGAN'S HILLS, and sound-alikes. For the fallback: HOME LINKS, HOMELINKS, HOME LINK.

| # | Where | What to look for | Done |
| --- | --- | --- | --- |
| 1 | IP Australia: Australian Trade Mark Search (VERIFY current name and address of the service) | identical or similar marks in classes 9, 41 (and 28) | [ ] |
| 2 | USPTO trademark search (the current system, VERIFY name) | same | [ ] |
| 3 | WIPO Global Brand Database | international registrations and designations | [ ] |
| 4 | EUIPO TMview (EU, UK and many national offices) | same | [ ] |
| 5 | UK IPO, CIPO (Canada), IPONZ (New Zealand) registers, if selling there | same | [ ] |
| 6 | Google Play search for "mulligan", "mulligan hills", "home links" (exact and partial) | live apps with similar names; note package ids | [ ] |
| 7 | Apple App Store search (web or an iPhone) for the same | same | [ ] |
| 8 | Steam, Epic, itch.io, Nintendo eShop, Xbox/PlayStation stores | games with similar names (names there can be cited against you even if registered nowhere) | [ ] |
| 9 | Web search (Google, Bing) with quotes, plus "golf", "game", "app", "tycoon" | companies using the name for golf or software; golf courses and clubs named Mulligan Hills or Home Links (real clubs may object to a game using their name) | [ ] |
| 10 | Social handles and domains: mulliganhills.com / .com.au / .app, @mulliganhills on the platforms you will use | availability; do not buy yet (see 5) | [ ] |
| 11 | Business and company name registers (ASIC business names, state Secretary of State, Companies House) | same name in use by a business | [ ] |
| 12 | Real place names: "Mulligan Hills" or "Home Links" as geographic or club names | descriptive or geographic arguments; real-world confusion | [ ] |
| 13 | Search your own listing text and screenshots against a list of competitor names | make sure nothing in the listing names another product | [ ] |

## 3. How to judge a hit (for the lawyer; I am not giving an opinion)
- Same or similar goods (games, apps)? Same or similar mark in look, sound, meaning, overall impression? Is the other mark registered, pending, or only used? In force in a country you will sell in? Is the shared word ("Mulligan", "Links") weak or descriptive in golf (many co-existing uses)? Is the other owner active? Has the other owner enforced before?
- Outcome categories to record per hit: ignore / low / medium / high risk, with the reason.

## 4. Decisions to make with the lawyer
1. Proceed with Mulligan Hills (and which classes and countries to file in), or switch to Home Links, or choose a third name.
2. A documented internal "knockout" search versus a "full clearance" (lawyer, paid). Cost and time: ask the lawyer for a quote (open question). I will not guess a figure.
3. Whether to file before the closed test (a cheap and early application, such as an Australian one, can establish priority; VERIFY with the lawyer) or after.
4. The legal owner (entity) that files and later holds the Play and Apple developer accounts (these should match).
5. The package id: keep `com.mulliganhills.game` only if the name is cleared; otherwise choose before the first upload (it cannot be changed). If the name might change, a neutral package id is safer (Q23 option B).

## 5. What NOT to spend until the check passes (DEC-001)
Paid art for the logo, merchandise, domain bundles, paid ads, trailers with the name on them, printed material. Free handle and domain reservation is the lawyer's call. Free devlog posts using the name carry a small risk; record the date they started (it can matter later).

## 6. Fallback test: Home Links
Run section 2 again for the fallback before you need it. A name that fails late costs a rename of: store listing, package id (cannot be changed on Play after upload; a changed id means a new app listing), icon and art, privacy policy, support email, in-game text keys, Supabase project display name (cosmetic). Estimated effort to rename in code: small, because strings are keyed (DEC-043); the package id is the real cost.

## 7. Record sheet (copy this table into a spreadsheet)
| Date | Searched by | Register / site | Search string | Class(es) | Hit? | Hit details (mark, owner, status, goods) | Risk (ignore/low/med/high) | Evidence (link or screenshot file) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |

## 8. Other IP checks (cheap, do alongside)
- Rating axis names (Accuracy, Imagination, Length, Beauty, Fairness) shown to the IP lawyer (DECISIONS open item 9).
- Sponsor and brand names inside the game must be fictional; run each through the same web search.
- Third-party assets: procedural art only (DEC-062) so no asset licences; fonts and audio are in `docs/LICENSE_LEDGER.md`.
- Game mechanics similar to older simulation games: copyright protects code and art, not general mechanics, but a lawyer should confirm there is no patent or trade dress concern (open question 15).

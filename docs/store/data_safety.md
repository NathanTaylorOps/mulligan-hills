# Data safety (Google Play) and privacy label (App Store): answers and the data inventory behind them

Status: DRAFT 2026-10-04. **Not legal advice. Not verified by a lawyer.** The Play Data safety form and the App Store privacy label are legal statements to the store and to users: a wrong answer can get an app rejected or removed. Section 1 is facts about what the code in this repository does (so the answers can be checked against it); sections 2 to 4 are my proposed answers from those facts; section 5 is what I could not decide. Category names and form wording are as I remember them and MUST be checked against the live form (VERIFY).

## 1. Data inventory (what is actually collected, where it lives, how long)
Source of truth: `supabase/migrations/*.sql`, `supabase/functions/*`, `docs/spec/data/analytics_catalog.json`, `game/platform/`. "Server" = our Supabase project (host region chosen in setup; open question 8).

| # | Data | Collected when | Where it lives | Retention | Deleted by |
| --- | --- | --- | --- | --- | --- |
| D1 | Anonymous account id (random UUID, no email, no name, no password) | First time the player uses cloud save, daily challenge, or transfer code (CONFIRM with the client team: whether the game signs in at first launch or on demand) | Supabase Auth | Until deleted. **No inactivity expiry exists** (open question 10) | Delete account (in app or web) |
| D2 | Cloud save files: course geometry and terrain, buildings, cash and club state, progress. No unlock, no typed text (names are presets) | Only if cloud save is used | Private Storage bucket `cloud-saves` + table `cloud_saves` (summary: day, cash, holes, play time, app version) | Until deleted; one file per slot, up to 5 slots | Delete slot, delete account |
| D3 | Daily challenge entry: score 0 to 1000, preset club name number, template id, engine versions, content hash, app version, UTC date, attempt count, timestamps | When the player submits a daily score | Table `daily_scores` | 30 days (nightly cleanup) | Delete account; cleanup |
| D4 | Analytics events, only if the player opted in (DEC-057): event name, time, random install id, random session id, app version, platform (android/ios), build (demo/full), a few whole-number or fixed-choice props (for example building id and tier, fps bucket, thermal bucket, quality tier) | Only after opt-in | Table `analytics_events` (no access from the app) | 180 days (nightly cleanup) | Opt-out or reset sends an erase request by install id; cleanup. No account link |
| D5 | Purchase verification: sha256 hash of the Google purchase token, product id, Google order id, test flag, counts, first and last seen | When the player buys or restores the unlock | Table `purchase_verifications` | 400 days after last use | Not tied to an account; cleanup only (open question 11) |
| D6 | The purchase token itself and the Play Integrity token | Sent to `verify-purchase` / `verify-integrity` over HTTPS and forwarded to Google | Not stored by us. Function logs may hold the verdict summary (reasons only, no tokens) | Supabase log retention (VERIFY) | n/a |
| D7 | Transfer code (hash only) | When the player asks for a code | Table `transfer_codes` | 15 minutes, cleaned after 1 day | Used up, replaced, or cleaned |
| D8 | Technical request logs: IP address, user agent, time, URL, status | Every request to Supabase | Supabase platform logs and Auth audit data | Set by Supabase (VERIFY; flag to lawyer) | Platform retention |
| D9 | Play Games Services leaderboards, Play Billing, Play Integrity data | If the player signs in to Play Games / buys | Google (Google is the controller of its own services) | Google's policies | Google |
| D10 | Crash and ANR data | Android vitals (Play Console) for users who opted in at the OS level. We run no crash SDK (decision pending, DEC-044) | Google | Google | Google |
| D11 | Support emails | When the player writes to us | Our mailbox | While needed (state a period) | On request |
| D12 | In-app feedback text | **UNKNOWN: the feedback screen exists in the UI list, but no code or table receives its text** (open question 12). The analytics event `feedback_sent` carries no text | none yet | | |

Not collected at all (checked in the code and schemas): name, email, phone, address, precise or approximate location, contacts, photos, microphone, advertising id, hardware ids (IMEI, serial, Android id), installed apps list, payment card details, push tokens (notifications are local only), any free text typed by the player, health data.

## 2. Google Play Data safety form: proposed answers
Form section: **Data collection and security.**

| Question | Answer | Why |
| --- | --- | --- |
| Does your app collect or share any of the required user data types? | Yes | D1 to D5 |
| Is all of the user data collected by your app encrypted in transit? | Yes | Every call is HTTPS (Supabase, Google APIs) |
| Do you provide a way for users to request that their data be deleted? | Yes | In-app Settings > Delete account; web page `web/delete-account.html` (needs a code from the app; support email fallback). Analytics erase on opt-out |
| Data deletion URL | the hosted URL of `web/delete-account.html` | |
| Committed to follow the Play Families Policy | No | Target audience 18 and over (DEC-006) |
| Independent security review | No | |

Data types (answer each as: Collected / Shared, Optional?, Purpose):

| Play category > type | Collected? | Shared? | Optional? | Purposes | Data in this inventory |
| --- | --- | --- | --- | --- | --- |
| Personal info > User IDs | Yes | No | Yes (only if cloud features are used) | App functionality; Fraud prevention, security, and compliance (leaderboard, abuse limits); Account management | D1 (anonymous account id) |
| App activity > Other actions | Yes | No | Yes | App functionality (cloud save, daily board) | D2 game progress, D3 daily entry. Category choice is my best guess; there is no "game save" type (VERIFY Google's examples) |
| App activity > App interactions | Yes | No | Yes (opt-in, off by default) | Analytics | D4 |
| App info and performance > Diagnostics | Yes | No | Yes (opt-in) | Analytics; App functionality (performance tuning) | D4 perf_sample (fps bucket, thermal bucket, quality tier) |
| Device or other IDs | Yes | No | Yes (opt-in) | Analytics | D4 install id and session id (random, resettable, not an advertising id) |
| Financial info > Purchase history | Yes | No | Yes (only buyers) | App functionality; Fraud prevention, security, and compliance | D5 order id, product id, token hash |
| Everything else (Location, Contacts, Photos and videos, Audio, Messages, Health and fitness, Web browsing, Calendar, Files and docs, Financial: payment info, credit score, other; Personal info: name, email, address, phone, race, politics, sexual orientation, religion, other) | No | | | | |

"Shared" is No for every type because data goes only to our hosting provider (Supabase) acting on our behalf, which Google's definition excludes from "sharing" as I understand it (VERIFY the exact wording and have the lawyer confirm). If a third party analytics or crash tool is added later, this changes.
"Collected, but processed ephemerally" does not apply: nothing here is only held in memory.

## 3. Things Google may ask that follow from the answers
- App content > **Privacy policy**: URL of the lawyer-reviewed policy (`privacy_policy_DRAFT.md` after review). The policy and this form must say the same thing.
- App content > **Account deletion** (appears when the app lets people create accounts): give the web URL; explain that deleting removes D1 to D3 and D7; purchases belong to the Google account and are not touched.
- **Ads**: none.
- **Government, financial features, health, news, COVID**: not applicable. Declare "no".
- **Advertising ID declaration**: the app does not use the advertising id (Android 13 permission `AD_ID` should NOT be requested; check the merged manifest of the final AAB: some libraries add it silently; VERIFY).

## 4. App Store privacy label (when the iPhone build ships)
All types below are "linked to the user's identity" unless stated; "tracking" is **No** for all (nothing is used to track across other companies' apps, no advertising id, no data broker). Have the lawyer confirm every row.

| Apple data type | Collect? | Linked to user? | Used for | Source |
| --- | --- | --- | --- | --- |
| Identifiers > User ID | Yes | Yes | App functionality | D1 |
| Identifiers > Device ID | Yes (random install id, opt-in) | Not linked is arguable; answer Linked to be safe | Analytics | D4 |
| Usage data > Product interaction | Yes (opt-in) | Linked (same reasoning) | Analytics | D4 |
| Diagnostics > Performance data | Yes (opt-in) | Linked | Analytics, App functionality | D4 |
| Purchases > Purchase history | Yes | Linked | App functionality | D5 |
| Other data types | Yes (game progress, scores) | Linked | App functionality | D2, D3 |
| Contact info, Health, Financial info (payment), Location, Sensitive info, Contacts, User content (photos, audio, gameplay content, customer support), Browsing history, Search history | No (support emails are "Customer support" under User content: answer Yes if the lawyer says so) | | | |

## 5. Questions I could not settle (also in `open_questions.md`)
1. Whether IP addresses in platform logs (D8) must be declared as collected (Play: "approximate location"? Apple: "coarse location"?). My understanding is that Google treats data only processed in transit and not stored as ephemeral, but Supabase does store logs. Lawyer.
2. Category for game saves (D2) and daily entries (D3).
3. Whether the random install id (D4) must be declared as "Device or other IDs" (I did, conservatively).
4. Whether collecting the support email address needs its own line.
5. Consent evidence: only a `consent_decision` event with `analytics: true` is ever stored; a "no" leaves no record (by design). The local setting is the only proof of a "no". Lawyer: is an opt-in record sufficient where the law requires proof of consent (GDPR, UK GDPR)?
6. Children: adults-only is a declared audience (DEC-006), but a cartoon golf game can attract minors; Australia's children's privacy code applicability is still open (DECISIONS open item 8).
7. Whether to expire inactive anonymous accounts (see D1) and after how long.

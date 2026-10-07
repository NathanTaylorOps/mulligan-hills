> **DRAFT FOR LAWYER REVIEW. NOT LEGAL ADVICE. DO NOT PUBLISH AS IS.**
> Working draft based on the documented game/backend data flows as of 2026-10-04. It has not been reviewed by qualified legal counsel and is not publication-ready. Items in [SQUARE BRACKETS] are placeholders or review questions. Facts must be reconciled with the release-candidate binary, live backend, `docs/store/data_safety.md`, target regions and current store requirements before approval.

# Mulligan Hills Privacy Policy

Effective date: [DATE]. Version: [1.0 draft].

## 1. Who we are
Mulligan Hills ("the game") is published by [LEGAL ENTITY OR SOLE TRADER NAME, ABN/COMPANY NUMBER] ("we", "us"), [ADDRESS]. Contact for privacy questions: [PRIVACY EMAIL]. [LAWYER: confirm the correct publisher entity, whether a representative is needed in the EU/UK, and whether a data protection officer is required. The business entity is still undecided: DECISIONS open item 8.]

## 2. The short version
- You can play the whole game offline without giving us anything.
- We do not ask for your name, email address, phone number, location, contacts, photos or microphone.
- Usage statistics are off unless you turn them on. If you say no, nothing is sent.
- If you use cloud save or the daily challenge, the game creates a random anonymous account for you. It has no name and no email address.
- You can delete that account and its data inside the game at any time.
- The game has no ads, and we do not sell your data.

## 3. What we collect and why
| What | When | Why | How long we keep it |
| --- | --- | --- | --- |
| **Anonymous account ID** (a random number) | The first time you use cloud save, the daily challenge or a transfer code [CONFIRM when the game signs in] | To keep your cloud save and daily score tied to you without a name or email | Until you delete your account [LAWYER: inactivity period before we delete an unused anonymous account, for example 24 months; not built yet] |
| **Cloud save files**: your course (terrain and hole layout), buildings, money and progress. They do not contain your purchase or any name | If you turn on cloud save | So you can restore your game and move it to another phone | Until you delete the slot or your account |
| **Daily challenge entry**: your score, a preset club name number, which challenge, the game version, the date | When you submit a daily score | To show a leaderboard and limit cheating | 30 days |
| **Usage statistics (optional)**: which parts of the game you use, such as building upgrades, tutorial steps and general speed of the game (in ranges), the game version, whether your device is Android or iOS, a random install ID and a random session ID | **Only if you switch it on** on the first screen or in Settings | To fix problems and balance the game | 180 days. You can stop at any time in Settings; the game then asks us to erase the events linked to your install ID |
| **Purchase check**: when you buy or restore the full game, the game sends your Google Play purchase token to our server, which checks it with Google. We keep a one-way scrambled copy (hash) of the token, the product and order number, and a count of checks | When you buy or restore | To confirm you own the full game and to spot a single purchase being copied to many phones | Up to 400 days after the last check |
| **Device integrity check**: Google Play tells our server whether the app and device are genuine. We do not keep the token | When you buy, and possibly when you submit daily scores [CONFIRM] | To reduce cheating and fraud | Not kept [LAWYER: logs may keep the verdict] |
| **Technical request logs** (IP address, time, the address your game asked for, and the result) | Every time the game talks to our servers | Security and fixing faults | Kept by our hosting provider for its standard period [VERIFY with Supabase; LAWYER: state it] |
| **Messages you send us** (for example a support email) | If you write to us | To reply | [PERIOD] |

We do **not** collect: your name, email, phone number, address, location, contacts, photos, microphone, advertising ID, device serial numbers, your list of installed apps, payment card details, or text you type into the game (club names are chosen from a preset list).

[LAWYER: in-game feedback form. A feedback screen is planned. If it sends text to us, add it here, say where it goes and how long it is kept. Today no backend receives it.]

## 4. Services we use (people who handle data for us or alongside us)
| Who | What for | Notes |
| --- | --- | --- |
| **Supabase** (database, file storage, sign in, server functions), data hosted in [REGION] | Running cloud save, the daily challenge, optional statistics, purchase checks | Acts on our behalf. [LAWYER: processor agreement, international transfers] |
| **Google Play** (Google Play Billing, Play Games Services leaderboards if you sign in to them, Play Integrity, Android vitals crash reports) | Payments, leaderboards, device checks, crash reports | Google handles this data under its own privacy policy. We never see your card details |
| **Apple App Store** (iPhone version, later) | Payments | Apple's privacy policy applies |
| [Any analytics, crash or email tool added later] | | Must be listed here before it ships (DEC-044) |

We share information when the law requires it, to protect rights and safety, or if the business is sold [LAWYER].

## 5. Where your data goes
Our servers are in [REGION]. If you are outside that region your data is transferred there. [LAWYER: cross-border transfer wording for Australia, the EU/UK and the US.]

## 6. Your choices and rights
- **Turn statistics on or off:** Settings > Privacy.
- **Delete your cloud data and account:** Settings > Delete account. This removes your anonymous account, cloud saves, daily entries and transfer codes. It does not delete the save files on your phone, and it does not cancel or refund a purchase (purchases belong to your Google or Apple account).
- **Delete without the game:** open [DELETION PAGE URL] and enter a transfer code created in the game within the last 15 minutes, or email [PRIVACY EMAIL] [LAWYER: how we verify an anonymous account owner; today the only proof available is a code from the game].
- **Access, correction, portability, objection:** because accounts are anonymous we can only find your data if you give us your install ID or a code from the game. Email [PRIVACY EMAIL]. [LAWYER: rights wording by region: APPs 12 and 13, GDPR Articles 15 to 22, CCPA/CPRA.]
- **Complaints:** to us first; you may also complain to [Office of the Australian Information Commissioner / your local data protection authority].

## 7. Legal basis (EU and UK users)
Cloud save and the daily challenge: needed to provide the features you ask for. Usage statistics: your consent, which you can withdraw at any time. Purchase check and security logs: our legitimate interest in preventing fraud and keeping the service secure. [LAWYER: confirm.]

## 8. Children
The game is intended for adults aged 18 and over and is not directed at children. We do not knowingly collect data from children. [LAWYER: Australian Children's Online Privacy Code applicability, COPPA and age assurance wording. DEC-006 declares an adults-only audience but the game is a cartoon-style game that could attract younger players.]

## 9. Security
Data is sent over HTTPS. Database tables have row level security and the app cannot read other players' data or any statistics. No system is perfectly secure. [LAWYER: breach notification wording (Notifiable Data Breaches scheme, GDPR).]

## 10. Changes
We will post changes here and update the date. If a change matters, the game will tell you. [LAWYER]

## 11. Contact
[PRIVACY EMAIL], [POSTAL ADDRESS].

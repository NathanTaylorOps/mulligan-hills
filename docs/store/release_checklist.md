# Release checklist: Google Play (Android first), then App Store

Status: DRAFT 2026-10-04. Tick items as done and write the date. "VERIFY" = confirm in the console or in Google's current documentation; policies and numbers change. Nothing here has been done yet.
Release gating is defined by `docs/QUALITY_GATES.md` and the exact release-candidate evidence in `docs/VERIFICATION.md`.

## A. Identity and accounts (start now: these are the longest waits)
- [ ] Decide the publisher: personal or registered business entity, and tax setup (DEC-044: decide BEFORE store payout setup; DECISIONS open item 8). The developer account type decides whether the 12 testers rule applies (the current Play Console requirements: personal accounts created after 2023-11-13 need it; VERIFY current rule).
- [ ] Create the Google Play developer account (fee one-time, VERIFY amount). Complete identity verification and the payments profile. Date approved: ______
- [ ] Choose the support email (a dedicated address; shown publicly) and set up a mailbox that is checked daily during testing and launch.
- [ ] Domain or hosting for the privacy policy, terms and the account deletion page (GitHub Pages is enough, `docs/phase0/platform.md`). URLs: privacy ______ terms ______ deletion ______
- [ ] (Later, iPhone) Apple Developer Program enrolment (annual fee, VERIFY), a cloud Mac build service (DEC-017).

## B. Name and legal (before the first upload)
- [ ] Trademark knockout search done and recorded (`trademark_checklist.md`); lawyer outcome: Mulligan Hills approved / switch to Home Links / other. Date ______
- [ ] Final package id chosen and written in `mh_platform_config.gd` and the Supabase secret `ANDROID_PACKAGE_NAME` (cannot change after upload).
- [ ] Privacy policy and terms reviewed by a lawyer, edited, published at the URLs above. Policy matches `data_safety.md` and the live backend.
- [ ] Data safety form answers confirmed by the lawyer (`data_safety.md`).
- [ ] Children's privacy question answered (Australian code, COPPA): written advice saved.
- [ ] Decide analytics consent wording per region (DECISIONS open item 7, DEC-057 says opt-in everywhere).

## C. Backend ready (`supabase/SETUP.md`)
- [ ] Supabase project created, migrations applied, functions deployed, secrets set, Parts 1 to 6 of the guide done.
- [ ] Anonymous sign-ins on. Row level security shown ON for every table. Bucket `cloud-saves` private.
- [ ] Play service account created, linked, permissions granted; `verify-purchase` works with a licence tester purchase (this can take 24 to 48 hours to start working: UNVERIFIED, `supabase/functions/README.md`).
- [ ] Kill switch rehearsal: switch `daily_challenge` and `cloud_sync` off and on again, and confirm the game reacts (Part 6 test 4, then in the game).
- [ ] Rollback rehearsal: `select public.mh_rollback_remote_config();` works; know how to un-publish a staged rollout in Play Console (DEC-044).
- [ ] Web account deletion page hosted and tested end to end with a test account (the 15 minute code).
- [ ] Before PUBLIC launch: Supabase paid plan switched on (DEC-059), backups confirmed, usage limits checked.
- [ ] Nightly cleanup scheduled (guide Part 8).

## D. Build
- [ ] Target API level meets the current Play requirement (the repository notes API 36 from 2026-08-31 with an extension to 2026-11-01; VERIFY today's rule). `targetSdkVersion` set in the Godot export preset.
- [ ] Play Billing Library version 8 or later (notes: 7 and older deprecated; VERIFY). Billing plugin API verified on a real device (`docs/phase0/platform.md` section 4 item 1).
- [ ] Release build is an Android App Bundle (.aab), signed with the upload key (the Android platform setup), Play App Signing accepted. Keystore backed up in two places.
- [ ] 64-bit builds included (VERIFY).
- [ ] Merged manifest checked for unwanted permissions: no `AD_ID`, no location, no storage, no contacts; `POST_NOTIFICATIONS` only if local notifications ship. Record the final list in `data_safety.md`.
- [ ] Version name and version code scheme chosen. Version code increases with every upload.
- [ ] Gate 0 results on the low-end phone (30 fps floor, 20 minute soak, thermal) recorded; settings 30/60/Auto implemented (DEC-047).
- [ ] No debug code, no test keys: `MHPlatformConfig` has the real Supabase URL, anon key and entitlement PUBLIC key; the test key `test_public.pem` is not used.
- [ ] Offline test: airplane mode, demo works, unlocked game works from the cached entitlement.
- [ ] Save safety tests green (kill during save, `.bak` fallback); a cloud conflict prompt test on two devices.
- [ ] Account deletion in the app tested on a fresh install.
- [ ] Analytics: first-launch consent screen shows, "No" sends nothing (check server table stays empty), "Yes" stores events.

## E. Play Console setup (per app)
- [ ] Create app: name, default language, Game, Free, declarations.
- [ ] Set up your app checklist: privacy policy URL; ads (No); app access (all features available); content rating questionnaire (`content_rating_notes.md`); target audience 18+; data safety form (`data_safety.md`); government apps (No); financial features (No); health (No); account deletion URL.
- [ ] In-app product `mh_full_unlock` created exactly, price 4.99 USD, active (`docs/phase0/platform.md` B). If token packs ship: consumable products created and server verification built first (not built yet; open question 1).
- [ ] Main store listing complete: `listing_google_play.md` text, icon, feature graphic, screenshots (phone and tablets).
- [ ] Countries and regions chosen; pricing set. Sales tax and payout profile complete.
- [ ] Release notes written.

## F. Testing tracks (see `tester_recruitment_plan.md`)
- [ ] Internal testing (up to 100 testers, no review wait in my understanding; VERIFY): upload first signed AAB, install from the opt-in link on both test phones (S22 Ultra and the low-end phone, DEC-046), test a license-tester purchase, restore, kill switch, cloud save, daily challenge. Date ______
- [ ] Closed testing: create the track, add the tester list (Google Group or email list), upload the build, submit for review. Recruit and confirm 12 or more testers opted in. **Start date of the 14 continuous days: ______ End date: ______**
- [ ] During the 14 days: ship at least one update from tester feedback (Google asks how you tested and what you changed when you apply for production; VERIFY the questions), keep a feedback log.
- [ ] Apply for production access in the console after day 14. Date applied ______ Date granted ______ (Google reviews the application; time varies; VERIFY).
- [ ] Optional: open testing for a wider audience before production.

## G. Go live
- [ ] Pre-launch report from Play Console reviewed (automated device tests; fix crashes).
- [ ] Android vitals thresholds understood (crash and ANR rates, VERIFY the limits) and a crash dashboard watched (DEC-044).
- [ ] Production release as a **staged rollout**: 5%, then 20%, 50%, 100% only if crash and ANR rates and support mail look normal after each step (DEC-044). Pause or halt a rollout from the release screen.
- [ ] Remote config: kill switches all ON, `min_app_version` equal to the launch version.
- [ ] Support email monitored; reply templates ready; a refund and "restore purchase" answer ready.
- [ ] Devlog / announcement post (no claims beyond the listing). Reviews: reply politely; do not ask for only positive reviews (store policy, VERIFY).

## H. After launch (first 30 days)
- [ ] Day 1, 3, 7, 14, 30 checks: crash rate, ANR rate, conversion, day-7 retention (DEC-044 kill criterion example: under 8% after 3 months), server errors (Supabase logs), storage and database size (free vs paid limits).
- [ ] Price decision with closed test and early data (DEC-006 is provisional).
- [ ] Update `data_safety.md`, privacy policy and the Play forms before shipping any new data collection or SDK (DEC-044).
- [ ] Decide when to start the iPhone path: `verify-apple` (not written), Game Center plugin, App Attest, TestFlight, App Store review notes (`listing_app_store.md`).

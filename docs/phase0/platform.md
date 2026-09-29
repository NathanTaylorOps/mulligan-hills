# Workstream F: platform (billing, sign-in, integrity, notifications, analytics)

Owner: workstream F. Written 2026-09-29. Status: **code and notes written; NOTHING RUN on Godot, Android or a device.**
What WAS run: Python and Node checks of the token format (section 2).

## README block
- **Purpose:** prove a signed Android build with Google Play Billing, Play Games Services and a server-verified Play Integrity token is achievable, and design the iPhone equivalents, with all of it behind interfaces so gameplay code never touches a plugin.
- **Unlock model:** free demo + one non-consumable unlock (product id `mh_full_unlock`, USD 4.99). Entitlement belongs to the STORE RECEIPT, not the Supabase account. Verified online once, then cached as an RS256-signed token (`mh1...`) checked offline with an embedded public key, so demo and unlocked game both work offline.
- **Public API (GDScript, all `extends Node`, all in `game/platform/`):**
  - `MHEntitlementService`: `initialize()`, `is_unlocked()`, `await query_owned_products() -> PackedStringArray`, `purchase(product_id)`, `restore()`, `get_display_price()`, `on_account_deleted(clear_entitlement)`, `clear_local_cache()`, `get_cached_token()`; signals `entitlement_changed`, `owned_products_updated`, `purchase_finished(product_id, result, message)`, `restore_finished`.
  - `MHIntegrityService`: `prepare()`, `await request_token(request_hash) -> {ok, token, error}`, static `request_hash(parts)`.
  - `MHLeaderboardService`: `sign_in()`, `submit_score(board, score)`, `show_leaderboard(board)`.
  - `MHNotificationService`: `request_permission()`, `schedule(id, title, body, delay_seconds)`, `cancel(id)`, `cancel_all()`.
  - `MHAnalyticsService`: `set_enabled()`, `log_event()`, `set_user_property()`, `reset_identity()`.
  - `MHAccountService`: `request_account_deletion()` (hook; backend owns the deletion).
  - `MHPlatform`: factory (`create_*`) choosing mock vs real; `on_account_deleted(...)` helper.
- **How tests run:** gdUnit4 via workstream A's CI. Tests live in `game/platform/tests/` (see Risks: contract gave F no `game/tests/` path). Python/Node token checks run locally as in section 2.
- **Gate 0 addressed:** item 7 (see section 3).

## 1. What was built (files)
`game/platform/`
- `mh_platform_config.gd` (package id, product id, Supabase URL/anon key, cloud project number, entitlement public key placeholders)
- `mh_entitlement_service.gd` (interface + shared cache/verify logic), `_mock.gd`, `_android.gd`, `_ios.gd`
- `mh_entitlement_token.gd` (offline verifier), `mh_verify_api.gd` (HTTPS client for the Edge Functions)
- `mh_integrity_service.gd`, `_mock.gd`, `_android.gd`
- `mh_leaderboard_service.gd`, `_mock.gd`, `_android.gd`, `_ios.gd`
- `mh_notification_service.gd`, `_mock.gd`, `_native.gd`
- `mh_analytics_service.gd`, `_mock.gd`; `mh_account_service.gd`, `_mock.gd`; `mh_platform.gd`
- `examples/platform_example.tscn` + `.gd` (usage example, not a test)
- `tests/test_entitlement_token.gd`, `tests/test_platform_mocks.gd`, `tests/fixtures/{golden.json,test_public.pem}`

`android/`: `README.md` (Gradle notes and build steps), `plugin/` (Kotlin `MHPlayIntegrityPlugin.kt`, Gradle files, `addon_template/`), `manifest/AndroidManifest_additions.xml`, `proguard-rules.pro`.
`supabase/functions/`: `verify-purchase/`, `verify-integrity/`, `_shared/`, `README.md` (secrets and service account), `verify-purchase/make_golden.py`, `_shared/selftest.node.ts`.
`ios/README.md`: StoreKit, sign in, TestFlight notes (design only).

Design points worth knowing:
- Guards: every adapter checks `Engine.has_singleton(...)` and/or `ResourceLoader.exists(...)` and degrades to "cached entitlement only". Adapter code references plugin classes only through `load()` and string method names, so the project still parses on desktop without any addon.
- Every plugin-specific name in the Android billing adapter sits in a "PLUGIN SEAM" section at the bottom of the file, so a wrong name is a one-place fix.
- The token is verified by Godot `Crypto.verify` with an RSA public key. RS256 was chosen over Ed25519 because Godot's `Crypto` is RSA-only (as far as I know: unverified).
- Account deletion does NOT revoke the purchase (it belongs to the Play/Apple account). `on_account_deleted(clear_entitlement)` lets the caller wipe the cache; the user can then Restore.
- Refunds: not detected offline (accepted for USD 4.99). See supabase README "Known gaps".

## 2. How it is tested, and what has NOT been run
**Actually run (2026-09-29, sandbox):**
1. Python 3.11 + `cryptography` generated the golden vector (`make_golden.py`): RS256-signed `mh1` token, a tampered variant, test public key.
2. Node 22 ran `_shared/selftest.node.ts`: 13 checks PASS (sha256 hex vector, Play Integrity verdict policy for good, wrong hash, stale, emulator, basic-only, unlicensed, sideload, Play purchase-response interpretation for purchased/pending/wrong product).
3. The token signed by the TypeScript signer (`signEntitlement`) was verified by Python `cryptography` (PKCS1v15 + SHA-256). So TS signer and Python vector agree.
4. `keytool -genkeypair` command in "For Nathan" was executed with a throwaway keystore and produced a valid PKCS12 keystore with SHA1/SHA256 fingerprints.

**NOT RUN (all of it):** every `.gd` file, both gdUnit4 suites, the example scene, the Kotlin plugin (not compiled), both Edge Functions under Deno/Supabase (only the pure logic under Node), every call to a Google API, any Android/iOS build, any plugin. GDScript was written conservatively but has never been parsed by Godot.
The gdUnit4 golden test (`test_valid_token_verifies`) is the first thing CI should check: it proves Godot's `Crypto.verify` accepts a signature made outside Godot.

## 3. Gate 0 item 7 evidence and what needs a real device or account
`docs/phase0/GATE0.md` did not exist when this was written, so I use my own reading of item 7 ("signed Android build with Play Billing, Play Games Services and server-verified Play Integrity"). Workstream H should align the wording.

| # | Sub-check | Where it can be proven |
| --- | --- | --- |
| 7a | Interfaces + mocks parse and pass tests on desktop | CI (gdUnit4), no device |
| 7b | Golden token verifies in Godot `Crypto.verify` | CI (gdUnit4) |
| 7c | Edge Function logic tests (`selftest.node.ts`) | CI (Node step to add; workstream A) |
| 7d | Android AAB exports and is signed with the upload key; plugins bundled; merged manifest correct | CI could export an unsigned/debug build; signed release needs the keystore secret (Nathan) |
| 7e | Play Console app + in-app product exist, AAB accepted on internal testing track | **Needs Nathan's Google Play developer account** |
| 7f | Billing: product loads with price, test purchase completes, acknowledged, survives app restart | **Needs a real Android device (or Play-enabled emulator) + license tester account + app on a Play testing track** |
| 7g | Restore: reinstall or clear data, Restore returns the unlock | **Real device + Play account** |
| 7h | Refund/cancel of test purchase handled (token not issued for non-PURCHASED) | Real device; server logic partly proven by Node test |
| 7i | Play Games sign-in and one leaderboard score submit + show | **Real device, Play Games account, Play Console Games Services project, OAuth client with correct SHA-1** |
| 7j | Play Integrity: token obtained on device, decoded server-side, verdict PLAY_RECOGNIZED + MEETS_DEVICE_INTEGRITY, request hash matches | **Real device, Google Cloud project linked in Play Console, service account, deployed Supabase function, app installed from Play (internal track)** |
| 7k | Offline: airplane mode, demo works, unlocked game works from cached token | **Real device** (after 7f) |
| 7l | Local notification scheduled and delivered, permission flow on Android 13+ | **Real device** |
| 7m | Account deletion hook wired to a real backend deletion | Needs backend workstream + Supabase project |
| 7n | iPhone equivalents (TestFlight purchase, Game Center) | **Deferred**: needs Apple Developer account, Mac/Xcode, iPhone |

## 4. Unverified assumptions (check before trusting)
Verified this session by fetching the pages (summaries by a fetch tool, treat as good but not gospel):
- New apps and updates must target Android 16 (API 36) from 2026-08-31; extension to 2026-11-01 available. https://support.google.com/googleplay/android-developer/answer/11926878
- Play Billing Library: 5, 6 and 7 deprecated, **version 8 or later required** for new apps and updates from 2026-08-31 (extension 2026-11-01); v8 supported to 2027-08-31, v9 to 2028-08-31. https://developer.android.com/google/play/billing/deprecation-faq
- Official Godot billing plugin: docs at https://docs.godotengine.org/en/stable/tutorials/platform/android/android_in_app_purchases.html ; repo https://github.com/godot-sdk-integrations/godot-google-play-billing ; asset library entry shows 3.2.0 (2026-03-16, Godot 4.2+) https://godotengine.org/asset-library/asset/4137 ; the releases page summary lists 3.3.0 latest with Billing Library 9.1.0, 3.2.0 = 8.3.0, 3.0.0 = 8.0.0 (class-based `BillingClient`, autoload removed). https://github.com/godot-sdk-integrations/godot-google-play-billing/releases . Old 1.x plugin cannot be used for new apps after 2026-08-31 (issue #110).
- Play Integrity standard API: `IntegrityManagerFactory.createStandard`, `prepareIntegrityToken` with cloud project number, `request` with `requestHash` (<= 500 bytes), server decode via POST `playintegrity.googleapis.com/v1/{package}:decodeIntegrityToken`, replay protection automatic for standard requests. https://developer.android.com/google/play/integrity/standard ; verdict fields https://developer.android.com/google/play/integrity/verdicts
- Play Games Services plugin: godot-sdk-integrations/godot-play-game-services, Godot 4.3+, PGS SDK 21, Node-based, manual init, needs `godot_play_game_services/game_id` preset option and OAuth client SHA-1. https://github.com/godot-sdk-integrations/godot-play-game-services
- iOS `InAppStore` singleton API (methods and event dicts): https://github.com/godot-sdk-integrations/godot-ios-plugins/blob/master/plugins/inappstore/README.md
- Notification Scheduler plugin (Android + iOS), node `NotificationScheduler`: https://github.com/godot-sdk-integrations/godot-notification-scheduler
- New personal Play developer accounts (created after 2023-11-13) need a closed test with at least 12 opted-in testers for 14 continuous days before production access. https://support.google.com/googleplay/android-developer/answer/14151465

**UNVERIFIED (could not confirm; every one is flagged in the code):**
1. Billing plugin exact API: method names/args (`start_connection`, `query_product_details`, `query_purchases`, `purchase`, `acknowledge_purchase`), signal names other than `connected` and `on_purchase_updated`, signal payload dictionary keys (`response_code`, `purchases`, `product_ids`, `purchase_token`, `purchase_state`, `is_acknowledged`, `product_details`), enum values, addon script path `res://addons/GodotGooglePlayBilling/BillingClient.gd`, native singleton name. The docs pages returned only navigation to the fetch tool. `purchase()` signature changed in 3.2.0. **Action: vendor the addon in CI and diff against `_seam_*` functions.**
2. Play Games plugin class/method/signal names and script paths (adapter is a documented stub, `_seam_*` not wired).
3. Notification plugin `NotificationData` setters, addon paths, singleton names, whether iOS exposes the same node.
4. Which Godot 4.7.2 versions can target SDK 36 and the exact Android export preset option names; env var names for keystore (`GODOT_ANDROID_KEYSTORE_RELEASE_PATH/USER/PASSWORD`).
5. Play Developer API v3 endpoint shapes (`purchases/productsv2/tokens/{token}`, fields `purchaseStateContext.purchaseState`, `acknowledgementState`, `testPurchaseContext`, the `:acknowledge` endpoint) and the `tokenPayloadExternal` wrapper for Integrity decode: written from memory.
6. Play Integrity client library Gradle version (`com.google.android.play:integrity:1.4.0` is a placeholder), Gradle/AGP/Kotlin plugin versions, Godot AAR coordinates (`org.godotengine:godot`), EditorExportPlugin AAR path convention.
7. Godot API assumptions: `Crypto.verify(hash_type, hash, signature, key)` semantics, `CryptoKey.load_from_string(pem, true)`, awaiting multi-arg signals returns an Array, `Script.get_script_constant_map()`.
8. Integrity token freshness window (10 minutes) and that a sideloaded/emulator token is rejected as intended.
9. Play Console license testing menu location, 3-day acknowledge rule, service-account permission propagation time.
10. Apple side: InAppStore plugin StoreKit version, App Store Server API endpoint, Sign in with Apple requirement, Apple developer fee.
11. Google account-deletion policy URL cited in `mh_account_service.gd`.

## 5. Risks and follow-ups
- **Contract gap:** F owns no `game/tests/` path, so tests are in `game/platform/tests/`. Workstream A must add that folder to the gdUnit4 run (or the lead moves it).
- **Play developer account timing is the critical path.** A new personal account needs 12 testers opted in for 14 days before it can publish to production. That does not block Gate 0 (internal testing works earlier) but blocks launch. Start day 1.
- The Billing plugin is the riskiest unknown (API unconfirmed, library 8 or later mandatory). Fallback: write a small Kotlin billing plugin ourselves, mirroring `MHPlayIntegrityPlugin`, against Play Billing Library 8 or 9.
- Shared token: a cached token can be copied between devices of one user (or rooted-device tampering with a rewritten file is prevented by the signature, but copying is not). Accepted for USD 4.99. No purchase-token reuse counter yet.
- Refunds not revoked offline; no Real-time Developer Notifications yet.
- Integrity `INTEGRITY_MODE` defaults to `log`: legitimate rooted users are not locked out. Flip to `enforce` only after seeing real verdict data.
- iOS: verification server (`verify-apple`), Game Center plugin and App Attest are all undone.
- Analytics vendor undecided (mock only). A privacy/consent screen is needed before enabling any real vendor.
- The golden test key (`test_public.pem`) is test-only; the matching private key was deleted and is not committed.
- Fill `mh_platform_config.gd` placeholders (package id, Supabase URL/anon key, cloud project number, public key) before any real build. Package id cannot change after the first Play upload.

## 6. For Nathan
Do these in order. Nothing here costs anything except step 1 (a one-time Google registration fee, about USD 25: check the amount shown on screen). Do not share passwords or the keystore file with anyone, including me.

### A. Create a Google Play developer account
1. On a computer, open https://play.google.com/console/signup in Chrome, signed in to the Google account you want to own the game long term (create a dedicated Gmail such as `mulliganhills.dev@gmail.com` first if you prefer; it cannot be changed later).
2. Choose account type **Personal** (unless you have a registered company: then choose Organization; Organization accounts skip the 12-tester rule but need a D-U-N-S number).
3. Enter your legal name and address, accept the agreement, and pay the one-time registration fee.
4. Complete identity verification when asked (photo ID, and a phone number). Wait for the approval email. This can take days.
5. Write down the date you were approved. If it is a Personal account, plan for the 12-tester, 14-day closed test before production.

### B. Create the app and the one-time in-app product
1. Play Console > **Create app**. App name `Mulligan Hills`, default language English (Australia) or your choice, **Game**, **Free**, tick the declarations, **Create app**.
2. Choose the package name in your first upload. Use `com.mulliganhills.game` unless you decide otherwise. **Tell me before you upload if you want a different one**: it can never be changed, and `mh_platform_config.gd` plus the Supabase secret must match.
3. Complete the "Set up your app" checklist on the dashboard (privacy policy URL, ads declaration: none, content rating questionnaire, target audience 13+ or higher (not children), data safety form). A privacy policy URL is required: a simple page on GitHub Pages is enough; ask me to draft the text.
4. Left menu > **Monetize with Play** > **Products** > **In-app products** > **Create product**. (If Google asks you to set up a merchant/payments profile first, do that: Settings > Payments profile.)
5. **Product ID: `mh_full_unlock`** (exactly; it cannot be changed or reused later). Name: `Full Game Unlock`. Description: `Unlock every course, tool and feature. One time purchase.`
6. Set the price to **USD 4.99** (Set price > pick country > adjust other countries' prices or accept the auto conversion) and **Activate** it.
7. Upload the first build later, per CI instructions, to **Testing > Internal testing** so the product becomes testable (billing only works on uploaded, signed builds).

### C. Create license testers
1. Make 2 or 3 Gmail addresses to test with (your own plus a spare). These become the accounts signed in on the test phone.
2. Play Console home (not inside an app) > **Settings** > **License testing** (location per Google docs: UNVERIFIED; if you can't find it, search "license testing" in the Console search bar).
3. Add those Gmail addresses to the **License testers** list, set **License response** to `RESPOND_NORMALLY`, and Save. Purchases by these accounts are free and are test purchases.
4. In the app > **Testing > Internal testing > Testers**, create an email list containing the same addresses, save, then copy the **opt-in URL**. Open that URL on the phone while signed in as the tester and press **Become a tester**.
5. The tester Google account must be the primary account on the phone (Settings > Google).

### D. Generate the upload keystore
Do this once, on your own computer, in a folder that is **not** inside the git repository (for example `C:\keys` or `~/keys`). You need Java installed (`keytool` comes with it); check with `keytool -help`.
1. Open a terminal in that folder.
2. Run exactly this (all one line; it will prompt you for a password twice, then ask for name fields: press Enter to skip them except the first and last):
```
keytool -genkeypair -v -storetype PKCS12 -keystore mulligan-upload.jks -alias mulligan-upload -keyalg RSA -keysize 2048 -validity 10000
```
3. When it asks "What is your first and last name?" type your name. For the confirmation type `yes`.
4. **Choose a long password and put it in a password manager now.** Losing the keystore or password means an upload-key reset request to Google (possible with Play App Signing, but slow).
5. Make two offline backups of `mulligan-upload.jks` (for example a USB stick and an encrypted cloud drive).
6. Print the fingerprints you will need for Play Games and Play Integrity setup:
```
keytool -list -v -keystore mulligan-upload.jks -alias mulligan-upload
```
   Copy the `SHA1:` and `SHA256:` lines into your password manager notes.
7. When you first upload to Play Console, accept **Play App Signing** (default). Afterwards go to **Setup > App signing** and copy the **App signing key certificate SHA-1** too; Play Games needs both SHA-1 values.

### E. Where to store secrets
| Secret | Store in | Never |
| --- | --- | --- |
| Keystore file `mulligan-upload.jks` and its password | Password manager + 2 offline backups. In GitHub: repository **Settings > Secrets and variables > Actions**: `ANDROID_KEYSTORE_BASE64` (output of `base64 -w0 mulligan-upload.jks` on Linux/Mac, or `certutil -encode` on Windows) and `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (= `mulligan-upload`). Ask workstream A/lead to wire them. | committed to git, emailed, pasted into chat |
| Google service account JSON key | Supabase: Project > Edge Functions > **Secrets** > add `GOOGLE_SERVICE_ACCOUNT_JSON` (paste the whole file). Keep a copy in the password manager. | in git, in the game, in the anon key |
| Entitlement private key (`entitlement_private.pem`) | Supabase secret `ENTITLEMENT_SIGNING_KEY_PEM` + password manager | in git, in the game |
| Entitlement PUBLIC key | Fine to commit: goes into `game/platform/mh_platform_config.gd` | n/a |
| Supabase **anon** key and project URL | Fine to put in `mh_platform_config.gd` (public by design) | Never use the Supabase **service_role** key in the game or in git |
| Play Games OAuth client id, game id | Fine in config/export preset (not secret) | n/a |

### F. Google Cloud, Play Integrity and service account (needed for check 7j)
1. https://console.cloud.google.com > create project `mulligan-hills`. Note its **Project number** (digits, on the dashboard: not the project id).
2. In that project: **APIs & Services > Library**: enable **Google Play Android Developer API** and **Play Integrity API**.
3. **IAM & Admin > Service Accounts > Create service account** `mh-verifier` (skip roles). Open it > **Keys > Add key > Create new key > JSON**. A file downloads: this is the secret from section E.
4. Play Console > **Users and permissions > Invite new users**: paste the service account email (`mh-verifier@...iam.gserviceaccount.com`), under **App permissions** add Mulligan Hills, and tick "View financial data, orders and cancellation survey responses" and "Manage orders and subscriptions". Invite. Access can take time to start working.
5. Play Console > your app > **Release > App integrity** (path may differ; UNVERIFIED) > link the Cloud project by its number. Put the digits into `CLOUD_PROJECT_NUMBER` in `mh_platform_config.gd`.
6. Generate the entitlement key pair using the two `openssl` commands in `supabase/functions/README.md`.
7. Supabase dashboard > Edge Functions secrets: add every row listed in `supabase/functions/README.md`. Deploy with the two `supabase functions deploy` commands there.

When steps A to D are done, tell me the package name you chose and the Supabase project URL; I will fill the config and the CI hand-off.

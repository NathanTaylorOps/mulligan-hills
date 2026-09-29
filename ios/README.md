# ios/ : iPhone platform notes (DESIGN ONLY, nothing built or run)

Phase 0 target is Android. iPhone follows. Everything below is a plan to keep the interfaces honest.

## Purchases (StoreKit)
- Option 1 (chosen for design): Godot's official iOS plugin `InAppStore` (godot-sdk-integrations/godot-ios-plugins,
  `plugins/inappstore`). README (fetched 2026-09-29): singleton `InAppStore`; methods `request_product_info`,
  `purchase`, `restore_purchases`, `set_auto_finish_transaction`, `finish_transaction`, `get_pending_event_count`,
  `pop_pending_event`; polled event dictionaries. It does NOT say StoreKit 1 or 2, nor which Godot 4.x versions. UNVERIFIED.
  https://github.com/godot-sdk-integrations/godot-ios-plugins/blob/master/plugins/inappstore/README.md
- Option 2 (candidates, unvetted): atlasapplications/godot-store-kit (https://github.com/atlasapplications/godot-store-kit),
  hrk4649/godot_ios_plugin_iap. Evaluate only if Option 1 fails on device.
- Adapter: `game/platform/mh_entitlement_service_ios.gd` (event polling written, server call TODO).
- Server: new Edge Function `verify-apple` calling the App Store Server API (`GET /inApps/v1/transactions/{transactionId}`,
  JWT signed with an App Store Connect API key) or verifying the JWS transaction locally with Apple's root certs; it returns the same `mh1`
  token with `pkg` = bundle id. Do NOT rely on the deprecated `verifyReceipt`. Endpoint names are from memory: UNVERIFIED.
- Restore Purchases button is mandatory for Apple review: `MHEntitlementService.restore()` exists for that.
- Product: non-consumable, product id `mh_full_unlock`, price tier equivalent to USD 4.99.

## Sign in / leaderboards
- Game Center for leaderboards. No first-party Godot 4 plugin confirmed. Candidate: sjc/godot-game-services (unvetted).
  Phase 0 decision: interface stub only (`mh_leaderboard_service_ios.gd`).
- Sign in with Apple is required by Apple if the app offers other third-party social sign-in for an account. If the account is
  email-only via Supabase, it is not required (verify current App Review Guideline 4.8: UNVERIFIED). Account deletion in-app is required.

## Integrity
- No Play Integrity equivalent shipped in Phase 0. iOS options: App Attest / DeviceCheck (needs a native plugin, not surveyed).
  Purchase trust on iOS comes from Apple's signed transactions instead.

## Local notifications
- `MHNotificationServiceNative` targets the Notification Scheduler plugin (has an iOS variant per its README).
  Needs the user permission prompt; no entitlements beyond default local notifications.

## TestFlight (steps, needs an Apple Developer Program account, USD 99/yr: verify price, UNVERIFIED)
1. Enrol at https://developer.apple.com/programs/ (individual is fine).
2. App Store Connect > Apps > + > New App; bundle id must match the Godot export preset.
3. Create the in-app purchase (non-consumable, id `mh_full_unlock`) and a Sandbox tester (Users and Access > Sandbox).
4. Godot iOS export produces an Xcode project (needs macOS with Xcode; CI uses a macOS runner). Archive and upload with Xcode or `xcrun altool`/Transporter.
5. TestFlight > Internal testing group > add testers. Sandbox purchases work in TestFlight builds.

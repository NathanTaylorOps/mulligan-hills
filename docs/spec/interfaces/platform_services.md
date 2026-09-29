# Interface: Platform services (`game/platform/`, owner F)

## Implemented API (Phase 0, reconciled 29 Sep 2026, NOT YET RUN; the code is authoritative)
`MHPlatform` is a STATIC FACTORY (`extends RefCounted`), not a Node autoload and not an object with `store()`/`games()` accessors. Each service is a separate `Node` subclass that the caller must `add_child()` before use. Mocks are chosen when the OS is not Android or iOS, or the user arg `--mh-mock-platform` is present.
```gdscript
class_name MHPlatform extends RefCounted
static func use_mocks() -> bool
static func create_entitlement() -> MHEntitlementService     # Mock / Android / IOS
static func create_integrity() -> MHIntegrityService         # Mock / Android; iOS returns the unsupported base class
static func create_leaderboard() -> MHLeaderboardService     # Mock / Android / IOS
static func create_notifications() -> MHNotificationService  # Mock / Native
static func create_analytics() -> MHAnalyticsService         # always MHAnalyticsServiceMock in Phase 0 (no vendor chosen)
static func create_account() -> MHAccountService             # Mock on desktop, base class otherwise
static func on_account_deleted(ent: MHEntitlementService, analytics: MHAnalyticsService, clear_entitlement: bool = false) -> void

class_name MHEntitlementService extends Node                 # replaces the drafted MHStoreService
enum PurchaseResult { OK, CANCELED, PENDING, ERROR, UNAVAILABLE, VERIFY_FAILED }
signal entitlement_changed(unlocked: bool)
signal owned_products_updated(product_ids: PackedStringArray)
signal purchase_finished(product_id: String, result: int, message: String)
signal restore_finished(success: bool, message: String)
func initialize() -> void
func query_owned_products() -> PackedStringArray             # coroutine friendly (await)
func purchase(product_id: String) -> void
func restore() -> void
func get_display_price(product_id: String) -> String         # "" if unknown, from the store
func on_account_deleted(clear_entitlement: bool = false) -> void
func is_unlocked() -> bool
func get_cached_token() -> String
func clear_local_cache() -> void
func needs_revalidation() -> bool

class_name MHEntitlementToken extends RefCounted              # signed entitlement token, prefix "mh1"
static func verify(token: String, public_key_pem: String, expected_pkg: String, expected_pid: String) -> Dictionary
static func needs_refresh(payload: Dictionary, now_unix: int) -> bool
static func b64url_decode(s: String) -> PackedByteArray

class_name MHIntegrityService extends Node
signal prepared(ok: bool, message: String)
func is_supported() -> bool
func prepare() -> void
func request_token(request_hash: String) -> Dictionary        # {"ok": bool, "token": String, "error": String}; coroutine (await)
static func request_hash(parts: PackedStringArray) -> String

class_name MHLeaderboardService extends Node                  # Play Games / Game Center LEADERBOARDS, no achievements API yet
signal sign_in_changed(signed_in: bool)
signal score_submitted(board: String, ok: bool)
func is_supported() -> bool
func is_signed_in() -> bool
func sign_in() -> void
func submit_score(board: String, score: int) -> void
func show_leaderboard(board: String) -> void

class_name MHNotificationService extends Node
signal permission_result(granted: bool)
signal notification_opened(id: int)
func is_supported() -> bool
func has_permission() -> bool
func request_permission() -> void
func schedule(id: int, title: String, body: String, delay_seconds: int) -> void
func cancel(id: int) -> void
func cancel_all() -> void

class_name MHAnalyticsService extends Node
var enabled: bool = false                                     # opt-in until a consent screen exists
func set_enabled(value: bool) -> void
func log_event(event_name: String, params: Dictionary = {}) -> void      # NOT validated against analytics_catalog.json in Phase 0
func set_user_property(key: String, value: String) -> void
func reset_identity() -> void

class_name MHAccountService extends Node
signal account_deleted(success: bool, message: String)
func is_signed_in() -> bool
func request_account_deletion() -> void

class_name MHVerifyApi extends Node                           # HTTPS client for Supabase Edge Functions
func verify_purchase(product_id: String, purchase_token: String, integrity_token: String) -> Dictionary   # await
func verify_integrity(integrity_token: String, action: String, nonce: String) -> Dictionary                # await

class_name MHPlatformConfig extends RefCounted                # non-secret constants
const PACKAGE_NAME = "com.mulliganhills.game"  (placeholder)
const PRODUCT_UNLOCK = "mh_full_unlock"        # THE store product id; the drafted "mh_unlock_full" is wrong
const SUPABASE_URL, SUPABASE_ANON_KEY, CLOUD_PROJECT_NUMBER, ENTITLEMENT_PUBLIC_KEY_PEM (all "" until filled)
const CACHE_PATH = "user://mh_entitlement.json"
const VERIFY_PURCHASE_PATH = "/functions/v1/verify-purchase"
const VERIFY_INTEGRITY_PATH = "/functions/v1/verify-integrity"
const HTTP_TIMEOUT_SECONDS = 20.0
static func verification_configured() -> bool
```
Each interface has `*Mock` classes (`MHEntitlementServiceMock`, `MHIntegrityServiceMock`, `MHLeaderboardServiceMock`, `MHNotificationServiceMock`, `MHAnalyticsServiceMock`, `MHAccountServiceMock`) and Android/iOS adapters (`MHEntitlementServiceAndroid` / `IOS`, `MHIntegrityServiceAndroid`, `MHLeaderboardServiceAndroid` / `IOS`, `MHNotificationServiceNative`). Plugin names and singletons inside the adapters are marked UNVERIFIED in code.

### Drafted facade members that do NOT exist (Phase 1 proposals, kept below for reference)
`MHPlatform` as a Node autoload with `store()`, `games()`, `device()`, `files()`, `cloud()`, `remote_config()`, `is_fake()`; `MHStoreService` (use `MHEntitlementService`); `MHGamesService` (achievements; only leaderboards exist); `MHDeviceService`; `MHFileService` (atomic file write exists only as `MHTerrainSave.write_atomic`); `MHCloudService`; `MHRemoteConfigService`; `MHResult`; `set_consent(granted)` (implemented as `set_enabled`); `track(name, props)` (implemented as `log_event`); `request_token(nonce)` with a `token_ready` signal (implemented as `request_token(request_hash) -> Dictionary`).

## Phase 1 draft (not implemented; superseded where the section above differs)

Purpose: one thin facade per external capability, so game code never touches a plugin directly and CI/desktop runs use fakes. All calls are asynchronous with a `completed` signal, or return immediately with a cached value. No call blocks the main thread.

```gdscript
class_name MHPlatform extends Node       # autoload "Platform"
func store() -> MHStoreService
func games() -> MHGamesService            # Play Games / Game Center: achievements only in v1
func integrity() -> MHIntegrityService
func device() -> MHDeviceService
func files() -> MHFileService
func cloud() -> MHCloudService            # Supabase client wrapper
func analytics() -> MHAnalyticsService
func remote_config() -> MHRemoteConfigService
func is_fake() -> bool                    # true on desktop/CI

class_name MHStoreService extends RefCounted
signal purchase_result(state: int, product_id: String)     # MHPurchaseState: NONE, PENDING, PURCHASED, CANCELLED, FAILED
signal entitlement_changed(unlocked: bool)
func start() -> void
func launch_unlock_flow() -> void                          # ONE non-consumable product "mh_unlock_full" (name pending store setup)
func restore() -> void                                     # queries owned purchases on every launch; also the Restore button
func is_unlocked() -> bool                                 # from the signed cached entitlement; verifies online when it can
func price_text() -> String                                # from the store, never hard-coded

class_name MHIntegrityService extends RefCounted
signal token_ready(ok: bool, token: String)
func request_token(nonce: String) -> void                  # Play Integrity (Android). App Attest later on iOS

class_name MHDeviceService extends RefCounted
func thermal_state() -> int                                # MHThermal.NORMAL, WARM, HOT (0 when unsupported)
func haptic(pattern: int) -> void
func safe_area_px() -> Rect2i
func quality_tier_hint() -> int                            # LOW, MEDIUM, HIGH from GPU/RAM buckets, overridable in settings
func open_url(url: String) -> void

class_name MHFileService extends RefCounted
func write_atomic(path: String, bytes: PackedByteArray) -> MHResult   # tmp, flush, verify, rename
func read_all(path: String) -> MHResult
func free_space_bytes() -> int

class_name MHCloudService extends RefCounted
signal sync_done(ok: bool, code: int)
func sign_in_anonymous() -> void
func link_google() -> void
func upload_save(slot: int, bytes: PackedByteArray, revision: int) -> void
func download_save(slot: int) -> void                      # result goes through save validation
func delete_account() -> void                              # in-app path required by store policy
func submit_daily(seed: int, payload: PackedByteArray) -> void   # payload carries rating_version, geometry, claimed result; never trusted by server

class_name MHAnalyticsService extends RefCounted
func set_consent(granted: bool) -> void                    # no events created or stored before consent
func track(name: String, props: Dictionary) -> void        # validated against analytics_catalog.json; unknown names or props dropped in release, asserted in debug

class_name MHRemoteConfigService extends RefCounted
signal updated(version: int)
func fetch() -> void
func get_config() -> Dictionary                            # last good config or bundled defaults, clamped per remote_config.schema.json
```

## Rules
- Entitlement is tied to the store receipt; cache is signed; Supabase account is not the source of truth. Some offline piracy is accepted.
- Unlock checks never go in save files.
- The `Fake*` implementations (desktop, CI) are part of this module so every other module's tests run without plugins.
- Plugin choices (billing, Play Games, Integrity) are decided in Phase 0 by F; the facade hides them.

## Consumers
UI shell, save/cloud sync, economy (fees only through remote config), analytics call sites.

## Contract tests
Fake store state machine (pending, purchased, restored), no unlock on PENDING, consent gating drops events, remote config clamp, atomic write kill test (Gate 0 item 10 with save).

# Interface: Platform services (`game/platform/`, owner F)

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

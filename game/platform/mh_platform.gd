class_name MHPlatform
extends RefCounted
## Factory. The ONLY place that decides mock vs real. Gameplay asks for an interface type.
## Mocks are used when: not Android/iOS, running in the editor, or the user arg `--mh-mock-platform` is present.

static func use_mocks() -> bool:
	if "--mh-mock-platform" in OS.get_cmdline_user_args():
		return true
	var os_name: String = OS.get_name()
	return os_name != "Android" and os_name != "iOS"

static func create_entitlement() -> MHEntitlementService:
	if use_mocks():
		return MHEntitlementServiceMock.new()
	if OS.get_name() == "Android":
		return MHEntitlementServiceAndroid.new()
	return MHEntitlementServiceIOS.new()

static func create_integrity() -> MHIntegrityService:
	if use_mocks():
		return MHIntegrityServiceMock.new()
	if OS.get_name() == "Android":
		return MHIntegrityServiceAndroid.new()
	return MHIntegrityService.new()  # iOS: unsupported in Phase 0

static func create_leaderboard() -> MHLeaderboardService:
	if use_mocks():
		return MHLeaderboardServiceMock.new()
	if OS.get_name() == "Android":
		return MHLeaderboardServiceAndroid.new()
	return MHLeaderboardServiceIOS.new()

static func create_notifications() -> MHNotificationService:
	if use_mocks():
		return MHNotificationServiceMock.new()
	return MHNotificationServiceNative.new()

static func create_analytics() -> MHAnalyticsService:
	return MHAnalyticsServiceMock.new()  # Phase 0: no vendor chosen; mock records in memory only

static func create_account() -> MHAccountService:
	return MHAccountServiceMock.new() if use_mocks() else MHAccountService.new()

## Call after a confirmed server-side account deletion.
static func on_account_deleted(ent: MHEntitlementService, analytics: MHAnalyticsService, clear_entitlement: bool = false) -> void:
	analytics.reset_identity()
	ent.on_account_deleted(clear_entitlement)

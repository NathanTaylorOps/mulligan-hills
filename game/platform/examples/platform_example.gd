extends Control
## Usage example (NOT a test). Shows gameplay-side use of the platform interfaces only.
## Runs on desktop with mocks: run this scene from the editor. On a device the factory picks adapters.

var _ent: MHEntitlementService
var _integrity: MHIntegrityService
var _leaderboard: MHLeaderboardService
var _notifications: MHNotificationService
var _analytics: MHAnalyticsService
var _account: MHAccountService
var _log: RichTextLabel

func _ready() -> void:
	_ent = MHPlatform.create_entitlement()
	_integrity = MHPlatform.create_integrity()
	_leaderboard = MHPlatform.create_leaderboard()
	_notifications = MHPlatform.create_notifications()
	_analytics = MHPlatform.create_analytics()
	_account = MHPlatform.create_account()
	for n: Node in [_ent, _integrity, _leaderboard, _notifications, _analytics, _account]:
		add_child(n)
	if _ent is MHEntitlementServiceAndroid:
		(_ent as MHEntitlementServiceAndroid).attach_integrity(_integrity)
	_build_ui()
	_ent.entitlement_changed.connect(func(u: bool) -> void: _say("entitlement_changed unlocked=%s" % u))
	_ent.purchase_finished.connect(func(p: String, r: int, m: String) -> void: _say("purchase_finished %s result=%d %s" % [p, r, m]))
	_ent.restore_finished.connect(func(ok: bool, m: String) -> void: _say("restore_finished ok=%s %s" % [ok, m]))
	_leaderboard.sign_in_changed.connect(func(s: bool) -> void: _say("sign_in_changed %s" % s))
	_analytics.set_enabled(true)
	_ent.initialize()
	_integrity.prepare()
	var owned: PackedStringArray = await _ent.query_owned_products()
	_say("owned=%s unlocked=%s price=%s" % [owned, _ent.is_unlocked(), _ent.get_display_price(MHPlatformConfig.PRODUCT_UNLOCK)])

func _build_ui() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(box)
	_add_button(box, "Buy unlock", func() -> void: _ent.purchase(MHPlatformConfig.PRODUCT_UNLOCK))
	_add_button(box, "Restore purchases", func() -> void: _ent.restore())
	_add_button(box, "Sign in (leaderboards)", func() -> void: _leaderboard.sign_in())
	_add_button(box, "Submit score 100", func() -> void: _leaderboard.submit_score("course_rating_best", 100))
	_add_button(box, "Ask notification permission", func() -> void: _notifications.request_permission())
	_add_button(box, "Schedule test notification (10 s)", func() -> void: _notifications.schedule(1, "Mulligan Hills", "Your course is ready", 10))
	_add_button(box, "Delete account (hook)", func() -> void: _delete_account())
	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_log)

func _add_button(parent: Node, text: String, cb: Callable) -> void:
	var b: Button = Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)

func _delete_account() -> void:
	var on_deleted: Callable = func(ok: bool, m: String) -> void:
		_say("account_deleted ok=%s %s" % [ok, m])
		if ok:
			MHPlatform.on_account_deleted(_ent, _analytics, false)
	_account.account_deleted.connect(on_deleted, CONNECT_ONE_SHOT)
	_account.request_account_deletion()

func _say(s: String) -> void:
	_log.append_text(s + "\n")

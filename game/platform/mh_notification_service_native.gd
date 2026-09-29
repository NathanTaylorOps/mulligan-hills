class_name MHNotificationServiceNative
extends MHNotificationService
## Android AND iOS adapter for the godot-mobile-plugins "Notification Scheduler" (same GDScript API on both).
## Source: https://github.com/godot-sdk-integrations/godot-notification-scheduler (fetched 2026-09-29).
## Documented surface: node NotificationScheduler; initialize(); schedule(NotificationData); cancel(id);
## create_notification_channel(NotificationChannel); has_post_notifications_permission();
## request_post_notifications_permission(); open_app_info_settings();
## signals: initialization_completed, notification_opened(data), notification_dismissed(data),
## post_notifications_permission_granted(name), post_notifications_permission_denied(name).
## NOT documented (UNVERIFIED): NotificationData / NotificationChannel builder methods, addon script paths,
## whether the iOS build exposes the same node. The build steps are in the PLUGIN SEAM.

const ANDROID_SINGLETON: String = "NotificationSchedulerPlugin"  # UNVERIFIED
const IOS_SINGLETON: String = "NotificationSchedulerPlugin"      # UNVERIFIED
const DATA_SCRIPT: String = "res://addons/NotificationScheduler/model/NotificationData.gd"      # UNVERIFIED
const NODE_SCRIPT: String = "res://addons/NotificationScheduler/NotificationScheduler.gd"       # UNVERIFIED
var _node: Node = null

func is_supported() -> bool:
	return ResourceLoader.exists(NODE_SCRIPT) and (Engine.has_singleton(ANDROID_SINGLETON) or Engine.has_singleton(IOS_SINGLETON))

func _ensure() -> bool:
	if _node != null:
		return true
	if not is_supported():
		return false
	var s: Script = load(NODE_SCRIPT) as Script
	_node = s.call("new") as Node
	add_child(_node)
	_node.call("initialize")
	if _node.has_signal("post_notifications_permission_granted"):
		_node.connect("post_notifications_permission_granted", func(_n: Variant) -> void: permission_result.emit(true))
		_node.connect("post_notifications_permission_denied", func(_n: Variant) -> void: permission_result.emit(false))
	return true

func has_permission() -> bool:
	return _ensure() and bool(_node.call("has_post_notifications_permission"))

func request_permission() -> void:
	if not _ensure():
		permission_result.emit(false)
		return
	_node.call("request_post_notifications_permission")

func schedule(id: int, title: String, body: String, delay_seconds: int) -> void:
	if not _ensure() or not has_permission() or delay_seconds < 1:
		return
	var data_script: Script = load(DATA_SCRIPT) as Script
	if data_script == null:
		return
	var d: Object = data_script.call("new") as Object
	# UNVERIFIED builder-style setters; adjust to the vendored addon.
	for m: Array in [["set_id", id], ["set_title", title], ["set_content", body], ["set_delay", delay_seconds]]:
		if d.has_method(m[0]):
			d.call(m[0], m[1])
		else:
			push_warning("NotificationData lacks %s" % m[0])
	_node.call("schedule", d)

func cancel(id: int) -> void:
	if _ensure():
		_node.call("cancel", id)

func cancel_all() -> void:
	push_warning("cancel_all: track scheduled ids and cancel individually (no documented cancel-all)")

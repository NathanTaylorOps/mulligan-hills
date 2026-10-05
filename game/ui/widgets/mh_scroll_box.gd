class_name MHScrollBox
extends ScrollContainer
## ScrollContainer that registers with MHTouchBridge for finger drag scrolling (mouse wheel and the scroll
## bar still work through the engine). Horizontal scrolling is off by default.

const GROUP: StringName = &"mh_scroll"


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _enter_tree() -> void:
	add_to_group(GROUP)

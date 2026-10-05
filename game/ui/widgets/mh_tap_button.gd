class_name MHTapButton
extends Button
## Button that works with raw touch. emulate_mouse_from_touch is OFF in project.godot, so a finger never
## produces the mouse event a normal Button waits for. Every MHTapButton joins the group GROUP; MHTouchBridge
## hit-tests raw InputEventScreenTouch against the group and emits `pressed` on a clean tap. Real mouse clicks
## still use the normal Button path (desktop dev builds), so one tap never fires twice.

const GROUP: StringName = &"mh_tap"

## Optional payload for handlers that share one callback (for example a tier or a speed).
var tag: Variant = null


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE


func _enter_tree() -> void:
	add_to_group(GROUP)


## Convenience factory. min_h is a UI-unit height (use MHUIContext.touch_min()).
static func make(text_value: String, variant: StringName, min_w: float, min_h: float) -> MHTapButton:
	var b: MHTapButton = MHTapButton.new()
	b.text = text_value
	if variant != &"":
		b.theme_type_variation = variant
	b.custom_minimum_size = Vector2(min_w, min_h)
	return b

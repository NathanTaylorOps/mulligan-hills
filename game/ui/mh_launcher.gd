extends Control
## Phase 0 scene launcher: the default main scene. One big button per scene that exists.
##
## Back-to-launcher convention: any scene may add a Button that calls
##   get_tree().change_scene_to_file(MHLauncher.LAUNCHER_PATH)
## (use the literal "res://ui/mh_launcher.tscn" if you do not want the dependency).
## Scenes must not be edited by the launcher; it only changes scene.

class_name MHLauncher

const LAUNCHER_PATH: String = "res://ui/mh_launcher.tscn"

## [label, path]. Order is display order. Missing scenes are hidden.
const SCENES: Array = [
	["Bench (forest + terrain)", "res://bench/bench_scene.tscn"],
	["Gesture sandbox", "res://input/mh_gesture_sandbox.tscn"],
	["Terrain demo", "res://terrain/demo/terrain_demo.tscn"],
	["Gate 0: sim hash", "res://gate0/sim_hash.tscn"],
	["Gate 0: terrain paint", "res://gate0/terrain_paint.tscn"],
	["Gate 0: save and kill", "res://gate0/save_kill.tscn"],
	["Gate 0: animation cost", "res://gate0/anim_cost.tscn"],
]


## Pure: entries whose path passes `exists`. `exists` is a Callable(String) -> bool.
static func filter_entries(entries: Array, exists: Callable) -> Array:
	var out: Array = []
	for e: Variant in entries:
		var entry: Array = e
		if entry.size() >= 2 and bool(exists.call(str(entry[1]))):
			out.append(entry)
	return out


static func available_scenes() -> Array:
	return filter_entries(SCENES, func(p: String) -> bool: return ResourceLoader.exists(p))


func _ready() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 16)
	scroll.add_child(box)

	var title: Label = Label.new()
	title.text = "Mulligan Hills: Phase 0"
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)
	var info: Label = Label.new()
	info.text = MHBuildInfo.label_text()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 22)
	box.add_child(info)

	var scenes: Array = available_scenes()
	if scenes.is_empty():
		var none: Label = Label.new()
		none.text = "No scenes found."
		box.add_child(none)
	for e: Variant in scenes:
		var entry: Array = e
		var b: Button = Button.new()
		b.text = str(entry[0])
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 30)
		b.pressed.connect(_open.bind(str(entry[1])))
		box.add_child(b)


func _open(path: String) -> void:
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("launcher: cannot open %s (error %d)" % [path, err])

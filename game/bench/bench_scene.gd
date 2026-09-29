class_name MHBenchScene
extends Node3D
## Benchmark scene root. Everything is built in code so bench_scene.tscn stays a one-node file.
## User args (after `--` on the command line): --tier=low|medium|high  --mode=quick|soak
## --autostart (start the bench immediately)  --seconds=N (override duration)  --no-adaptive
## --no-orbit

var tier_name: String = "medium"
var cfg: Dictionary = {}
var forest: MHForest
var water: MHWater
var golfers: MHGolfers
var rig: MHCameraRig
var light: DirectionalLight3D
var adaptive: MHAdaptiveScale = MHAdaptiveScale.new()
var runner: MHBenchRunner
var results: MHResultsScreen

var _hud_label: Label
var _tier_buttons: Array[Button] = []
var _run_buttons: Array[Button] = []
var _hud_accum: float = 0.0
var _last_us: int = 0
var _brush_enabled: bool = true
var _autostart_mode: String = ""
var _seconds_override: float = -1.0
var _meta: Dictionary = {}


func _ready() -> void:
	DisplayServer.screen_set_keep_on(true)
	var args: Dictionary = parse_user_args(OS.get_cmdline_user_args())
	tier_name = MHQuality.normalize_name(str(args.get("tier", "medium")))
	_seconds_override = float(args.get("seconds", -1.0))
	adaptive.enabled = not args.has("no-adaptive")

	_build_world()
	rig.orbit_enabled = not args.has("no-orbit")
	_build_hud()
	runner = MHBenchRunner.new()
	runner.context_cb = Callable(self, "_bench_context")
	runner.finished.connect(_on_bench_finished)
	add_child(runner)
	results = MHResultsScreen.new()
	add_child(results)
	_meta = MHBenchRunner.device_meta()
	apply_tier(tier_name)
	_last_us = Time.get_ticks_usec()
	if args.has("autostart"):
		var m: String = str(args.get("mode", "quick"))
		_start_bench(m)


## Parses ["--tier=low", "--autostart", ...] into {"tier": "low", "autostart": true}.
static func parse_user_args(argv: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for a in argv:
		var s: String = a
		if not s.begins_with("--"):
			continue
		s = s.substr(2)
		var eq: int = s.find("=")
		if eq < 0:
			out[s] = true
		else:
			out[s.substr(0, eq)] = s.substr(eq + 1)
	return out


func _build_world() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.75, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.6
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)

	light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	light.light_energy = 1.1
	add_child(light)

	var ground: MeshInstance3D = MeshInstance3D.new()
	var gp: PlaneMesh = PlaneMesh.new()
	gp.size = Vector2(500.0, 500.0)
	ground.mesh = gp
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_color = Color(0.26, 0.5, 0.22)
	gm.roughness = 1.0
	ground.material_override = gm
	add_child(ground)

	var fairway: MeshInstance3D = MeshInstance3D.new()
	var fp: PlaneMesh = PlaneMesh.new()
	fp.size = Vector2(320.0, 40.0)
	fairway.mesh = fp
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.albedo_color = Color(0.4, 0.68, 0.28)
	fm.roughness = 1.0
	fairway.material_override = fm
	fairway.position = Vector3(0.0, 0.05, -90.0)
	fairway.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fairway)

	forest = MHForest.new()
	forest.name = "Forest"
	add_child(forest)
	forest.build()

	water = MHWater.new()
	water.name = "Water"
	add_child(water)
	water.build()

	golfers = MHGolfers.new()
	golfers.name = "Golfers"
	add_child(golfers)
	golfers.build()

	rig = MHCameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.build()
	rig.camera.current = true


func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_hud_label = Label.new()
	_hud_label.position = Vector2(16.0, 12.0)
	_hud_label.add_theme_font_size_override("font_size", 26)
	_hud_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hud_label.add_theme_constant_override("shadow_offset_x", 2)
	_hud_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_hud_label)

	var bar: HBoxContainer = HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -110.0
	bar.offset_bottom = -12.0
	bar.offset_left = 12.0
	bar.offset_right = -12.0
	layer.add_child(bar)
	for t in MHQuality.TIERS:
		var b: Button = _make_button(str(t).capitalize())
		b.pressed.connect(_on_tier_pressed.bind(str(t)))
		bar.add_child(b)
		_tier_buttons.append(b)
	var q: Button = _make_button("Quick 60s")
	q.pressed.connect(_start_bench.bind("quick"))
	bar.add_child(q)
	_run_buttons.append(q)
	var s: Button = _make_button("Soak 20min")
	s.pressed.connect(_start_bench.bind("soak"))
	bar.add_child(s)
	_run_buttons.append(s)


func _make_button(text: String) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150.0, 90.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 26)
	return b


func _on_tier_pressed(t: String) -> void:
	if runner != null and runner.running:
		return
	apply_tier(t)


func apply_tier(t: String) -> void:
	tier_name = MHQuality.normalize_name(t)
	cfg = MHQuality.get_tier(tier_name)
	var errs: Array = MHQuality.validate(cfg)
	if not errs.is_empty():
		push_error("Invalid tier config: %s" % str(errs))
	MHQuality.apply_shadows(cfg, light)
	forest.apply_tier(cfg)
	water.apply_tier(cfg)
	golfers.apply_tier(cfg)
	var vp: Viewport = get_viewport()
	vp.msaa_3d = MHQuality.msaa_enum(int(cfg["msaa"])) as Viewport.MSAA
	adaptive.configure(cfg)
	adaptive.apply(vp)
	_brush_enabled = bool(cfg["foliage_dither"])
	print("MH_TIER ", tier_name, " ", JSON.stringify(cfg))


func _start_bench(mode: String) -> void:
	if runner.running:
		return
	results.visible = false
	for b in _tier_buttons:
		b.disabled = true
	for b in _run_buttons:
		b.disabled = true
	runner.start(mode, _seconds_override)


func _on_bench_finished(summary: Dictionary) -> void:
	for b in _tier_buttons:
		b.disabled = false
	for b in _run_buttons:
		b.disabled = false
	results.show_summary(summary)
	# Headless/CI style runs can pass --quit-after-bench to exit when done.
	if OS.get_cmdline_user_args().has("--quit-after-bench"):
		get_tree().quit()


func _bench_context() -> Dictionary:
	return {
		"tier": tier_name,
		"render_scale": snappedf(adaptive.current, 0.01),
		"renderer_active": str(_meta.get("renderer_active", _meta.get("renderer_setting", "unknown"))),
		"device": str(_meta.get("model", "")),
		"gpu": str(_meta.get("gpu", "")),
		"golfers_visible": golfers.visible_cap,
		"trees": forest.placed_tree_count(),
	}


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var ms: float = float(now - _last_us) / 1000.0
	_last_us = now
	var before: float = adaptive.current
	adaptive.step(ms)
	if adaptive.current != before:
		adaptive.apply(get_viewport())
	if _brush_enabled:
		forest.set_brush(rig.brush_position(), 14.0, 1.0)
	_hud_accum += ms
	if _hud_accum >= 500.0:
		_hud_accum = 0.0
		var t: String = ""
		if runner.running:
			t = "  bench %ds/%ds" % [int(runner.elapsed_s()), int(runner.duration_s)]
		_hud_label.text = "%s  %d fps  scale %.2f  draws %d  prims %d%s" % [
			tier_name, int(Engine.get_frames_per_second()), adaptive.current,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), t]

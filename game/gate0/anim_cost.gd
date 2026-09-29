extends Node3D
## Gate 0 item 9, COST HALF ONLY: N animated placeholder golfers using the procedural clips (walk, swing_full),
## measured with animation off then on. It does NOT retarget a licensed rig and there is no "celebrate" clip.
## See docs/phase0/gate0_scenes.md. NOT YET RUN.

const PHASE_SECONDS: float = 6.0
const WARMUP_SECONDS: float = 1.0
const COUNTS: Array[int] = [1, 5, 10, 20]

var _panel: MHGate0Panel
var _rigs: Array[MHGolferRig] = []
var _players: Array[AnimationPlayer] = []
var _animators: Array[MHGolferAnimator] = []
var _lib: AnimationLibrary = null
var _count: int = 20
var _anim_on: bool = true
var _swing_timer: float = 0.0
var _load_error: String = ""

# measurement state: 0 idle, 1 baseline (animation off), 2 animated
var _phase: int = 0
var _phase_time: float = 0.0
var _frame_off: MHGate0Stats = MHGate0Stats.new(3000)
var _frame_on: MHGate0Stats = MHGate0Stats.new(3000)
var _proc_off: MHGate0Stats = MHGate0Stats.new(3000)
var _proc_on: MHGate0Stats = MHGate0Stats.new(3000)
var _live: MHGate0Stats = MHGate0Stats.new(300)
var _hud_timer: float = 0.0


func _ready() -> void:
	_build_world()
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_panel = MHGate0Panel.new()
	_panel.setup("Gate 0: golfer animation cost (item 9, cost half)", "anim_cost", 0.0, 330.0)
	layer.add_child(_panel)
	for c: int in COUNTS:
		_panel.add_action(StringName("n%d" % c), "%d golfers" % c)
	_panel.add_action(&"toggle", "Animation: ON")
	_panel.add_action(&"measure", "Measure 12 s")
	_panel.action.connect(_on_action)
	_panel.show_result_box(false)
	_spawn(_count)


func _build_world() -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	ground.mesh = plane
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_color = Color(0.25, 0.55, 0.25)
	ground.material_override = gm
	add_child(ground)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	add_child(sun)
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.0, 9.0, 16.0)
	cam.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	cam.current = true


func _clear_golfers() -> void:
	for r: MHGolferRig in _rigs:
		r.queue_free()
	_rigs.clear()
	_players.clear()
	_animators.clear()


func _spawn(n: int) -> void:
	_clear_golfers()
	_count = n
	_load_error = ""
	var pos: PackedVector3Array = MHGate0AnimCost.layout(n, 5, 2.4)
	for i: int in range(n):
		var rig: MHGolferRig = MHGolferRig.new()
		add_child(rig)
		rig.position = pos[i]
		if not rig.load_model():
			_load_error = "MHGolferRig.load_model failed for golfer %d (see the debug log); is res://characters/golfer_placeholder.gltf imported?" % i
			rig.queue_free()
			break
		rig.apply_vertex_color_material()
		if _lib == null:
			_lib = MHProceduralSwing.build_library(rig.skeleton_track_path(), rig.capture_rest_rotations(), rig.hips_rest_position())
		var player: AnimationPlayer = rig.install_animations(_lib)
		var animator: MHGolferAnimator = MHGolferAnimator.new()
		rig.add_child(animator)
		animator.setup(player)
		animator.set_state(MHGolferAnimator.State.WALK if i % 2 == 0 else MHGolferAnimator.State.SWING_FULL)
		player.active = _anim_on
		_rigs.append(rig)
		_players.append(player)
		_animators.append(animator)
	_panel.set_live(_load_error if _load_error != "" else "%d golfers loaded" % _rigs.size())


func _on_action(id: StringName) -> void:
	var s: String = String(id)
	if s.begins_with("n") and s.substr(1).is_valid_int():
		_spawn(s.substr(1).to_int())
	elif id == &"toggle":
		_anim_on = not _anim_on
		_set_active(_anim_on)
		_panel.set_button_text(&"toggle", "Animation: ON" if _anim_on else "Animation: OFF")
	elif id == &"measure":
		_start_measure()


func _set_active(on: bool) -> void:
	for p: AnimationPlayer in _players:
		p.active = on


func _start_measure() -> void:
	if _rigs.is_empty():
		_panel.set_live("no golfers loaded: " + _load_error)
		return
	_frame_off.reset()
	_frame_on.reset()
	_proc_off.reset()
	_proc_on.reset()
	_phase = 1
	_phase_time = 0.0
	_set_active(false)
	_panel.set_live("phase 1 of 2: animation OFF (baseline) ...")


func _process(delta: float) -> void:
	var frame_ms: float = delta * 1000.0
	var proc_ms: float = float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	_live.add(frame_ms)
	if _phase != 0:
		_phase_time += delta
		if _phase_time > WARMUP_SECONDS:
			if _phase == 1:
				_frame_off.add(frame_ms)
				_proc_off.add(proc_ms)
			else:
				_frame_on.add(frame_ms)
				_proc_on.add(proc_ms)
		if _phase_time >= PHASE_SECONDS:
			if _phase == 1:
				_phase = 2
				_phase_time = 0.0
				_set_active(true)
				_panel.set_live("phase 2 of 2: animation ON ...")
			else:
				_phase = 0
				_set_active(_anim_on)
				_finish_measure()
	_swing_timer += delta
	if _swing_timer >= 3.0:
		_swing_timer = 0.0
		for i: int in range(_animators.size()):
			if i % 2 == 1:
				_animators[i].set_state(MHGolferAnimator.State.SWING_FULL, true)
	_hud_timer += delta
	if _hud_timer >= 0.5 and _phase == 0:
		_hud_timer = 0.0
		_panel.set_live("%d golfers  %s  process %.2f ms  draw calls %d" % [_rigs.size(), _live.live_line(), proc_ms,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])


func _finish_measure() -> void:
	var off_p: Dictionary = _proc_off.summary()
	var on_p: Dictionary = _proc_on.summary()
	var off_f: Dictionary = _frame_off.summary()
	var on_f: Dictionary = _frame_on.summary()
	var n: int = _rigs.size()
	var per_g: float = MHGate0AnimCost.per_golfer_ms(float(off_p["avg_ms"]), float(on_p["avg_ms"]), n)
	var lines: Array[String] = []
	lines.append(MHGate0Report.header_lines("golfer animation cost").strip_edges())
	lines.append("")
	lines.append("golfers: %d (half walk loop, half swing_full every 3 s). Clips: walk, swing_full. NO celebrate clip. NO licensed rig retarget." % n)
	lines.append("main-thread process time (Performance.TIME_PROCESS), avg ms per frame:")
	lines.append("  animation OFF %.2f    animation ON %.2f    delta %.2f" % [float(off_p["avg_ms"]), float(on_p["avg_ms"]), float(on_p["avg_ms"]) - float(off_p["avg_ms"])])
	lines.append("  per golfer (animation evaluation only): %.3f ms" % per_g)
	lines.append("  projected for 20 golfers: %.2f ms per frame" % MHGate0AnimCost.projected_ms(per_g, 20))
	lines.append("frame time (includes vsync wait): OFF avg %.1f fps p95 %.1f ms   ON avg %.1f fps p95 %.1f ms max %.1f ms" % [
		float(off_f["avg_fps"]), float(off_f["p95_ms"]), float(on_f["avg_fps"]), float(on_f["p95_ms"]), float(on_f["max_ms"])])
	lines.append("frames measured: OFF %d  ON %d" % [int(off_f["frames"]), int(on_f["frames"])])
	lines.append("Skinning is drawn either way (the pose is frozen, not hidden), so the delta is animation evaluation, not GPU skinning.")
	lines.append("If animation OFF is not lower than ON, TIME_PROCESS is not capturing the animation update; use the fps lines.")
	if _lib != null:
		lines.append("")
		lines.append("clip size (tracks / keys):")
		for clip: StringName in _lib.get_animation_list():
			var anim: Animation = _lib.get_animation(clip)
			var sz: Dictionary = MHGate0AnimCost.clip_size(anim)
			lines.append("  %s: %d tracks, %d keys, %.2f s" % [String(clip), int(sz["tracks"]), int(sz["keys"]), anim.length])
	lines.append("")
	var fields: Dictionary = {
		"golfers": n, "clips_measured": ["walk", "swing_full"], "celebrate_clip": false, "licensed_rig_retarget": false,
		"process_ms_off": off_p["avg_ms"], "process_ms_on": on_p["avg_ms"], "per_golfer_ms": snappedf(per_g, 0.001),
		"projected_20_golfers_ms": snappedf(MHGate0AnimCost.projected_ms(per_g, 20), 0.01),
		"fps_on_avg": on_f["avg_fps"], "frame_p95_ms_on": on_f["p95_ms"], "frame_max_ms_on": on_f["max_ms"],
		"note": "cost half of item 9 only; retarget half not done",
	}
	lines.append(MHGate0Report.to_json(MHGate0Report.evidence_now("09_retarget_cost_only", "incomplete", fields)))
	_panel.set_result("\n".join(lines))
	_panel.show_result_box(true)
	_panel.set_live("measurement finished")

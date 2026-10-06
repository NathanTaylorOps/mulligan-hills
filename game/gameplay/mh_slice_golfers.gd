class_name MHSliceGolfers
extends Node3D
## Draws the visual golfer groups of the vertical slice. READ ONLY with respect to the session: it is told
## where a group tees off and how long to run, it never sees or changes game state.
##
## Per frame: advance every golfer's cosmetic timeline (MHSliceRound), rank by camera distance
## (MHSliceVisibility), then draw
##   - the nearest few as MHGolferFigure joint puppets (12 draw calls each, posed directly with set_pose),
##   - the rest as ONE baked mesh each (MHGolferMeshes.build_posed, cached per look / LOD / frozen pose),
##   - the farthest not at all.
## Figures, baked MeshInstance3Ds and balls are pooled and hidden, never freed, while the scene runs.
## One shared vertex-colour material for everything. NOT YET RUN in Godot.

const LOOK_POOL: int = 12
const BAKED_LOD_NEAR: int = 1
const BAKED_LOD_FAR: int = 2
const BAKED_LOD_SWITCH_M: float = 70.0
const BALL_POOL: int = 6
## Frozen poses used for baked golfers: [name, clip, time].
const FRAMES: Array = [["idle", "idle", 0.0], ["walk_a", "walk", 0.25], ["walk_b", "walk", 0.75]]

var near_cap: int = 2
var total_cap: int = 10

## Golfers alive: Array of Dictionary {group, member, size, look, t, tee (Vector2), dir (Vector2), len, green (Vector2)}.
var golfers: Array = []
## Counts of the last draw, for the HUD and tests.
var last_figures: int = 0
var last_baked: int = 0
var last_hidden: int = 0

var _mat: Material
var _looks: Array = []
var _figures: Dictionary = {}
var _baked_cache: Dictionary = {}
var _baked_pool: Array = []
var _balls: Array = []
var _ball_mesh: Mesh
var terrain_grid: MHHeightGrid


func setup(material: Material) -> void:
	_mat = material
	for i: int in range(LOOK_POOL):
		_looks.append(MHGolferLook.from_seed(1000 + i))
	_ball_mesh = MHPropMeshes.build(MHPropMeshes.KIND_BALL, 1, 0)
	for i: int in range(BALL_POOL):
		var mi: MeshInstance3D = MHArtMaterials.make_instance(_ball_mesh, _mat, false)
		mi.visible = false
		add_child(mi)
		_balls.append(mi)


func set_caps(near: int, total: int) -> void:
	near_cap = maxi(0, near)
	total_cap = maxi(0, total)


## Adds one group that teed off just now. tee and green are world x,z in metres.
func spawn_group(serial: int, size: int, tee: Vector2, green: Vector2, round: Dictionary = {}) -> void:
	var delta: Vector2 = green - tee
	var length: float = delta.length()
	var dir: Vector2 = Vector2(0.0, 1.0) if length < 0.001 else delta / length
	for member: int in range(size):
		golfers.append({"group": serial, "member": member, "size": size,
			"look": MHSliceSchedule.look_index(serial, member, LOOK_POOL), "t": 0.0,
			"tee": tee, "dir": dir, "len": length, "green": green,
			"events": (round.get("events", []) as Array).duplicate(true) if member == 0 else []})


func golfer_count() -> int:
	return golfers.size()


## Advance every golfer by `dt` visual seconds and redraw. cam_pos is the camera position in world space.
func advance(dt: float, cam_pos: Vector3) -> void:
	var live: Array = []
	var states: Array = []
	for g: Variant in golfers:
		var d: Dictionary = g
		d["t"] = float(d["t"]) + maxf(dt, 0.0)
		var st: Dictionary
		var events: Array = d.get("events", []) as Array
		if not events.is_empty():
			st = _authoritative_state(events, float(d["t"]), int(d["member"]), int(d["size"]))
		else:
			st = MHSliceRound.state(float(d["t"]), int(d["member"]), int(d["size"]), float(d["len"]))
		if bool(st.get("done", false)) or int(st.get("phase", -1)) == MHSliceRound.Phase.DONE:
			continue
		live.append(d)
		states.append(st)
	golfers = live
	_render(states, cam_pos)


func _authoritative_state(events: Array, t: float, member: int, size: int) -> Dictionary:
	var stagger: float = float(member) * 0.35
	var timeline: Dictionary = MHAIRoundTimeline.state(events, maxf(0.0, t - stagger))
	if bool(timeline.get("done", false)):
		return {"done": true, "phase": MHSliceRound.Phase.DONE, "clip": MHGolferPoses.CLIP_IDLE,
			"clip_t": 0.0, "aim": false, "ball_u": -1.0, "world": Vector2.ZERO}
	var x0: float = float(int(timeline["x0"])) * 0.009144
	var y0: float = float(int(timeline["y0"])) * 0.009144
	var x1: float = float(int(timeline["x1"])) * 0.009144
	var y1: float = float(int(timeline["y1"])) * 0.009144
	var u: float = float(timeline.get("u", 0.0))
	var phase: String = str(timeline.get("phase", "address"))
	var world: Vector2 = Vector2(x0, y0)
	if phase == "walk" or phase == "putt":
		world = Vector2(x0, y0).lerp(Vector2(x1, y1), u)
	var clip: String = MHGolferPoses.CLIP_IDLE
	if phase == "swing":
		clip = MHGolferPoses.CLIP_SWING
	elif phase == "walk":
		clip = MHGolferPoses.CLIP_WALK
	elif phase == "putt":
		clip = MHGolferPoses.CLIP_PUTT
	return {"done": false, "phase": MHSliceRound.Phase.WALK, "clip": clip, "clip_t": t,
		"aim": phase != "walk", "ball_u": u if phase == "flight" else -1.0, "world": world,
		"ball_from": Vector2(x0, y0), "ball_to": Vector2(x1, y1)}


func _render(states: Array, cam_pos: Vector3) -> void:
	var positions: Array = []
	var dist2: Array = []
	var looks: Array = []
	for i: int in range(golfers.size()):
		var d: Dictionary = golfers[i]
		var st: Dictionary = states[i]
		var p2: Vector2
		if st.has("world"):
			p2 = st["world"] as Vector2
		else:
			p2 = MHSliceRound.ground_point(d["tee"] as Vector2, d["dir"] as Vector2, float(st["along"]),
				int(d["member"]), int(d["size"]))
		var p3: Vector3 = Vector3(p2.x, 0.0, p2.y)
		p3 = MHClubPedestrian.apply_ground_height(p3, terrain_grid)
		positions.append(p3)
		dist2.append(p3.distance_squared_to(cam_pos))
		looks.append(int(d["look"]))
	var vis: PackedInt32Array = MHSliceVisibility.classify(dist2, looks, near_cap, total_cap)
	last_figures = MHSliceVisibility.count_state(vis, MHSliceVisibility.FIGURE)
	last_baked = MHSliceVisibility.count_state(vis, MHSliceVisibility.BAKED)
	last_hidden = MHSliceVisibility.count_state(vis, MHSliceVisibility.HIDDEN)
	var used_figures: Dictionary = {}
	var baked_used: int = 0
	var balls_used: int = 0
	for i: int in range(golfers.size()):
		var state: int = vis[i]
		if state == MHSliceVisibility.HIDDEN:
			continue
		var d2: Dictionary = golfers[i]
		var st2: Dictionary = states[i]
		var dir: Vector2 = d2["dir"] as Vector2
		var yaw: float = MHSliceRound.facing_yaw(dir.x, dir.y, bool(st2["aim"]))
		var pos: Vector3 = positions[i] as Vector3
		if state == MHSliceVisibility.FIGURE:
			var look_i: int = int(d2["look"])
			var fig: MHGolferFigure = _figure_for(look_i)
			fig.visible = true
			fig.position = pos
			fig.rotation = Vector3(0.0, yaw, 0.0)
			fig.set_pose(MHGolferPoses.sample(str(st2["clip"]), float(st2["clip_t"])))
			used_figures[look_i] = true
		else:
			var mi: MeshInstance3D = _baked_node(baked_used)
			baked_used += 1
			var lod: int = BAKED_LOD_NEAR if dist2[i] < BAKED_LOD_SWITCH_M * BAKED_LOD_SWITCH_M else BAKED_LOD_FAR
			var baked: ArrayMesh = _baked_mesh(int(d2["look"]), lod, _frame_for(st2))
			if mi.mesh != baked:
				mi.mesh = baked
			mi.visible = true
			mi.position = pos
			mi.rotation = Vector3(0.0, yaw, 0.0)
		var u: float = float(st2["ball_u"])
		if u >= 0.0 and balls_used < _balls.size():
			var b: MeshInstance3D = _balls[balls_used] as MeshInstance3D
			balls_used += 1
			var tee: Vector2 = st2.get("ball_from", d2["tee"]) as Vector2
			var green: Vector2 = st2.get("ball_to", d2["green"]) as Vector2
			b.position = MHSliceRound.ball_point(tee, green, u)
			var ground: Vector3 = MHClubPedestrian.apply_ground_height(Vector3(b.position.x, 0.0, b.position.z), terrain_grid)
			b.position.y += ground.y
			b.visible = true
	for k: Variant in _figures.keys():
		if not used_figures.has(k):
			(_figures[k] as MHGolferFigure).visible = false
	for j: int in range(baked_used, _baked_pool.size()):
		(_baked_pool[j] as MeshInstance3D).visible = false
	for n: int in range(balls_used, _balls.size()):
		(_balls[n] as MeshInstance3D).visible = false


func _figure_for(look_index: int) -> MHGolferFigure:
	if _figures.has(look_index):
		return _figures[look_index] as MHGolferFigure
	var fig: MHGolferFigure = MHGolferFigure.new()
	fig.auto_advance = false # Posed directly each frame; the joint tree never self-animates.
	add_child(fig)
	fig.setup(_looks[look_index] as MHGolferLook, 0, _mat)
	_figures[look_index] = fig
	return fig


func _baked_node(index: int) -> MeshInstance3D:
	while _baked_pool.size() <= index:
		var mi: MeshInstance3D = MHArtMaterials.make_instance(null, _mat, false)
		mi.visible = false
		add_child(mi)
		_baked_pool.append(mi)
	return _baked_pool[index] as MeshInstance3D


## Index into FRAMES for a golfer state: walking alternates between two frozen steps, everything else idles.
static func _frame_for(st: Dictionary) -> int:
	if str(st["clip"]) == MHGolferPoses.CLIP_WALK:
		return 1 if fposmod(float(st["clip_t"]), 1.0) < 0.5 else 2
	return 0


func _baked_mesh(look_index: int, lod: int, frame: int) -> ArrayMesh:
	var key: String = "%d:%d:%d" % [look_index, lod, frame]
	if _baked_cache.has(key):
		return _baked_cache[key] as ArrayMesh
	var row: Array = FRAMES[frame] as Array
	var pose: Dictionary = MHGolferPoses.sample(str(row[1]), float(row[2]))
	var mesh: ArrayMesh = MHGolferMeshes.build_posed(_looks[look_index] as MHGolferLook, lod, pose)
	_baked_cache[key] = mesh
	return mesh


## Distinct baked meshes built so far (for tests and the HUD).
func baked_cache_size() -> int:
	return _baked_cache.size()

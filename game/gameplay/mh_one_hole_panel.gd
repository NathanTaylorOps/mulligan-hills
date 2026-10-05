class_name MHOneHolePanel
extends VBoxContainer
## Development controls for an exact player-edited short par 3. Not final phone UI or career golf.
var live: MHLiveConstruction
var length_yd: int = 60
var half_width_yd: int = 8
var water: bool = false
var _preview_draft: bool = false
var aim_x: int = 0
var aim_y: int = 6000
var _info: Label
var _world: Node3D
var _ball: MeshInstance3D
var _path: Node3D
var _feedback: Label
var _aim: MeshInstance3D
const ORIGIN: Array = [480, 340]

func setup(scene: MHLiveConstruction) -> void:
	live = scene
	position = Vector2(8, 285)
	add_child(MHUIKit.label("One-hole practice prototype — no prizes or XP"))
	_info = MHUIKit.label("")
	add_child(_info)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback = MHUIKit.label("Tap the course to aim. Play shot is a separate confirmation.")
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_feedback)
	size.x = maxf(240.0, get_viewport().get_visible_rect().size.x - 16.0)
	var design: HFlowContainer = MHUIKit.flow(6)
	add_child(design)
	_button(design, "Length -", func() -> void: length_yd = maxi(60, length_yd - 1); _draft_changed())
	_button(design, "Length +", func() -> void: length_yd = mini(62, length_yd + 1); _draft_changed())
	_button(design, "Narrow", func() -> void: half_width_yd = maxi(6, half_width_yd - 2); _draft_changed())
	_button(design, "Widen", func() -> void: half_width_yd = mini(14, half_width_yd + 2); _draft_changed())
	_button(design, "Side water on/off", func() -> void: water = not water; _draft_changed())
	_button(design, "Finalize / redesign", _finalize)
	var shots: HFlowContainer = MHUIKit.flow(6)
	add_child(shots)
	_button(shots, "Aim at cup", _aim_cup)
	_button(shots, "Play shot", _shoot)
	_button(shots, "New practice round", _restart)
	_button(shots, "Close", func() -> void: hide(); _world.hide(); live.chunks.show())
	_world = Node3D.new()
	live.add_child(_world)
	_world.hide()
	var layouts: Array = live.session.hole_definitions()
	if not layouts.is_empty():
		var h: Dictionary = layouts[0]
		length_yd = int(h["green"][1])
		half_width_yd = int(h["features"][0]["rect"][2])
		water = (h["features"] as Array).size() > 1
	_describe()
	hide()

func open() -> void:
	live.router.cancel_world_input()
	if live.aim_input != null:
		live.aim_input.taps.clear()
	live.shell.show_root(MHScreenIds.HUD)
	live.chunks.hide() # Flat exact-layout view; arbitrary brush terrain is not claimed as rated geometry.
	show()
	_world.show()
	_draw()
	_describe()

func _button(parent: Control, title: String, action: Callable) -> void:
	var b: MHTapButton = MHUIKit.button(live.shell.ctx, title, &"ChipButton", 110)
	parent.add_child(b)
	b.pressed.connect(action)

func _layout() -> Dictionary:
	var features: Array = [{"t": "fairway", "rect": [-half_width_yd, 0, half_width_yd, length_yd]}]
	if water:
		features.append({"t": "water", "rect": [10, 20, 14, 30]})
	return {"slot_id": 0, "tee": [0, 0], "green": [0, length_yd, 5], "features": features}

func _draft_changed() -> void:
	_preview_draft = true
	_draw()
	_describe()

func _finalize() -> void:
	if live.shell.modal_id() != "":
		return
	live.router.cancel_world_input()
	var h: Dictionary = _layout()
	var encoded: MHSaveResult = MHCourseLayout.encode([h], live.document["course"] as Dictionary, [ORIGIN])
	if not encoded.is_ok():
		_info.text = encoded.message
		return
	var result: Dictionary = live.session.submit_course([h])
	if not bool(result["ok"]):
		_info.text = "Cannot finalize: " + str(result["reason"])
		return
	_preview_draft = false
	live.document["course"] = encoded.value
	live.document["min_reader_version"] = 3
	live.session.practice = null # A redesign cannot continue a round on a previous layout.
	_restart()
	live._request_save()
	_draw()
	_describe()

func _restart() -> void:
	if live.shell.modal_id() != "":
		return
	var layouts: Array = live.session.hole_definitions()
	if layouts.is_empty():
		_info.text = "Finalize your hole first."
		return
	_preview_draft = false
	var current: Dictionary = layouts[0]
	length_yd = int(current["green"][1])
	half_width_yd = int(current["features"][0]["rect"][2])
	water = (current["features"] as Array).size() > 1
	live.session.practice = MHPracticeRound.create(layouts[0] as Dictionary,
		MHRatingEngine.seed_for(0, {"save_secret": live.session.save_secret, "rating_epoch": live.session.rating_epoch}))
	live._request_save()
	_aim_cup()
	_draw()
	_describe()

func _aim_cup() -> void:
	if live.session.practice != null:
		aim_x = live.session.practice.hole.gx
		aim_y = live.session.practice.hole.gy
	_move_aim()

func _shoot() -> void:
	if live.shell.modal_id() != "":
		return
	if live.session.practice == null:
		_info.text = "Finalize, then start a practice round."
		return
	if _preview_draft:
		_info.text = "Finalize the draft before playing it. Your current round was preserved."
		return
	var result: Dictionary = live.session.practice.play(aim_x, aim_y)
	if not bool(result["ok"]):
		_info.text = "Round finished or aim is at the ball. Start another round or change aim."
		return
	live._request_save()
	_draw()
	_describe()
	if int(result["penalty"]) > 0:
		_info.text += " | Penalty +1"
	elif bool(result["tree"]):
		_info.text += " | Tree hit"

func _describe() -> void:
	var price: int = 0 if not live.session.hole_definitions().is_empty() else live.session.economy.hole_cost_cents()
	_info.text = "Draft: %d yd, fairway %d yd wide. Finalize $%d; redesign free." % [length_yd, half_width_yd * 2, price / 100]
	var r: MHPracticeRound = live.session.practice
	if r != null:
		_info.text += " | %d strokes | %s" % [r.strokes, "Picked up" if r.picked_up else ("Holed" if r.finished else "Playing")]
	var scores: Array = live.session.hole_results()
	if not scores.is_empty():
		_info.text += " | Official hole score %d/100" % int(scores[0]["score"])

func _draw() -> void:
	_path = null
	for child: Node in _world.get_children():
		_world.remove_child(child)
		child.queue_free()
	_box(Vector3(64, -0.1, 64), Vector3(128, 0.1, 128), Color(0.27, 0.44, 0.21))
	var layouts: Array = live.session.hole_definitions()
	var h: Dictionary = _layout() if layouts.is_empty() or _preview_draft else layouts[0]
	for row: Variant in h["features"]:
		var f: Dictionary = row
		var rect: Array = f["rect"]
		var a: Vector3 = _position(int(rect[0]) * 100, int(rect[1]) * 100, 0.02)
		var b: Vector3 = _position(int(rect[2]) * 100, int(rect[3]) * 100, 0.02)
		_box((a + b) / 2.0, Vector3(b.x - a.x, 0.03, b.z - a.z), Color(0.12, 0.4, 0.7) if str(f["t"]) == "water" else Color(0.36, 0.64, 0.23))
	var g: Array = h["green"]
	var circle: CylinderMesh = CylinderMesh.new()
	circle.top_radius = float(g[2]) * 0.9144
	circle.bottom_radius = circle.top_radius
	circle.height = 0.03
	_mesh(circle, _position(int(g[0]) * 100, int(g[1]) * 100, 0.06), Color(0.5, 0.78, 0.3))
	_box(_position(int(g[0]) * 100, int(g[1]) * 100, 1.0), Vector3(0.12, 2, 0.12), Color.WHITE)
	_ball = _marker(Color.WHITE, 0.35)
	var r: MHPracticeRound = live.session.practice
	_ball.position = _position(r.x if r != null and not _preview_draft else 0, r.y if r != null and not _preview_draft else 0, 0.45)
	_aim = _marker(Color(1, 0.8, 0.1), 0.55)
	_move_aim()

func _move_aim() -> void:
	if _aim != null:
		_aim.position = _position(aim_x, aim_y, 0.7)
	_refresh_path()

func _position(cx: int, cy: int, height: float) -> Vector3:
	return Vector3(float(MHCourseLayout.world_mm(int(ORIGIN[0]), cx)) / 1000.0, height,
		float(MHCourseLayout.world_mm(int(ORIGIN[1]), cy)) / 1000.0)

func _marker(color: Color, radius: float) -> MeshInstance3D:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	return _mesh(sphere, Vector3.ZERO, color)

func _box(pos: Vector3, size_value: Vector3, color: Color) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = size_value
	_mesh(box, pos, color)

func _mesh(mesh_value: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	m.mesh = mesh_value
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	m.position = pos
	_world.add_child(m)
	return m


## The save codec supports more shapes than this small authoring/view prototype does.
static func supported(course: Dictionary) -> bool:
	var decoded: MHSaveResult = MHCourseLayout.decode(course)
	if not decoded.is_ok():
		return false
	var rows: Array = course["holes"]
	if rows.is_empty():
		return true
	if rows.size() != 1:
		return false
	var row: Dictionary = rows[0]
	if row["origin_dm"] != ORIGIN:
		return false
	var h: Dictionary = row["layout"]
	if int(h["slot_id"]) != 0 or h["tee"] != [0, 0] or h.has("tee_z_mm") or h.has("green_z_mm"):
		return false
	var g: Array = h["green"]
	if int(g[0]) != 0 or int(g[1]) < 60 or int(g[1]) > 62 or int(g[2]) != 5:
		return false
	var fs: Array = h["features"]
	if fs.size() < 1 or fs.size() > 2:
		return false
	var f: Dictionary = fs[0]
	if str(f["t"]) != "fairway" or not f.has("rect"):
		return false
	var rect: Array = f["rect"]
	if int(rect[2]) < 6 or int(rect[2]) > 14 or rect != [-int(rect[2]), 0, int(rect[2]), int(g[1])]:
		return false
	return fs.size() == 1 or fs[1] == {"t": "water", "rect": [10, 20, 14, 30]}


func blocks_world_tap(pos: Vector2) -> bool:
	if get_global_rect().has_point(pos) or live.shell.modal_id() != "":
		return true
	for getter: Variant in live.shell.region_rects().values():
		var rect: Rect2 = (getter as Callable).call()
		if rect.has_point(pos):
			return true
	for n: Node in get_tree().get_nodes_in_group(MHTapButton.GROUP):
		var b: Button = n as Button
		if b != null and b.is_visible_in_tree() and b.get_global_rect().has_point(pos):
			return true
	return false

func aim_from_screen(pos: Vector2) -> bool:
	var camera: Camera3D = live.controller.camera
	var origin: Vector3 = camera.project_ray_origin(pos)
	var direction: Vector3 = camera.project_ray_normal(pos)
	if absf(direction.y) < 0.00001:
		return false
	var distance: float = -origin.y / direction.y
	if distance <= 0.0:
		return false
	var hit: Vector3 = origin + direction * distance
	if hit.x < 0.0 or hit.x >= 128.0 or hit.z < 0.0 or hit.z >= 128.0:
		return false
	# Only the input/render boundary uses float coordinates; the gameplay aim is integer centiyards.
	aim_x = MHRMath.rdiv((roundi(hit.x * 1000.0) - int(ORIGIN[0]) * 100) * 1000, 9144)
	aim_y = MHRMath.rdiv((roundi(hit.z * 1000.0) - int(ORIGIN[1]) * 100) * 1000, 9144)
	_move_aim()
	return true

func _refresh_path() -> void:
	if _world == null or _aim == null:
		return
	if _path != null and is_instance_valid(_path):
		_world.remove_child(_path)
		_path.queue_free()
	_path = Node3D.new()
	_world.add_child(_path)
	var r: MHPracticeRound = live.session.practice
	if r == null or _preview_draft:
		_feedback.text = "Draft preview. Finalize before practice; tap sets the target only."
		return
	var preview: Dictionary = r.aim_preview(aim_x, aim_y)
	if not bool(preview.get("ok", false)):
		return
	if r.finished:
		_feedback.text = "Round finished. Start another practice round."
		return
	var a: Vector3 = _position(r.x, r.y, 0.18)
	var b: Vector3 = _position(aim_x, aim_y, 0.18)
	_path_line(a, b, Color(1, 0.8, 0.1))
	var landing: Vector3 = _position(int(preview["landing_x"]), int(preview["landing_y"]), 0.22)
	var radius: float = maxf(0.5, float(preview["spread_cy"]) * 0.009144)
	for i: int in range(16):
		var t0: float = float(i) * TAU / 16.0
		var t1: float = float(i + 1) * TAU / 16.0
		_path_line(landing + Vector3(cos(t0) * radius, 0, sin(t0) * radius),
			landing + Vector3(cos(t1) * radius, 0, sin(t1) * radius), Color(1, 0.8, 0.1))
	_feedback.text = "%d yd target | %s. Ring is rough shot spread, not a guaranteed landing." % [int(preview["distance_cy"]) / 100,
		"Within reach" if bool(preview["reachable"]) else "Beyond reach: shot stops short"]
	var target_lie: int = int(preview["landing_lie"])
	if target_lie == MHRHole.LIE_WATER:
		_feedback.text += " Water on intended landing."
	elif target_lie == MHRHole.LIE_OB:
		_feedback.text += " Intended landing out of bounds."
	elif target_lie == MHRHole.LIE_BUNKER:
		_feedback.text += " Intended landing in sand."

func _path_line(a: Vector3, b: Vector3, color: Color) -> void:
	var length_value: float = a.distance_to(b)
	if length_value < 0.001:
		return
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.1, 0.035, length_value)
	var line: MeshInstance3D = MeshInstance3D.new()
	line.mesh = box
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	line.material_override = material
	line.position = (a + b) / 2.0
	line.rotation.y = atan2(b.x - a.x, b.z - a.z)
	_path.add_child(line)

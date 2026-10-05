class_name MHPersonalShot
extends RefCounted
## Personal outcome mirror. Takes already validated, privately owned MHRHole geometry.
## tree_hit mutates the hole's scratch hit fields; never share it across concurrent calls.
@warning_ignore_start("integer_division")
const VERSION: String = "MHPERSONAL-SHOT-0.1"
const LIES: Array[String] = ["tee", "fairway", "fringe", "rough", "deep", "bunker", "green", "water", "ob"]
const TMAX: Array[int] = [600, 550, 450, 400, 350, 300, 280, 260, 240, 220, 200, 200]

static func _distance(a: Vector2i, b: Vector2i) -> int:
	var dx: int = a.x - b.x
	var dy: int = a.y - b.y
	return MHRMath.isqrt(dx * dx + dy * dy)

static func _start(h: MHRHole, ball: Vector2i, lie: String) -> bool:
	if not MHPersonalEnvelope.LIES.has(lie):
		return false
	var actual: int = h.lie_at(ball.x, ball.y)
	if actual >= MHRHole.LIE_WATER:
		return false
	if lie == "tee":
		return ball == Vector2i(h.tee_x, h.tee_y)
	if lie == "deep" and actual != MHRHole.LIE_DEEP:
		if actual == MHRHole.LIE_GREEN:
			return false
		for i in range(0, h.trees.size(), 2):
			if _distance(ball, Vector2i(h.trees[i], h.trees[i + 1])) <= 300:
				return true
		return false
	return LIES[actual] == lie

static func preview(h: MHRHole, p: Dictionary, ball: Vector2i, lie: String, aim: Vector2i, style: String = "straight", pressure: int = 0) -> Dictionary:
	if h == null or not h.valid or not MHRParams.ensure_loaded():
		return {}
	if absi(ball.x) > 120000 or absi(ball.y) > 120000 or absi(aim.x) > 120000 or absi(aim.y) > 120000 or not _start(h, ball, lie):
		return {}
	var distance: int = _distance(ball, aim)
	var selected: Dictionary = {}
	var club: int = -1 if style == "putt" else 0
	for i in range(11, -1, -1):
		selected = MHPersonalEnvelope.envelope(p, distance, MHRParams.club_base[i] * 100, lie, style, pressure)
		if selected.is_empty():
			return {}
		if style == "putt" or int(selected["carry_max_cy"]) >= distance:
			if style != "putt":
				club = i
			break
	selected["club"] = club
	return selected

static func _cross(a: Vector2i, b: Vector2i, c: Vector2i) -> int:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)

static func _opposite(x: int, y: int) -> bool:
	return x == 0 or y == 0 or (x < 0) != (y < 0)

static func _touch(a: Vector2i, b: Vector2i, c: Vector2i, d: Vector2i) -> bool:
	if maxi(a.x, b.x) < mini(c.x, d.x) or maxi(c.x, d.x) < mini(a.x, b.x):
		return false
	if maxi(a.y, b.y) < mini(c.y, d.y) or maxi(c.y, d.y) < mini(a.y, b.y):
		return false
	return _opposite(_cross(a, b, c), _cross(a, b, d)) and _opposite(_cross(c, d, a), _cross(c, d, b))

static func _hazard(h: MHRHole, a: Vector2i, b: Vector2i) -> int:
	for kind: int in [MHRHole.T_OB, MHRHole.T_WATER]:
		var code: int = 2 if kind == MHRHole.T_OB else 1
		var rects: PackedInt32Array = h.rects[kind]
		for i in range(0, rects.size(), 4):
			var x0: int = rects[i]
			var y0: int = rects[i + 1]
			var x1: int = rects[i + 2]
			var y1: int = rects[i + 3]
			if (x0 <= a.x and a.x <= x1 and y0 <= a.y and a.y <= y1) or (x0 <= b.x and b.x <= x1 and y0 <= b.y and b.y <= y1):
				return code
			var corners: Array[Vector2i] = [Vector2i(x0, y0), Vector2i(x1, y0), Vector2i(x1, y1), Vector2i(x0, y1)]
			for j in range(4):
				if _touch(a, b, corners[j], corners[(j + 1) % 4]):
					return code
		var circles: PackedInt32Array = h.circles[kind]
		for i in range(0, circles.size(), 3):
			var c: Vector2i = Vector2i(circles[i], circles[i + 1])
			var r: int = circles[i + 2]
			var dx: int = b.x - a.x
			var dy: int = b.y - a.y
			var length2: int = dx * dx + dy * dy
			var dot: int = (c.x - a.x) * dx + (c.y - a.y) * dy
			var hit: bool
			if length2 == 0 or dot <= 0:
				hit = (c.x - a.x) * (c.x - a.x) + (c.y - a.y) * (c.y - a.y) <= r * r
			elif dot >= length2:
				hit = (c.x - b.x) * (c.x - b.x) + (c.y - b.y) * (c.y - b.y) <= r * r
			else:
				var area: int = _cross(a, b, c)
				hit = area * area <= r * r * length2
			if hit:
				return code
	return 0

static func _result(ball: Vector2i, lie: String, club: int, penalty: int, kind: int, tree: bool, holed: bool, index: int) -> Dictionary:
	return {"model": VERSION, "x": ball.x, "y": ball.y, "lie": lie, "club": club, "penalty": penalty,
		"penalty_kind": kind, "tree": tree, "holed": holed, "shot_index": index}

static func play(h: MHRHole, p: Dictionary, ball: Vector2i, lie: String, aim: Vector2i, seed: int, index: int, style: String = "straight", pressure: int = 0) -> Dictionary:
	if seed < 0 or seed > 0xFFFFFFFF or index < 1 or index > 1000000:
		return {}
	var env: Dictionary = preview(h, p, ball, lie, aim, style, pressure)
	if env.is_empty():
		return {}
	var u: Vector3i = MHRMath.unit(aim.x - ball.x, aim.y - ball.y)
	var rng: MHRng = MHRng.new(seed, index * 8)
	var lateral: int = MHRMath.fdiv(rng.gauss_q16() * int(env["lateral_scale_cy"]), 65536)
	rng = MHRng.new(seed, index * 8 + 1)
	var depth: int = MHRMath.fdiv(rng.gauss_q16() * int(env["depth_scale_cy"]), 65536)
	var along: int = maxi(0, int(env["effective_cy"]) + depth)
	var destination: Vector2i = Vector2i(ball.x + MHRMath.rdiv(u.x * along - u.y * lateral, 1024), ball.y + MHRMath.rdiv(u.y * along + u.x * lateral, 1024))
	var club: int = int(env["club"])
	var tree: bool = false
	if style == "putt":
		var distance: int = _distance(ball, destination)
		var steps: int = maxi(1, (distance + 24) / 25)
		var points: Array[Vector2i] = []
		var nearest_distance: int = 2147483647
		var nearest_travel: int = 0
		var nearest_index: int = 0
		for i in range(1, steps + 1):
			var pt: Vector2i = Vector2i(ball.x + MHRMath.rdiv((destination.x - ball.x) * i, steps), ball.y + MHRMath.rdiv((destination.y - ball.y) * i, steps))
			points.append(pt)
			var cup_distance: int = _distance(pt, Vector2i(h.gx, h.gy))
			if cup_distance < nearest_distance:
				nearest_distance = cup_distance
				nearest_travel = _distance(ball, pt)
				nearest_index = i
		var capture_index: int = nearest_index if nearest_distance <= 15 and distance <= nearest_travel + 100 else -1
		var previous: Vector2i = ball
		for j in range(points.size()):
			var pt: Vector2i = points[j]
			var crossing: int = _hazard(h, previous, pt)
			if crossing > 0:
				return _result(ball, lie, club, 1, crossing, false, false, index)
			previous = pt
			var loc: int = h.lie_at(pt.x, pt.y)
			if loc >= MHRHole.LIE_WATER:
				return _result(ball, lie, club, 1, 1 if loc == MHRHole.LIE_WATER else 2, false, false, index)
			if j + 1 == capture_index:
				return _result(Vector2i(h.gx, h.gy), "green", club, 0, 0, false, true, index)
	else:
		var cutoff: int = 1000 if style == "safe_recovery" else TMAX[club]
		if h.tree_hit(ball.x, ball.y, destination.x, destination.y, cutoff):
			tree = true
			var back_u: Vector3i = MHRMath.unit(h.hit_x - ball.x, h.hit_y - ball.y)
			var back: int = mini(back_u.z, 100)
			destination = Vector2i(h.hit_x - MHRMath.fdiv(back_u.x * back, 1024), h.hit_y - MHRMath.fdiv(back_u.y * back, 1024))
	var loc: int = h.lie_at(destination.x, destination.y)
	if loc >= MHRHole.LIE_WATER:
		return _result(ball, lie, club, 1, 1 if loc == MHRHole.LIE_WATER else 2, tree, false, index)
	if tree and loc != MHRHole.LIE_GREEN:
		loc = MHRHole.LIE_DEEP
	return _result(destination, LIES[loc], club, 0, 0, tree, false, index)

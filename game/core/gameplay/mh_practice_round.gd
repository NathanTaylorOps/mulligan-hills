class_name MHPracticeRound
extends RefCounted
## One-hole aim-controlled practice prototype. No money, XP, prizes or tournament entry.
## Uses the same integer flight/lie/penalty rules as rating; official rating never reads player results.
@warning_ignore_start("integer_division")
var hole: MHRHole
var seed: int = 0
var skill: int = 500
var x: int = 0
var y: int = 0
var lie: int = MHRHole.LIE_TEE
var strokes: int = 0
var shot: int = 1
var finished: bool = false
var picked_up: bool = false

static func create(layout: Dictionary, round_seed: int, player_skill: int = 500) -> MHPracticeRound:
	if not MHRParams.ensure_loaded() or player_skill < 0 or player_skill > 1000:
		return null
	var valid: Dictionary = MHRatingEngine.validate_input({"schema": 1, "engine": MHRatingEngine.RATING_VERSION, "hole": layout})
	if not bool(valid["ok"]):
		return null
	var parsed: MHRHole = MHRHole.from_def(layout)
	if not parsed.valid:
		return null
	var r: MHPracticeRound = MHPracticeRound.new()
	r.hole = parsed
	r.seed = round_seed & MHRMath.M32
	r.skill = player_skill
	r.x = parsed.tee_x
	r.y = parsed.tee_y
	return r

func play(aim_x: int, aim_y: int) -> Dictionary:
	if finished or absi(aim_x) > 120000 or absi(aim_y) > 120000 or (aim_x == x and aim_y == y):
		return {"ok": false, "reason": "aim_or_finished"}
	var penalty: int = 0
	var kind: int = 0
	var tree: bool = false
	if lie == MHRHole.LIE_GREEN:
		# Direct, individually controlled putt. Prototype, not the AI's aggregate putt-count shortcut.
		var u: Vector3i = MHRMath.unit(aim_x - x, aim_y - y)
		var distance: int = mini(u.z, 3000)
		x += MHRMath.rdiv(u.x * distance, 1024)
		y += MHRMath.rdiv(u.y * distance, 1024)
		if MHRMath.isqrt((x - hole.gx) * (x - hole.gx) + (y - hole.gy) * (y - hole.gy)) <= 15:
			x = hole.gx
			y = hole.gy
			finished = true
		lie = hole.lie_at(x, y)
		if lie == MHRHole.LIE_WATER or lie == MHRHole.LIE_OB:
			# The same stroke-and-distance policy as flight for OB; safe prototype water reset.
			kind = 1 if lie == MHRHole.LIE_WATER else 2
			x -= MHRMath.rdiv(u.x * distance, 1024)
			y -= MHRMath.rdiv(u.y * distance, 1024)
			lie = MHRHole.LIE_GREEN
			penalty = 1
	else:
		var sim: MHRSim = MHRSim.new(hole, 0, 0, 0)
		var z: PackedInt32Array = MHRParams.z256
		sim.land(x, y, lie, aim_x, aim_y, skill,
			z[MHRMath.h32d(seed, 0, shot, 0) & 255], z[MHRMath.h32d(seed, 0, shot, 1) & 255],
			MHRMath.h32d(seed, 0, shot, 2) % 1000, MHRMath.h32d(seed, 0, shot, 3))
		x = sim.r_x
		y = sim.r_y
		lie = sim.r_lie
		penalty = sim.r_pen
		kind = sim.r_kind
		tree = sim.r_tree
	strokes += 1 + penalty
	shot += 1
	if strokes >= hole.par + 4 and not finished:
		finished = true
		picked_up = true
	return {"ok": true, "x": x, "y": y, "lie": lie, "strokes": strokes,
		"penalty": penalty, "penalty_kind": kind, "tree": tree, "finished": finished, "picked_up": picked_up}

func to_dict() -> Dictionary:
	return {"v": 1, "slot_id": hole.slot, "content_hash": hole.content_hash(), "seed": seed, "skill": skill,
		"x": x, "y": y, "lie": lie, "strokes": strokes, "shot": shot, "finished": finished, "picked_up": picked_up}

static func restore(layout: Dictionary, raw: Dictionary) -> MHPracticeRound:
	if raw.size() != 12:
		return null
	for key: String in ["v", "slot_id", "seed", "skill", "x", "y", "lie", "strokes", "shot"]:
		if not MHRValidate.is_int_value(raw.get(key, null)):
			return null
	if int(raw["v"]) != 1 or int(raw["seed"]) < 0 or int(raw["seed"]) > MHRMath.M32 \
		or typeof(raw.get("finished", null)) != TYPE_BOOL or typeof(raw.get("picked_up", null)) != TYPE_BOOL:
		return null
	var r: MHPracticeRound = create(layout, int(raw["seed"]), int(raw["skill"]))
	if r == null or int(raw["slot_id"]) != r.hole.slot or raw.get("content_hash", null) != r.hole.content_hash():
		return null
	var sx: int = int(raw["x"])
	var sy: int = int(raw["y"])
	var sl: int = int(raw["lie"])
	var ss: int = int(raw["strokes"])
	var sn: int = int(raw["shot"])
	if absi(sx) > 120000 or absi(sy) > 120000 or ss < 0 or ss > r.hole.par + 5 or sn < 1 or sn > ss + 1:
		return null
	if ss == 0:
		if sx != r.x or sy != r.y or sl != r.lie or sn != 1 or bool(raw["finished"]) or bool(raw["picked_up"]):
			return null
	elif sl != r.hole.lie_at(sx, sy) and not (sl == MHRHole.LIE_TEE and sx == r.hole.tee_x and sy == r.hole.tee_y) and not (sl == MHRHole.LIE_DEEP and r.hole.tree_hit(sx, sy, sx, sy, 1000)):
		# Tree interception backs the ball off by one yard and marks it deep.
		var near_tree: bool = false
		if sl == MHRHole.LIE_DEEP:
			for i: int in range(r.hole.tree_count()):
				var dx: int = sx - r.hole.trees[i * 2]
				var dy: int = sy - r.hole.trees[i * 2 + 1]
				if dx * dx + dy * dy <= 301 * 301:
					near_tree = true
		if not near_tree:
			return null
	if not bool(raw["finished"]) and ss >= r.hole.par + 4:
		return null
	if bool(raw["picked_up"]) and (not bool(raw["finished"]) or ss < r.hole.par + 4):
		return null
	if bool(raw["finished"]) and not bool(raw["picked_up"]) and (sx != r.hole.gx or sy != r.hole.gy):
		return null
	r.x = sx
	r.y = sy
	r.lie = sl
	r.strokes = ss
	r.shot = sn
	r.finished = bool(raw["finished"])
	r.picked_up = bool(raw["picked_up"])
	return r


## Non-consuming, no-random-draw preview. Spread is a rough scale, not a probability/guarantee.
func aim_preview(aim_x: int, aim_y: int) -> Dictionary:
	if absi(aim_x) > 120000 or absi(aim_y) > 120000:
		return {"ok": false}
	var u: Vector3i = MHRMath.unit(aim_x - x, aim_y - y)
	var club: int = MHRSim.pick_club(u.z, skill, lie)
	var limit: int = 3000 if lie == MHRHole.LIE_GREEN else MHRSim.carry_max(club, skill, lie)
	var deff: int = mini(u.z, limit)
	var spread: int = 0
	if lie != MHRHole.LIE_GREEN:
		var short_mult: int = MHRMath.interp(MHRParams.short_game, deff / 100)
		spread = deff * MHRSim.spread_pm(skill) / 1000 * MHRParams.lie_disp[lie] / 1000 * short_mult / 1000
	var tx: int = x + MHRMath.rdiv(u.x * deff, 1024)
	var ty: int = y + MHRMath.rdiv(u.y * deff, 1024)
	var target_lie: int = hole.lie_at(tx, ty)
	return {"ok": true, "distance_cy": u.z, "reachable": u.z <= limit, "club": club,
		"landing_x": tx, "landing_y": ty, "landing_lie": target_lie, "spread_cy": spread,
		"finished": finished}

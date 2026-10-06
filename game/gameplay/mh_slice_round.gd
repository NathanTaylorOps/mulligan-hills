class_name MHSliceRound
extends RefCounted
## Cosmetic timeline of one golfer playing one short hole: wait, swing at the tee, walk to the green, putt,
## walk off. Pure functions of elapsed VISUAL seconds, so tests need no scene. Nothing here touches the sim.
##
## Group members swing one after another (SWING_STAGGER apart), walk together, then putt in turn.
## Clip lengths and impact times come from MHGolferPoses so the ball leaves the club when the swing hits.
## NOT YET RUN in Godot.

enum Phase { WAIT_TEE = 0, SWING = 1, WAIT_WALK = 2, WALK = 3, WAIT_PUTT = 4, PUTT = 5, EXIT = 6, DONE = 7 }

const SWING_STAGGER_S: float = 2.8
const WALK_STAGGER_S: float = 0.5
const PUTT_STAGGER_S: float = 2.0
const WALK_SPEED_MPS: float = 2.2
const EXIT_M: float = 14.0
const FLIGHT_S: float = 1.5
const BALL_APEX_M: float = 6.0
const LATERAL_SPACING_M: float = 1.4


## Timeline numbers for one golfer, all in seconds since the group teed off.
static func times(member: int, size: int, path_len_m: float) -> Dictionary:
	var swing_start: float = float(member) * SWING_STAGGER_S
	var swing_end: float = swing_start + MHGolferPoses.LENGTH_SWING
	var all_swung: float = float(maxi(size, 1) - 1) * SWING_STAGGER_S + MHGolferPoses.LENGTH_SWING
	var walk_start: float = all_swung + float(member) * WALK_STAGGER_S
	var walk_end: float = walk_start + maxf(path_len_m, 0.0) / WALK_SPEED_MPS
	# Everyone has arrived once the last member's walk ends; then members putt in turn.
	var last_walk_end: float = all_swung + float(maxi(size, 1) - 1) * WALK_STAGGER_S + maxf(path_len_m, 0.0) / WALK_SPEED_MPS
	var putt_start: float = last_walk_end + float(member) * PUTT_STAGGER_S
	var putt_end: float = putt_start + MHGolferPoses.LENGTH_PUTT
	var exit_end: float = putt_end + EXIT_M / WALK_SPEED_MPS
	return {"swing_start": swing_start, "swing_end": swing_end, "walk_start": walk_start, "walk_end": walk_end,
		"putt_start": putt_start, "putt_end": putt_end, "exit_end": exit_end,
		"impact": swing_start + MHGolferPoses.IMPACT_SWING}


## Total seconds until the golfer is gone, for the last member of a group.
static func group_duration(size: int, path_len_m: float) -> float:
	return float(times(maxi(size, 1) - 1, size, path_len_m)["exit_end"])


## State at `t` seconds. Keys: phase (Phase), clip ("idle"|"walk"|"swing"|"putt"), clip_t (seconds into the
## clip), along (metres from the tee along the hole, beyond path_len_m while walking off), ball_u (0..1 while the
## ball is in the air, else -1.0), aim (true when the golfer faces the target with the +X side, as in a swing).
static func state(t: float, member: int, size: int, path_len_m: float) -> Dictionary:
	var k: Dictionary = times(member, size, path_len_m)
	var out: Dictionary = {"phase": Phase.WAIT_TEE, "clip": MHGolferPoses.CLIP_IDLE, "clip_t": maxf(t, 0.0),
		"along": 0.0, "ball_u": -1.0, "aim": true}
	var impact: float = float(k["impact"])
	if t >= impact and t < impact + FLIGHT_S:
		out["ball_u"] = (t - impact) / FLIGHT_S
	if t >= float(k["exit_end"]):
		out["phase"] = Phase.DONE
		out["along"] = path_len_m + EXIT_M
		out["aim"] = false
		return out
	if t >= float(k["putt_end"]):
		out["phase"] = Phase.EXIT
		out["clip"] = MHGolferPoses.CLIP_WALK
		out["clip_t"] = fposmod(t - float(k["putt_end"]), MHGolferPoses.LENGTH_WALK)
		out["along"] = path_len_m + (t - float(k["putt_end"])) * WALK_SPEED_MPS
		out["aim"] = false
		return out
	if t >= float(k["putt_start"]):
		out["phase"] = Phase.PUTT
		out["clip"] = MHGolferPoses.CLIP_PUTT
		out["clip_t"] = t - float(k["putt_start"])
		out["along"] = path_len_m
		return out
	if t >= float(k["walk_end"]):
		out["phase"] = Phase.WAIT_PUTT
		out["clip_t"] = t
		out["along"] = path_len_m
		out["aim"] = false
		return out
	if t >= float(k["walk_start"]):
		out["phase"] = Phase.WALK
		out["clip"] = MHGolferPoses.CLIP_WALK
		out["clip_t"] = fposmod(t - float(k["walk_start"]), MHGolferPoses.LENGTH_WALK)
		out["along"] = (t - float(k["walk_start"])) * WALK_SPEED_MPS
		out["aim"] = false
		return out
	if t >= float(k["swing_end"]):
		out["phase"] = Phase.WAIT_WALK
		out["clip_t"] = t
		return out
	if t >= float(k["swing_start"]):
		out["phase"] = Phase.SWING
		out["clip"] = MHGolferPoses.CLIP_SWING
		out["clip_t"] = t - float(k["swing_start"])
		return out
	return out


## Yaw (radians about +Y) for a figure that faces the hole direction (dir_x, dir_z). The figure model faces +Z when
## walking, and a right-handed swing aims along its local +X (see art_nature_golfers_props.md).
static func facing_yaw(dir_x: float, dir_z: float, aim: bool) -> float:
	if aim:
		return atan2(-dir_z, dir_x)
	return atan2(dir_x, dir_z)


## World position (x, z) of a golfer: `along` metres from the tee toward the green, plus a sideways offset
## that spreads the group (member index centred on the group).
static func ground_point(tee: Vector2, dir: Vector2, along: float, member: int, size: int) -> Vector2:
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var offset: float = (float(member) - float(size - 1) * 0.5) * LATERAL_SPACING_M
	return tee + dir * along + side * offset


## Ball position while in the air (u in 0..1), a simple parabola over the line tee to green.
static func ball_point(tee: Vector2, green: Vector2, u: float) -> Vector3:
	var uu: float = clampf(u, 0.0, 1.0)
	var p: Vector2 = tee.lerp(green, uu)
	return Vector3(p.x, 0.1 + 4.0 * BALL_APEX_M * uu * (1.0 - uu), p.y)

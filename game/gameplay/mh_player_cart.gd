class_name MHPlayerCart
extends RigidBody3D
## Free-drive cart sandbox. Physics consequences are presentation/gameplay fun, not authoritative course traffic.
## Respawning owns cleanup of the current cart and everything it shed.

signal sunk()
signal tipped()
signal clubs_lost(count: int)

const DRIVE_FORCE: float = 780.0
const BRAKE_FORCE: float = 1100.0
const TURN_TORQUE: float = 210.0
const MAX_FORWARD_MPS: float = 13.0
const MAX_REVERSE_MPS: float = 5.0
const LATERAL_GRIP: float = 7.0
const TIP_UP_DOT: float = 0.38
const CLUB_SHED_IMPULSE: float = 8.0

var splat: MHSplatMap
var grid: MHHeightGrid
var debris_root: Node3D
var _tip_reported: bool = false
var _sunk_reported: bool = false
var _clubs_shed: bool = false
var _throttle: float = 0.0
var _steer: float = 0.0

func drive(throttle: float, steer: float) -> void:
	_throttle = clampf(throttle, -1.0, 1.0)
	_steer = clampf(steer, -1.0, 1.0)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _sunk_reported:
		state.linear_velocity *= 0.96
		return
	var forward: Vector3 = -global_transform.basis.z.normalized()
	var right: Vector3 = global_transform.basis.x.normalized()
	var forward_speed: float = state.linear_velocity.dot(forward)
	var lateral_speed: float = state.linear_velocity.dot(right)
	var limit: float = MAX_FORWARD_MPS if _throttle >= 0.0 else MAX_REVERSE_MPS
	if absf(forward_speed) < limit or signf(_throttle) != signf(forward_speed):
		apply_central_force(forward * _throttle * DRIVE_FORCE)
	if absf(_throttle) < 0.05:
		apply_central_force(-forward * forward_speed * BRAKE_FORCE * 0.02)
	apply_central_force(-right * lateral_speed * LATERAL_GRIP * mass)
	var speed_factor: float = clampf(absf(forward_speed) / 3.0, 0.15, 1.0)
	apply_torque(Vector3.UP * _steer * TURN_TORQUE * speed_factor * (1.0 if forward_speed >= -0.2 else -1.0))

func _physics_process(_delta: float) -> void:
	var surface: String = MHCartSurfacePolicy.free_drive_surface(splat, global_position, grid)
	if surface == "water" and not _sunk_reported:
		_sunk_reported = true
		gravity_scale = 0.35
		linear_damp = 3.5
		angular_damp = 4.0
		_shed_clubs()
		sunk.emit()
	var upright: float = global_transform.basis.y.dot(Vector3.UP)
	if upright < TIP_UP_DOT and not _tip_reported:
		_tip_reported = true
		tipped.emit()
		_shed_clubs()
	if linear_velocity.length() > 12.0 and absf(angular_velocity.y) > 2.2:
		_shed_clubs()
	# Severe airborne/sideways motion can also dump the bag before a full rollover.
	if absf(linear_velocity.y) > 5.5 and linear_velocity.length() > 9.0:
		_shed_clubs()

func _shed_clubs() -> void:
	if _clubs_shed or debris_root == null:
		return
	_clubs_shed = true
	var bag: Node = get_node_or_null("GolfBag")
	if bag != null:
		bag.hide()
	var count: int = 4
	for i: int in range(count):
		var club: RigidBody3D = RigidBody3D.new()
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(0.05, 0.9, 0.05)
		mesh_instance.mesh = mesh
		club.add_child(mesh_instance)
		debris_root.add_child(club)
		club.global_position = global_position + global_transform.basis.z * 1.1 + Vector3(0.0, 0.8, 0.0)
		club.apply_central_impulse(Vector3(float(i - 2) * 0.7, 2.0, 1.0).normalized() * CLUB_SHED_IMPULSE)
	clubs_lost.emit(count)

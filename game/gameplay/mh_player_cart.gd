class_name MHPlayerCart
extends RigidBody3D
## Free-drive cart sandbox. Physics consequences are presentation/gameplay fun, not authoritative course traffic.
## Respawning owns cleanup of the current cart and everything it shed.

signal sunk()
signal tipped()
signal clubs_lost(count: int)

const DRIVE_FORCE: float = 950.0
const TURN_TORQUE: float = 260.0
const TIP_UP_DOT: float = 0.38
const CLUB_SHED_IMPULSE: float = 8.0

var splat: MHSplatMap
var grid: MHHeightGrid
var debris_root: Node3D
var _tip_reported: bool = false
var _sunk_reported: bool = false
var _clubs_shed: bool = false

func drive(throttle: float, steer: float) -> void:
	if _sunk_reported:
		return
	apply_central_force(-global_transform.basis.z * clampf(throttle, -1.0, 1.0) * DRIVE_FORCE)
	apply_torque(Vector3.UP * clampf(steer, -1.0, 1.0) * TURN_TORQUE)

func _physics_process(_delta: float) -> void:
	var surface: String = MHCartSurfacePolicy.free_drive_surface(splat, global_position, grid)
	if surface == "water" and not _sunk_reported:
		_sunk_reported = true
		sunk.emit()
	var upright: float = global_transform.basis.y.dot(Vector3.UP)
	if upright < TIP_UP_DOT and not _tip_reported:
		_tip_reported = true
		tipped.emit()
		_shed_clubs()
	if linear_velocity.length() > 12.0 and absf(angular_velocity.y) > 2.2:
		_shed_clubs()

func _shed_clubs() -> void:
	if _clubs_shed or debris_root == null:
		return
	_clubs_shed = true
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

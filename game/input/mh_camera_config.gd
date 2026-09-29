class_name MHCameraConfig
extends Resource
## All camera tunables. Values are guesses until tuned on a phone.

@export_group("Distance")
@export var min_distance: float = 8.0
@export var max_distance: float = 120.0
@export var start_distance: float = 40.0

@export_group("Angles")
@export var start_yaw_deg: float = 0.0
@export var start_pitch_deg: float = 50.0
## Hard tilt limits (degrees above the ground plane).
@export var tilt_min_deg: float = 25.0
@export var tilt_max_deg: float = 70.0
## If true, tilt is derived from zoom (close = low angle, far = high angle) and
## manual tilt is disabled. Touch has no dedicated tilt gesture in Phase 0.
@export var tilt_follows_zoom: bool = true
@export var tilt_close_deg: float = 30.0
@export var tilt_far_deg: float = 65.0

@export_group("Sensitivity")
## Master multiplier applied to rotate, zoom and pan.
@export_range(0.2, 3.0, 0.05) var sensitivity: float = 1.0
@export var rotate_sensitivity: float = 1.0
@export var zoom_sensitivity: float = 1.0
@export var pan_sensitivity: float = 1.0
## Set to -1 if twist feels backwards on device.
@export var twist_sign: float = 1.0
## World units per pixel per unit of camera distance.
@export var pan_per_pixel: float = 0.0015

@export_group("Desktop")
@export var mouse_rotate_rad_per_px: float = 0.006
@export var mouse_tilt_deg_per_px: float = 0.2
@export var wheel_zoom_step: float = 0.1

@export_group("Inertia")
@export var inertia_enabled: bool = false
@export var inertia_damping: float = 4.0
@export var inertia_min_speed: float = 0.05

@export_group("Snap North")
## Higher = faster ease back to north.
@export var snap_ease_rate: float = 10.0

@export_group("Pan Bounds")
@export var use_pan_bounds: bool = false
## Bounds on target x (Rect2.x) and z (Rect2.y).
@export var pan_bounds: Rect2 = Rect2(-200.0, -200.0, 400.0, 400.0)

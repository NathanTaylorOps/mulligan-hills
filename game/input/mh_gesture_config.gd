class_name MHGestureConfig
extends Resource
## Tunables for MHGestureStateMachine. All values are starting guesses that
## must be tuned on a real phone.

## One finger must travel further than this (pixels) to start a stroke early.
@export var dead_zone_px: float = 10.0
## A stroke starts after the first finger has been down this long (ms) even
## without movement. A second finger inside this window means camera intent
## and no stroke ever starts. 0 = start immediately.
@export var commit_window_ms: int = 80
## Long-press option. If > 0, painting requires holding one finger still for
## this many ms. Moving beyond the dead zone earlier makes the touch inert
## until all fingers lift. Quick taps do nothing in this mode. 0 = off.
@export var long_press_ms: int = 0
## A quick tap (lift before commit) paints one dab (stroke_started + stroke_ended).
@export var tap_dab_enabled: bool = true
## New touches starting within this many pixels of a screen edge are ignored.
## 0 = off. Needs tracker.screen_size to be set.
@export var edge_margin_px: float = 0.0

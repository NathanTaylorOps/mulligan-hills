class_name MHGolferAnimator
extends Node
## Maps gameplay states to animation clips with crossfades, and reports the moment of ball impact.
##
## STATUS: NOT YET RUN. Uses AnimationPlayer.play(name, custom_blend) and the animation_finished
## signal, which exist in all Godot 4.x versions as far as we know (UNVERIFIED for the pinned version).

signal impact                       ## emitted once per swing or putt at the impact time
signal one_shot_finished(finished_state: int) ## emitted when a non-looping state's clip ends

enum State { IDLE, WALK, ADDRESS, PUTT, SWING_FULL }

const CLIP_FOR_STATE: Dictionary = {
	State.IDLE: &"idle",
	State.WALK: &"walk",
	State.ADDRESS: &"address",
	State.PUTT: &"putt",
	State.SWING_FULL: &"swing_full",
}

## After a one-shot state ends, go to this state.
const NEXT_AFTER: Dictionary = {
	State.PUTT: State.IDLE,
	State.SWING_FULL: State.IDLE,
}

## Impact time (seconds into clip) for states that hit a ball.
const IMPACT_AT: Dictionary = {
	State.PUTT: MHProceduralSwing.IMPACT_TIME_PUTT,
	State.SWING_FULL: MHProceduralSwing.IMPACT_TIME_SWING_FULL,
}

const DEFAULT_BLEND: float = 0.2

## Crossfade seconds per "from,to" pair, key format "FROM>TO" using State names. Missing pairs use DEFAULT_BLEND.
const BLEND: Dictionary = {
	"IDLE>WALK": 0.25,
	"WALK>IDLE": 0.25,
	"IDLE>ADDRESS": 0.35,
	"ADDRESS>SWING_FULL": 0.10,
	"ADDRESS>PUTT": 0.10,
	"SWING_FULL>IDLE": 0.40,
	"PUTT>IDLE": 0.30,
}

var state: int = State.IDLE
var _player: AnimationPlayer = null
var _impact_fired: bool = false


func setup(player: AnimationPlayer) -> void:
	_player = player
	if not _player.animation_finished.is_connected(_on_animation_finished):
		_player.animation_finished.connect(_on_animation_finished)


func set_state(new_state: int, force: bool = false) -> void:
	if _player == null:
		push_error("MHGolferAnimator: setup(player) not called")
		return
	if new_state == state and not force and _player.is_playing():
		return
	var blend: float = _blend_for(state, new_state)
	state = new_state
	_impact_fired = false
	var clip: StringName = CLIP_FOR_STATE[new_state]
	if not _player.has_animation(clip):
		push_error("MHGolferAnimator: missing clip %s" % String(clip))
		return
	_player.play(clip, blend)


func _blend_for(from_state: int, to_state: int) -> float:
	var k: String = "%s>%s" % [State.keys()[from_state], State.keys()[to_state]]
	if BLEND.has(k):
		return BLEND[k]
	return DEFAULT_BLEND


func _process(_delta: float) -> void:
	if _player == null or _impact_fired:
		return
	if not IMPACT_AT.has(state):
		return
	if not _player.is_playing():
		return
	var expected: StringName = CLIP_FOR_STATE[state]
	if _player.current_animation != String(expected):
		return  # still blending in from another clip
	if _player.current_animation_position >= float(IMPACT_AT[state]):
		_impact_fired = true
		impact.emit()


func _on_animation_finished(anim_name: StringName) -> void:
	if not CLIP_FOR_STATE.has(state):
		return
	if anim_name != CLIP_FOR_STATE[state]:
		return
	if NEXT_AFTER.has(state):
		var finished: int = state
		one_shot_finished.emit(finished)
		set_state(NEXT_AFTER[finished])

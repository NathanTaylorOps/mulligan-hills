class_name MHFirstLaunchFlow
extends RefCounted
## Pure state machine for the first launch: one consent screen (one tap), then the editor with a coach
## note until the first stroke lands, then a hint to open the rating panel. Time is passed in, so this
## is testable without a scene. Target (DEC-032, DEC-057): first stroke within 30 seconds of the
## consent screen appearing, with a single tap on the consent screen.

enum Step { CONSENT = 0, COACH_STROKE = 1, COACH_RATING = 2, DONE = 3 }

const BUDGET_MS: int = 30000
## Taps the player must make before the first stroke (consent Continue only).
const TAPS_BEFORE_STROKE: int = 1

var step: int = Step.CONSENT
var start_ms: int = 0
var first_stroke_ms: int = -1
var taps: int = 0


func begin(now_ms: int, consent_already_shown: bool) -> void:
	start_ms = now_ms
	first_stroke_ms = -1
	taps = 0
	step = Step.COACH_STROKE if consent_already_shown else Step.CONSENT


## The single tap on the consent screen (analytics choice is settings state, not a step).
func on_consent_continue() -> void:
	if step == Step.CONSENT:
		taps += 1
		step = Step.COACH_STROKE


func on_first_stroke(now_ms: int) -> void:
	if step == Step.COACH_STROKE:
		first_stroke_ms = maxi(0, now_ms - start_ms)
		step = Step.COACH_RATING


func on_rating_opened() -> void:
	if step == Step.COACH_RATING:
		step = Step.DONE


func skip() -> void:
	step = Step.DONE


func is_done() -> bool:
	return step == Step.DONE


func time_to_first_stroke_ms() -> int:
	return first_stroke_ms


func within_budget() -> bool:
	return first_stroke_ms >= 0 and first_stroke_ms <= BUDGET_MS


## Which screen id the shell should be showing for a step.
static func screen_for(p_step: int) -> String:
	if p_step == Step.CONSENT:
		return "consent"
	return "editor"


## Whether the coach overlay is shown on top of the editor for a step.
static func overlay_for(p_step: int) -> bool:
	return p_step == Step.COACH_STROKE or p_step == Step.COACH_RATING

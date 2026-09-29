class_name MHLeaderboardService
extends Node
## INTERFACE for leaderboards / platform sign-in (Play Games Services on Android, Game Center on iOS).
## Scores are int64-safe integers (the simulation is integer-only, workstream B).
## Leaderboard ids are logical names ("course_rating_best"); adapters map them to store ids via MHLeaderboardService.ID_MAP.

signal sign_in_changed(signed_in: bool)
signal score_submitted(board: String, ok: bool)

## Logical id -> platform id. Fill from Play Console / App Store Connect. Empty = not configured.
const ID_MAP_ANDROID: Dictionary = {}
const ID_MAP_IOS: Dictionary = {}

func is_supported() -> bool:
	return false

func is_signed_in() -> bool:
	return false

## Interactive or silent sign-in depending on platform. Result via sign_in_changed.
func sign_in() -> void:
	sign_in_changed.emit(false)

func submit_score(board: String, score: int) -> void:
	score_submitted.emit(board, false)

func show_leaderboard(board: String) -> void:
	pass

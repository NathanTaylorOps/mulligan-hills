class_name MHLeaderboardServiceMock
extends MHLeaderboardService

var signed_in: bool = false
var submitted: Array = []  # of {"board": String, "score": int}
var shown: PackedStringArray = PackedStringArray()

func is_supported() -> bool:
	return true

func is_signed_in() -> bool:
	return signed_in

func sign_in() -> void:
	signed_in = true
	sign_in_changed.emit(true)

func submit_score(board: String, score: int) -> void:
	if not signed_in:
		score_submitted.emit(board, false)
		return
	submitted.append({"board": board, "score": score})
	score_submitted.emit(board, true)

func show_leaderboard(board: String) -> void:
	shown.append(board)

class_name MHLeaderboardServiceIOS
extends MHLeaderboardService
## Game Center adapter STUB (design only). Candidate plugin found: github.com/sjc/godot-game-services
## ("Godot native plugins for iOS ...", unverified maturity/API). Godot has no first-party Game Center
## plugin for 4.x that we could confirm. Decision for Phase 0: interface only; iOS build ships without leaderboards
## until Phase 2 unless the spike in ios/README.md succeeds. Singleton name is UNVERIFIED.

const SINGLETON: String = "GameCenter"  # UNVERIFIED

func is_supported() -> bool:
	return Engine.has_singleton(SINGLETON)

func sign_in() -> void:
	# TODO(ios): call the plugin's authenticate method and emit sign_in_changed.
	sign_in_changed.emit(false)

func submit_score(board: String, _score: int) -> void:
	score_submitted.emit(board, false)

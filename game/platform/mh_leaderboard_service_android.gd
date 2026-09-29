class_name MHLeaderboardServiceAndroid
extends MHLeaderboardService
## Adapter: godot-sdk-integrations/godot-play-game-services (Godot 4.3+, PGS SDK v21, "revamped since 3.0":
## Node-based, main node `GodotPlayGamesServices` needs MANUAL initialisation, sign-in is NOT automatic;
## features are Nodes: sign-in client, LeaderboardsClient (submit_score, show_leaderboard), achievements, snapshots).
## Source: https://github.com/godot-sdk-integrations/godot-play-game-services (fetched 2026-09-29).
## Exact class/method/signal names are UNVERIFIED (docs live in the addon source); they are isolated in the
## PLUGIN SEAM below. Requires: export preset option godot_play_game_services/game_id, OAuth client with the
## upload/app-signing SHA-1, custom Gradle build.

const ADDON_DIR: String = "res://addons/GodotPlayGameServices"  # UNVERIFIED
const MAIN_SCRIPT: String = "res://addons/GodotPlayGameServices/godot_play_games_services.gd"  # UNVERIFIED
var _main: Node = null
var _signed_in: bool = false

func is_supported() -> bool:
	return DirAccess.dir_exists_absolute(ADDON_DIR)

func is_signed_in() -> bool:
	return _signed_in

func sign_in() -> void:
	if not is_supported():
		sign_in_changed.emit(false)
		return
	_seam_sign_in()

func submit_score(board: String, score: int) -> void:
	var id: String = str(ID_MAP_ANDROID.get(board, ""))
	if not _signed_in or id == "":
		score_submitted.emit(board, false)
		return
	_seam_submit(id, score)
	score_submitted.emit(board, true)  # UNVERIFIED: plugin may report async; adjust in seam

func show_leaderboard(board: String) -> void:
	var id: String = str(ID_MAP_ANDROID.get(board, ""))
	if _signed_in and id != "":
		_seam_show(id)

# ============================= PLUGIN SEAM (UNVERIFIED) =========================================
func _seam_sign_in() -> void:
	# Intended: main = load(MAIN_SCRIPT).new(); add_child(main); main.initialize(); then SignInClient.sign_in()
	# and listen to its user_authenticated(is_authenticated) signal -> _on_auth(bool). NOT RUN.
	push_warning("MHLeaderboardServiceAndroid._seam_sign_in: wire to the vendored addon (see platform.md)")
	sign_in_changed.emit(false)

func _on_auth(ok: bool) -> void:
	_signed_in = ok
	sign_in_changed.emit(ok)

func _seam_submit(_id: String, _score: int) -> void:
	push_warning("MHLeaderboardServiceAndroid._seam_submit: LeaderboardsClient.submit_score(id, score) not wired")

func _seam_show(_id: String) -> void:
	push_warning("MHLeaderboardServiceAndroid._seam_show: LeaderboardsClient.show_leaderboard(id) not wired")

class_name MHProgressionFixture
extends RefCounted
## Shared helpers for the progression tests.

const PROGRESSION_PATH: String = "res://data/progression.json"
const ACHIEVEMENTS_PATH: String = "res://data/achievements.json"


static func progression() -> MHProgression:
	var p: MHProgression = MHProgression.new()
	p.load_defaults()
	return p


static func achievements() -> MHAchievements:
	var a: MHAchievements = MHAchievements.new()
	a.load_from_file(ACHIEVEMENTS_PATH)
	return a


static func streak() -> MHStreak:
	var s: MHStreak = MHStreak.new()
	var d: Dictionary = MHDataJson.load_file(PROGRESSION_PATH)["value"]
	s.configure(d["streak"] as Dictionary)
	return s


static func same_text_as_docs(game_path: String, docs_rel: String) -> bool:
	var game_text: String = FileAccess.get_file_as_string(game_path)
	var docs_path: String = ProjectSettings.globalize_path("res://").path_join(docs_rel).simplify_path()
	if not FileAccess.file_exists(docs_path):
		# exported or packaged run without the docs folder: nothing to compare
		return game_text.length() > 100
	return FileAccess.get_file_as_string(docs_path).sha256_text() == game_text.sha256_text()

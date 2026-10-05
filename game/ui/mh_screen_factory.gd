class_name MHScreenFactory
extends RefCounted
## Builds a screen or modal from its id (see MHScreenIds). Kept apart from MHScreenIds so the screens, which use
## the id constants, do not form a cycle with the code that creates them.


## New (not yet set up) screen for an id, or null for an unknown id.
static func create(id: String) -> MHScreen:
	match id:
		"hud":
			return MHHudScreen.new()
		"build":
			return MHBuildScreen.new()
		"land":
			return MHLandScreen.new()
		"editor":
			return MHEditorScreen.new()
		"rating":
			return MHRatingScreen.new()
		"score":
			return MHScoreScreen.new()
		"daily":
			return MHDailyScreen.new()
		"tournament":
			return MHTournamentScreen.new()
		"achievements":
			return MHAchievementsScreen.new()
		"settings":
			return MHSettingsScreen.new()
		"consent":
			return MHConsentScreen.new()
		"tokens":
			return MHTokenStoreScreen.new()
		"tutorial_overlay":
			return MHOnboardingScreen.new()
		"bankruptcy":
			return MHBankruptcyDialog.new()
		"confirm_delete":
			return MHConfirmDeleteDialog.new()
	return null

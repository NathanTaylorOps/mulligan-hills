class_name MHScreenIds
extends RefCounted
## Screen and modal ids (docs/spec/interfaces/ui_shell.md uses the same ids where they exist). Order of ALL is the
## gallery order. Constants only, so screens can use it without a cyclic reference (see MHScreenFactory).

const HUD: String = "hud"
const BUILD: String = "build"
const LAND: String = "land"
const EDITOR: String = "editor"
const RATING: String = "rating"
const SCORE: String = "score"
const DAILY: String = "daily"
const TOURNAMENT: String = "tournament"
const ACHIEVEMENTS: String = "achievements"
const SETTINGS: String = "settings"
const CONSENT: String = "consent"
const TOKENS: String = "tokens"
const ONBOARDING: String = "tutorial_overlay"
const BANKRUPTCY: String = "bankruptcy"
const CONFIRM_DELETE: String = "confirm_delete"

const ALL: Array = [
	"hud", "build", "land", "editor", "rating", "score", "daily", "tournament", "achievements",
	"settings", "consent", "tokens", "tutorial_overlay", "bankruptcy", "confirm_delete",
]

## Ids shown as dialogs on top of the current screen (the shell treats them as modals).
const MODALS: Array = ["bankruptcy", "confirm_delete"]


static func is_modal(id: String) -> bool:
	return MODALS.has(id)


static func is_known(id: String) -> bool:
	return ALL.has(id)

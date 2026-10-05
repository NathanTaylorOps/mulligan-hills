# Phase 1: UI shell and screens (`game/ui/`)

> 5 October follow-up: `one_hole.md` adds an exact short-hole finalization/rating/save and aim-controlled practice prototype. Earlier zero-hole limits below describe the preceding increment. Legacy polygon conversion, full terrain authoring and finished golfer RPG remain unresolved. See `simgolf_controls_research.md` for Nathan's requested controls research.


Status: written 4 Oct 2026. NOT YET RUN. Nobody could run Godot here, so none of this GDScript has been parsed or executed by the engine. CI is the first test. Expect to fix parse errors and small type mistakes on the first red run.

## 1. What was built

All screens are built in code (no scene files except the gallery), use the system font, and ship no assets (DEC-062). Palette: background #FBF7EC, ink #17342A, accent #C8431F, green #2F6B4F (`MHTheme`).

Foundation (`game/ui/`)
- `mh_theme.gd`, `mh_layout.gd`, `mh_safe_area.gd`, `mh_format.gd`, `mh_screen_stack.gd`, `mh_tokens.gd`, `mh_ui_settings.gd`, `mh_first_launch_flow.gd`, `mh_editor_tools.gd`, `mh_advisor.gd`: written earlier, reviewed and fixed, see section 3.
- `mh_strings.gd` `MHStrings`: English string table (about 600 keys incl. the merged tournament, challenge and progression drafts, DRAFT text for Nathan to edit), `t(key, params)`, `tr_key`, `has_key`; a missing key returns `[key]` and logs once. A param named `x_key` is translated and offered as `{x}`.
- `mh_ui_context.gd` `MHUIContext`: settings, dp conversion, layout class, safe insets (pure `recompute`).
- `mh_screen_ids.gd` `MHScreenIds` (id constants), `mh_screen_factory.gd` `MHScreenFactory` (id to screen; separate files to avoid a cyclic class reference).
- `mh_ui_shell.gd` `MHUIShell`: screen stack, modal, toasts, theme, safe area, first-launch flow, router glue (`region_rects`, `trigger_region`). Implements `push_screen`, `pop_screen`, `show_modal`, `toast`, `set_mode`, `layout_class`, `text_scale_pct`, `left_handed`, `colorblind_palette` from `docs/spec/interfaces/ui_shell.md`. `load_language` and `MHResult` are not built (neither exists).
- `mh_ui_gallery.gd` + `mh_ui_gallery.tscn`: every screen and modal on sample data, with demo, token, cash, bankruptcy, text size and left-hand toggles. Added to `MHLauncher.SCENES`.
- Pure logic models: `mh_speed_control.gd`, `mh_build_menu_model.gd`, `mh_recovery_model.gd`, `mh_score_model.gd`.

Adapter (`game/ui/adapters/`)
- `mh_game_state_view.gd` `MHGameStateView`: READ-ONLY view the screens read. No setters, no buy, no spend. Row shapes are documented at the top of the file (hole rating, daily, tournament, achievement, recovery, product). Emits `changed`.
- `mh_fake_game_state_view.gd` `MHFakeGameStateView`: sample data about 12 days in (7 holes, one dead; clubhouse, pro shop and cart barn at tier 1; the 6-hole start plot; $18,450; 7 earned tokens; 22 members). Uses the real `MHBuildingDefs`, `MHGateView`, `MHLandModel`. `sample_*` methods change the sample for the gallery and tests; they are not contract. Income per tier and token pack prices are PLACEHOLDERS.
- `mh_progress_bridge.gd` `MHProgressBridge`: owns MHProgression, MHTournamentState and MHDailyState; read rows (`daily_row`, `tournament_rows` with `can_host`/`block_reason`, `tournament_event`, `achievement_rows`, level getters), intents `tournament_host {level}` and `daily_play`, save blocks. The fake view runs on it. `MHGameStateView` gained `tournament_event`, `club_level`, `club_points`, `points_for_next_level`, `level_title_key`. Tests: `test_progress_bridge.gd`.
- The real adapter (wrapping the clock, economy, buildings, land, ledger, rating engine) is the next task. Screens never call those modules directly.

Widgets (`game/ui/widgets/`)
- `MHTapButton` + `MHTouchBridge`: raw-touch taps (`emulate_mouse_from_touch` is false, so a finger never reaches a plain Button). Same approach as `MHGate0Panel`: press and release on the same button within 18 units. `scope` limits taps to the open modal. Drag scrolling for `MHScrollBox`.
- `MHScrollBox`, `MHUIKit` (static builders).

Screens (`game/ui/screens/`, `game/ui/modals/`), intents in brackets
- Home / Course HUD `MHHudScreen`: cash with net per day, day and time with day bar, speed 1x/2x/4x/8x with token-locked speeds (a locked speed sends the player to the token store), pause, course score with band, token balance, demo chip, bottom nav (Build, Land, Edit, Rating, Menu), left-handed mirror. [`set_speed`, `toggle_pause`, `nav`]
- Build menu `MHBuildScreen`: 10 buildings x 5 tiers (pips), next tier cost = target payback days x added daily income (DEC-050), up to 3 locked reasons per card, demo lock with unlock button, details card with all 5 tiers and gates. [`buy_tier`, `show_unlock`]
- Land `MHLandScreen`: 4x4 parcel map from `MHLandModel`, buyable only next to owned land, price, capacity. [`buy_parcel`]
- Hole editor toolbar `MHEditorScreen`: raise, lower, smooth, level, paint, brush radius, 11 surfaces (shown with Paint), Undo and Redo always visible, Done. Exposes `region_buttons()` for `MHInputRouter`. [`editor_tool`, `editor_undo`, `editor_redo`]
- Hole rating `MHRatingScreen`: hole picker, 0..100 score, four axes (Accuracy, Imagination, Length, Beauty) plus the Fairness modifier, advisor notes from reason codes (max 3, worst first, "More notes" shows all). Rating weights: Imagination 35, Accuracy 25, Length 20, Beauty 20; Fairness is a multiplier (rating-engine.md section 6). [`opened`]
- Course score `MHScoreScreen`: score and band, weakest hole, dead holes (DEC-063), next tier score gate, per-hole bars. [`nav`]
- Daily challenge `MHDailyScreen`: brief, target, attempts, streak, local board, kill-switch notice (DEC-059). [`daily_play`]
- Tournament `MHTournamentScreen`: four levels, status, entry checklist, cost and reward, demo preview (DEC-028). [`tournament_host`]
- Achievements `MHAchievementsScreen`: category filter, points, progress, hidden ones masked.
- Settings `MHSettingsScreen`: 30/60/auto fps, metric/imperial, analytics opt-in (default off), text size 80..160, left-handed, colour palette choice, restore purchases, replay tutorial, account deletion (confirm dialog), build info. [`settings_changed`, `restore_purchases`, `show_modal`, `replay_tutorial`]
- First-launch consent `MHConsentScreen`: one screen, one tap (Continue), analytics off unless toggled (DEC-057). [`consent_done`]
- Token store `MHTokenStoreScreen`: PLACEHOLDERS ONLY. Balances, what tokens do and do not do (DEC-053), three sample packs with disabled buttons. No purchase code and no intent starts a purchase.
- Bankruptcy recovery `MHBankruptcyDialog`: free bank loan with reputation penalty, token plan (earned and paid both count), not now. The shell opens it when `recovery_offer().active`. [`recovery_loan`, `recovery_tokens`, `recovery_later`]
- Account deletion confirm `MHConfirmDeleteDialog`. [`delete_account`]
- Onboarding `MHOnboardingScreen`: coach overlay on the editor that never blocks painting; driven by `MHFirstLaunchFlow` (consent, one tap, editor with coach, rating hint). [`skip_tutorial`]

## 2. How it is tested

Tests are in `game/tests/ui/` (gdUnit4, pure logic and headless node building). NOT YET RUN. Covered: formatting, theme and text scaling, dp and touch-target maths, contrast of the palette (checked once in Python: ink on background 12.6, white on accent 4.9, white on green 6.3), safe-area maths, layout classes, `MHUIContext`, strings (lookup, params, house style: ASCII, no em dash, no double spaces, placeholders; every key family the screens build exists), no literal text in `screens/`, `modals/`, `widgets/` (the CI grep check from the interface), the adapter contract (read-only method names, fake exposes only sample or private extras, row shapes, `gate_view` is a copy), build menu model (cost = payback x income, statuses, reasons, demo, heavy parcels), speed control, recovery, score model, screen stack, first-launch flow (one tap, 30 s budget), settings normalisers, touch picking, editor tools, advisor sorting, and a headless smoke test that builds and refreshes every screen on sample data, on empty data, and in portrait with left-handed layout and 160 percent text.

NOT covered: anything visual (layout, wrapping, colours on a real screen), real finger input, the shell in a live tree (`MHUIShell` itself has no test), the gallery scene.

## 3. Defects found in the earlier agent's work and fixed

- `MHLauncher` (the main scene) used plain Buttons. With `emulate_mouse_from_touch` false they ignore fingers, so the launcher would have been dead on a phone. It now uses `MHTapButton`, `MHScrollBox` and an `MHTouchBridge`.
- `mh_format.gd`: local variables named `sign` shadowed the built-in; renamed. Added `game_clock`, `day_number`, `day_progress_percent`, `score_from_pm`, `score_x10`, `speed_label`, and `@warning_ignore_start("integer_division")`.
- `mh_advisor.gd`: `sort_custom(_less)` changed to `sort_custom(MHAdvisor._less)` (a bare static function name inside a static function is the riskiest form).
- Reviewed with no change: theme, layout, safe area, screen stack, tokens, settings, first-launch flow, editor tools.

## Live adapter update (5 October 2026)

`MHLiveGameStateView` and `MHGameSession` now provide a live foundation; see `docs/phase1/gameplay.md`. The gallery remains sample-driven. Connecting the 3D scene, editor and validated autosave is still open. New GDScript tests await CI; no playable-game completion claimed.

## 4. Wiring (for the lead, when the real game scene exists)

1. Add the shell AFTER the game's `MHInputRouter` in the tree, so the shell's `_input` runs first and a tap on a button never paints. If that order is not possible, use the router: `for k in shell.region_rects(): router.register_ui_region(k, shell.region_rects()[k])` after every screen change, and connect `router.ui_tapped` to `shell.trigger_region`.
2. `shell.setup(view, settings)` (call after `add_child`; `settings` is a loaded `MHUISettings`; `view` is the real `MHGameStateView`). Then `shell.start_first_launch(Time.get_ticks_msec())`.
3. Connect `shell.intent(id, args)` to the game. The shell itself handles only navigation (`nav`, `show_modal`), consent, tutorial and closing dialogs; everything else (`buy_tier`, `buy_parcel`, `set_speed`, `toggle_pause`, `editor_tool`, `editor_undo`, `editor_redo`, `daily_play`, `tournament_host`, `restore_purchases`, `delete_account`, `recovery_*`, `show_unlock`, `settings_changed`) is for the game.
4. Call `shell.notify_first_stroke(Time.get_ticks_msec())` from `MHGestureStateMachine.stroke_started`.
5. Call `view.changed.emit()` whenever shown data changes.

## 5. Unverified assumptions

- Every GDScript construct (see the Phase 1 CI lessons in `docs/phase1/README.md`). Specific worries: `@warning_ignore_start`, `static var` in `MHStrings`, `Theme.set_type_variation` with a `Button` base, `Button.action_mode`, `find_children` argument order, lambdas returning typed values, `Script.get_script_method_list()` in the contract test, `match` on `Class.Enum.VALUE` patterns.
- Whether Godot also scrolls a `ScrollContainer` itself on `InputEventScreenDrag`. If it does, scrolling will double. Fix: set `MHTouchBridge.manual_scroll = false` (one line, in `mh_ui_shell.gd` and the launcher).
- Whether `Button` reacts to raw touch at all. The design assumes it does not (as `MHGate0Panel` documents). If it does, taps could fire twice; the bridge would then need to skip buttons the engine already handled.
- Game day display: the clock has 660 minutes per day (DEC-052). I show 7:00 AM to 6:00 PM (`MHFormat.DAY_START_MINUTE` = 420). The start hour is my placeholder.
- Token plan in the bankruptcy dialog: DEC-053 says tokens never buy cash, only recovery. I do not say what the token plan grants; the economy decides. The sample offer numbers (loan $5,000, penalty 15, 5 tokens) are placeholders.
- Speeds and token rates mirror `MHGameClock` (1, 2, 4, 8x at 0, 1, 2, 4 tokens per real minute).
- Palette choice (colour-blind) is stored and shown but does not change any colour yet.
- Strings: the table lives in code (`MHStrings.TABLE`) because `game/data/strings/en.json` does not exist. Advisor text exists for 21 reason codes only; other codes show "Advisor note RCnnn". Sample achievement names and the tournament, daily and building descriptions are my drafts, not approved content.

## 6. Risks and follow-ups

- Advisor keys: `MHAdvisor` names them `advisor.RCnnn` (uppercase), the localization spec says `advisor.<axis>.<reason_code>` in lowercase. Unreconciled. The strings test exempts `advisor.RC*` from the lowercase rule.
- Advisor severity: the interface doc says 0..2, the rating spec has five levels; the UI uses five (`MHAdvisor`).
- Achievement text: only 12 sample achievements have strings; the data file has 61. Missing ones render `[achievement.<id>.name]` until content writes them.
- Real adapter, string file, colour palettes, a real unlock screen (`show_unlock` intent has no screen), tutorial script beyond the two coach lines, tablet-specific layouts beyond column counts, and a tee sheet, commissions and event card screens (listed in the interface, not in this task) are all still to do.
- The coach overlay says "Two fingers move the camera"; that follows the gesture design in `docs/phase0/gestures.md` and must be kept in step with it.
- Text over 130 percent may wrap badly on the HUD chips on a small phone; needs a look on a device.

## 7. For Nathan

Nothing to run yet. When CI is green, the gallery is in the launcher as "UI gallery (every screen)": open it on the phone and tap through every screen. Tell the lead anything that is cut off, too small to tap, or unclear.

## 5 October: design pause

Editor toolbar now exposes pause/resume because editor mode hides the normal HUD. It uses the existing localized labels and session intent; a live-session smoke test covers both toggles. CI and phone layout verification remain pending. This does not complete the live scene/editor integration.

## Live construction connection (5 October)

`MHLiveGameStateView` now reads real terrain undo/redo history. The live construction scene connects editor intents and ordinary club menus to the real session; world input is suppressed on opaque pages/modals, stale pointer modes reset on suppression, and hidden overlays no longer contribute live region rects. See `live_construction.md` for save/scope limits. Phone layout and Godot interaction remain pending, not gallery/device sign-off.

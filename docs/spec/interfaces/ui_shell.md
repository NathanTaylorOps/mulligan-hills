# Interface: UI shell (`game/ui/`, owner assigned in Phase 1; gestures come from `game/input/` owner E)

## Implementation status (29 Sep 2026)
No `game/ui/` code exists (`MHUIShell`, `MHStrings`, `MHResult` are drafts). What exists in `game/input/` (owner E), which the shell will consume: `MHInputRouter` (`setup(controller, compass, overlay, sink: MHStrokeSink, screen_to_cell: Callable, gesture_config)`, `register_ui_region(region, rect_getter)`, signal `ui_tapped(region: StringName)`), `MHGestureStateMachine` (states IDLE, PENDING, PAINTING, CAMERA, IGNORED; signals `stroke_started/moved/ended/cancelled`, `camera_gesture`, `state_changed`), `MHStrokeSink` (`begin_stroke`, `apply_brush_at(cell_x, cell_y)`, `end_stroke`, `cancel_stroke`) with `MHForwardingStrokeSink(target)` which forwards to `MHTerrainEditor`, `MHStrokeBridge` (`NO_CELL` sentinel), `MHCameraController`, `MHOrbitRig`, `MHCompassButton`, `MHDebugOverlay`, `MHGestureConfig`, `MHCameraConfig`. The `MHUIMode` edit/watch/heatmap/menu modes and the rule "UI shell only forwards mode changes" have no code yet. The brush is chosen with `MHTerrainEditor.set_brush(mode, radius_cells, strength)`; there is no `MHUIMode`-to-brush mapping.

Purpose: screen navigation, layout for phone and tablet, theming and accessibility, string lookup, dialogs. Screens hold no game rules: they call the modules above. Layout is responsive from day one (phone portrait/landscape, tablet).

```gdscript
class_name MHUIShell extends Control       # root scene node
signal screen_changed(screen_id: String)
func push_screen(screen_id: String, args: Dictionary = {}) -> void
func pop_screen() -> void
func show_modal(modal_id: String, args: Dictionary = {}) -> void
func toast(key: String, params: Dictionary = {}) -> void      # key from the string table
func set_mode(mode: int) -> void                              # MHUIMode.EDIT, WATCH, HEATMAP, MENU: separate camera and brush modes
func layout_class() -> int                                    # PHONE_PORTRAIT, PHONE_LANDSCAPE, TABLET
func text_scale_pct() -> int                                  # accessibility, 80..160
func left_handed() -> bool
func colorblind_palette() -> int                              # 0 off, 1 deuteranopia, 2 protanopia, 3 tritanopia

class_name MHStrings extends RefCounted     # autoload "Strings"
func tr_key(key: String, params: Dictionary = {}) -> String   # missing key returns "[key]" and logs; never crashes
func has_key(key: String) -> bool
func load_language(lang: String) -> MHResult
```

## Screens (ids)
`editor`, `watch`, `heatmap`, `rating`, `advisor`, `club`, `building_card`, `land`, `tournament`, `tee_sheet`, `commissions`, `event_card`, `recap`, `settings`, `save_slots`, `unlock`, `consent`, `tutorial_overlay`, `photo`, `achievements`, `feedback`. Design status of several is unresolved (Master Plan: ratings, daily challenge, tournaments, building card, settings, tutorial are undesigned).

## Rules
- Land in the editor in under 30 seconds on first launch; consent and account prompts come later.
- Every user-visible string comes from `Strings` by key; no literal text in scenes (CI grep check).
- Touch targets at least 48 dp; text scale and left-handed layout honoured on every screen.
- Camera gestures (owner E): one finger paints, a second finger cancels the open stroke and moves the camera. UI shell only forwards mode changes.
- Undo/redo is always visible in EDIT mode.

## Consumers
Everything.

## Contract tests
Screen push/pop stack, missing-key behaviour, layout class switching at fixed viewport sizes, string-literal grep check, accessibility scale bounds.

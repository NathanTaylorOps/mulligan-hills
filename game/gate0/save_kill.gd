extends Node
## Gate 0 item 10 on the phone: save the 600 x 400 terrain repeatedly so a tester can force-kill the app
## mid-save, then relaunch and check the save. The scene verifies automatically on launch.
## See docs/phase0/gate0_scenes.md. NOT YET RUN.

const SAVE_INTERVAL_S: float = 0.5

var harness: MHGate0SaveHarness
var _panel: MHGate0Panel
var _repeating: bool = false
var _timer: float = 0.0
var _gen: int = 0
var _last_err: int = OK
var _saves_this_launch: int = 0
var _killer: Thread = null


func _ready() -> void:
	harness = MHGate0SaveHarness.new()
	_gen = harness.next_generation()
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_panel = MHGate0Panel.new()
	_panel.setup("Gate 0: kill during save (item 10)", "save_kill")
	layer.add_child(_panel)
	_panel.add_action(&"save", "Save now")
	_panel.add_action(&"repeat", "Start repeated saves")
	_panel.add_action(&"verify", "Load and verify")
	_panel.add_action(&"randkill", "Saves + random self-kill")
	_panel.add_action(&"killmid", "Save, kill mid write")
	_panel.add_action(&"killafter", "Save, kill before rename")
	_panel.add_action(&"clear", "Clear files and log")
	_panel.action.connect(_on_action)
	_panel.set_live("launch check ran automatically; repeated saves are OFF")
	_verify()


func _exit_tree() -> void:
	if _killer != null and _killer.is_started():
		_killer.wait_to_finish()


func _on_action(id: StringName) -> void:
	if id == &"save":
		_do_save()
		_panel.set_live("saved generation %d, error code %d" % [_gen - 1, _last_err])
	elif id == &"repeat":
		_repeating = not _repeating
		_panel.set_button_text(&"repeat", "Stop repeated saves" if _repeating else "Start repeated saves")
		_timer = SAVE_INTERVAL_S
	elif id == &"verify":
		_verify(false)
	elif id == &"randkill":
		_start_random_kill()
	elif id == &"killmid":
		_save_with_fault(1)
	elif id == &"killafter":
		_save_with_fault(2)
	elif id == &"clear":
		_clear()


func _do_save() -> void:
	_last_err = harness.save_generation(_gen)
	_gen += 1
	_saves_this_launch += 1


func _save_with_fault(mode: int) -> void:
	_panel.set_live("saving now; the app will kill itself inside the write ...")
	harness.fault_mode = mode
	harness.fault_kill = true
	harness.fault_target = "primary"
	_do_save()
	# Only reached if the kill did not happen (fault hooks return an error instead of killing).
	harness.fault_mode = 0
	_panel.set_live("kill did not happen; save returned error code %d" % _last_err)


func _start_random_kill() -> void:
	_repeating = true
	_timer = 0.0
	_panel.set_button_text(&"repeat", "Stop repeated saves")
	var delay_ms: int = 300 + int(randi() % 2500)
	_panel.set_live("repeated saves running; a background thread kills the app in %d ms" % delay_ms)
	_killer = Thread.new()
	_killer.start(Callable(self, "_kill_after").bind(delay_ms))


func _kill_after(delay_ms: int) -> void:
	OS.delay_msec(delay_ms)
	OS.kill(OS.get_process_id())


## write_log true = counts in the tally (launch check). The button re-check does not add to the tally.
func _verify(write_log: bool = true) -> void:
	var d: Dictionary = harness.verify(write_log)
	var parsed: Dictionary = MHGate0KillLog.parse(harness.read_log_text())
	var t: String = MHGate0Report.header_lines("kill-during-save verify") + "\n"
	t += MHGate0SaveHarness.format_verify(d) + "\n\n" + MHGate0KillLog.tally_text(parsed)
	t += "\n\nFor 200 kills: force-kill, relaunch, read RESULT here, repeat. Any CORRUPT or LOG MISMATCH is a FAIL.\n"
	t += "Next generation to save: %d\n\n" % _gen
	var res: String = "pass" if bool(d["judged_ok"]) and int((parsed["tally"] as Dictionary)["CORRUPT"]) == 0 else "fail"
	t += MHGate0Report.to_json(MHGate0Report.evidence_now("10_kill_save_android", res, {
		"last_verify": {"outcome": d["outcome"], "gen": d["gen"], "judged_ok": d["judged_ok"], "stale_tmp": d["stale_tmp"]},
		"tally": parsed["tally"], "saves_begun_total": parsed["begun"], "saves_finished_total": parsed["done"],
		"note": "kills counted = verifies after a save that was in flight; see gate0_scenes.md",
	}))
	_panel.set_result(t)


func _clear() -> void:
	_repeating = false
	_panel.set_button_text(&"repeat", "Start repeated saves")
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null:
		for p: String in [harness.primary_path, harness.backup_path(), MHTerrainSave.temp_path(harness.primary_path),
				MHTerrainSave.temp_path(harness.backup_path()), harness.log_path]:
			if FileAccess.file_exists(p):
				dir.remove(p.get_file())
	_gen = 0
	_panel.set_live("cleared")
	_verify(false)


func _process(delta: float) -> void:
	if not _repeating:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = SAVE_INTERVAL_S
		_do_save()
		_panel.set_live("repeated saves ON: generation %d done this launch: %d, last error %d. Force-kill the app any time." % [_gen - 1, _saves_this_launch, _last_err])

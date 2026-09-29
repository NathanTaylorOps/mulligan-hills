extends Node
## Gate 0 item 3 (sim hash on the phone) and the item 4 sim-cost figure. See docs/phase0/gate0_scenes.md.
## Runs the golden sim rows on launch, three passes, and shows PASS/FAIL per hash. NOT YET RUN.

var _panel: MHGate0Panel
var _passes: Array = []
var _busy: bool = false
var _cost_text: String = ""


func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_panel = MHGate0Panel.new()
	_panel.setup("Gate 0: sim hash (items 3 and 4)", "sim_hash")
	layer.add_child(_panel)
	_panel.add_action(&"run", "Run 3 passes")
	_panel.add_action(&"cost", "Sim cost 24x18")
	_panel.add_action(&"json", "Evidence JSON")
	_panel.action.connect(_on_action)
	_panel.set_result("Starting golden runs...")
	_run_passes.call_deferred(3)


func _on_action(id: StringName) -> void:
	if _busy:
		return
	if id == &"run":
		_passes.clear()
		_run_passes(3)
	elif id == &"cost":
		_run_cost()
	elif id == &"json":
		_show_json()


func _run_passes(count: int) -> void:
	_busy = true
	for p: int in range(count):
		var rows: Array = []
		for row: Variant in MHGate0Sim.RUNS:
			var d: Dictionary = row
			_panel.set_live("pass %d of %d: running %s ..." % [p + 1, count, MHGate0Sim.row_label(d)])
			await get_tree().process_frame
			await get_tree().process_frame
			rows.append(MHGate0Sim.run_one(d))
		_passes.append(rows)
		_refresh()
	_panel.set_live("done: %d passes so far" % _passes.size())
	_busy = false


func _refresh() -> void:
	var t: String = MHGate0Report.header_lines("sim hash golden runs")
	t += "\n" + MHGate0Sim.report_text(_passes)
	if _cost_text != "":
		t += "\n\n" + _cost_text
	_panel.set_result(t)


@warning_ignore("integer_division")
func _run_cost() -> void:
	_busy = true
	_panel.set_live("timing %d golfers x %d holes on the main thread ..." % [MHGate0Sim.COST_GOLFERS, MHGate0Sim.COST_HOLES])
	await get_tree().process_frame
	await get_tree().process_frame
	var lines: Array[String] = []
	var per_frame_list: Array[int] = []
	for i: int in range(3):
		var c: Dictionary = MHGate0Sim.time_cost_run()
		per_frame_list.append(int(c["per_frame_us"]))
		lines.append("run %d: whole round %d ms for %d simulated s = %d us per sim second, %d us per frame at %dx/%d fps" % [
			i + 1, int(c["sim_us"]) / 1000, int(c["sim_seconds"]), int(c["us_per_sim_s"]), int(c["per_frame_us"]), MHGate0Sim.COST_SPEED_X, MHGate0Sim.COST_FPS])
		await get_tree().process_frame
	per_frame_list.sort()
	var median: int = per_frame_list[1]
	_cost_text = "SIM COST (item 4 figure, MAIN THREAD, whole-round average, not a per-frame histogram)\n" + "\n".join(lines) \
		+ "\nmedian per frame: %d us -> %s\nThe real per-frame histogram on a worker thread needs the item 4 scene, which does not exist yet." % [
			median, MHGate0Sim.cost_verdict(median)]
	_refresh()
	_panel.set_live("cost measured")
	_busy = false


func _show_json() -> void:
	var f: Dictionary = MHGate0Sim.evidence_fields(_passes)
	var e: Dictionary = MHGate0Report.evidence_now("03_sim_hash_android", MHGate0Sim.overall_result(_passes), f)
	e["arch_arm64"] = OS.has_feature("arm64")
	e["arch_x86_64"] = OS.has_feature("x86_64")
	_panel.set_result(MHGate0Report.to_json(e))

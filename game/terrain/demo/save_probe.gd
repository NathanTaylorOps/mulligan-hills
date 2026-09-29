extends SceneTree
## Kill-during-save probe. Run headless as separate processes:
##   godot --headless --path game --script res://terrain/demo/save_probe.gd -- write user://probe.mhts mid
##   godot --headless --path game --script res://terrain/demo/save_probe.gd -- verify user://probe.mhts
## "write": saves the first version normally, prints its hash, mutates the grid, then saves again with the fault
## point (mid|after|bak) and KILL_PROCESS, so the process dies mid-save. "verify": loads the file and checks
## the fallback loader returns a complete valid old OR new save (hash file next to it). Exit code 0 = pass. NOT YET RUN.

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage: write|verify <path> [mid|after]")
		quit(2)
		return
	var mode: String = args[0]
	var path: String = args[1]
	var hash_path: String = path + ".hash"
	if mode == "write":
		var grid := MHHeightGrid.new(128, 128, 1000)
		grid.fill_lcg_noise(777, 500)
		var splat := MHSplatMap.new(grid.samples_x, grid.samples_y)
		var e1: int = MHTerrainSave.save_to_file(path, grid, splat)
		var f: FileAccess = FileAccess.open(hash_path, FileAccess.WRITE)
		var old_hash: int = grid.hash_fnv1a()
		print("first save err=", e1, " hash=", old_hash)
		MHBrush.apply_dab(grid, MHBrush.Mode.RAISE, 64, 64, 20, 4000, 0, null)
		f.store_string(str(old_hash) + "," + str(grid.hash_fnv1a()))
		f.close()
		var which: String = args[2] if args.size() > 2 else "after"
		if which == "mid":
			MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.MID_TEMP_WRITE
		elif which == "bak":
			MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.AFTER_BAK_ROTATE
		else:
			MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.AFTER_TEMP_WRITE
		MHTerrainSave.fault_action = MHTerrainSave.FaultAction.KILL_PROCESS
		MHTerrainSave.save_to_file(path, grid, splat)
		print("FAIL: process should have been killed before this line")
		quit(1)
	else:
		var res: MHTerrainSave.LoadResult = MHTerrainSave.load_with_fallback(path)
		var hf: FileAccess = FileAccess.open(hash_path, FileAccess.READ)
		var parts: PackedStringArray = hf.get_as_text().split(",")
		hf.close()
		var h_old: int = int(parts[0])
		var h_new: int = int(parts[1])
		if res.error == OK and (res.grid.hash_fnv1a() == h_old or res.grid.hash_fnv1a() == h_new):
			print("PASS: complete save loaded from ", res.source)
			quit(0)
		else:
			print("FAIL: err=", res.error, " ", res.message)
			quit(1)

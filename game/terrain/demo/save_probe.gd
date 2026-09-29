extends SceneTree
## Kill-during-save probe. Run headless as separate processes:
##   godot --headless --path game --script res://terrain/demo/save_probe.gd -- write user://probe.mhts mid
##   godot --headless --path game --script res://terrain/demo/save_probe.gd -- verify user://probe.mhts
## "write": saves version 1 normally, prints its hash, mutates the grid, then saves again with the fault
## point (mid|after) and KILL_PROCESS, so the process dies mid-save. "verify": loads the file and checks
## it is a complete valid version 1 (hash file next to it). Exit code 0 = pass. NOT YET RUN.

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
		f.store_string(str(grid.hash_fnv1a()))
		f.close()
		print("v1 saved err=", e1, " hash=", grid.hash_fnv1a())
		MHBrush.apply_dab(grid, MHBrush.Mode.RAISE, 64, 64, 20, 4000, 0, null)
		MHTerrainSave.fault_point = MHTerrainSave.FaultPoint.MID_TEMP_WRITE if (args.size() > 2 and args[2] == "mid") \
			else MHTerrainSave.FaultPoint.AFTER_TEMP_WRITE
		MHTerrainSave.fault_action = MHTerrainSave.FaultAction.KILL_PROCESS
		MHTerrainSave.save_to_file(path, grid, splat)
		print("FAIL: process should have been killed before this line")
		quit(1)
	else:
		var res: MHTerrainSave.LoadResult = MHTerrainSave.load_from_file(path)
		var hf: FileAccess = FileAccess.open(hash_path, FileAccess.READ)
		var expected: int = int(hf.get_as_text())
		hf.close()
		if res.error == OK and res.grid.hash_fnv1a() == expected:
			print("PASS: previous version intact")
			quit(0)
		else:
			print("FAIL: err=", res.error, " ", res.message)
			quit(1)

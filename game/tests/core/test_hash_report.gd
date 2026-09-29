extends GdUnitTestSuite
## Prints the simulation hashes in the format the determinism CI job compares across platforms:
## MH_HASH:<label>=<hex>. CI fails if any platform prints a different value for the same label.

func test_print_sim_hashes() -> void:
	var g: Dictionary = MHGolden.load_json("shotsim.json")
	var seed_v: int = MHGolden.i(g["course_seed"])
	var base_v: int = MHGolden.i(g["base_seed"])
	for row in g["runs"]:
		var golfers: int = MHGolden.i(row["golfers"])
		var holes: int = MHGolden.i(row["holes"])
		var res: Dictionary = MHSimHash.run(seed_v, base_v, golfers, holes, true)
		print("MH_HASH:sim_%dx%d=%s" % [golfers, holes, res["hash"]])
		assert_str(res["hash"]).is_equal(row["hash"])

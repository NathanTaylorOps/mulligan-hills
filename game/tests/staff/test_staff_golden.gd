extends GdUnitTestSuite
## Replays the Python reference scenarios (tools/reference/staff/gen_golden.py) through MHStaff and compares every
## recorded result, every state vector and the final save block. NOT YET RUN in Godot.

const MAX_REPORTED: int = 8


func _agg(st: MHStaff, view: Dictionary) -> Array:
	var ov: Dictionary = st.overlay(view)
	return [
		st.demand_permille(view), st.pace_points(), st.gate_staff_count(view), st.condition_penalty_permille(view),
		int(ov["beauty_delta_pm"]), int(ov["fairness_delta_pm"]), st.daily_payroll_cents(), st.grounds.avg_cond(st.defs, view),
		st.grounds.avg_pest(view), st.service_avg(view), st.head_count(),
	]


func _note(errs: Array, msg: String) -> void:
	if errs.size() < MAX_REPORTED:
		errs.append(msg)


func _same_ints(got: Array, want: Array) -> bool:
	if got.size() != want.size():
		return false
	for i: int in range(got.size()):
		if int(got[i]) != int(want[i]):
			return false
	return true


func _replay(sc: Dictionary) -> Array:
	var errs: Array = []
	var st: MHStaff = MHStaffFixture.staff()
	var kinds: Array = MHStaffFixture.kinds()
	var v0: Dictionary = sc["view"]
	var view: Dictionary = MHStaffView.make(v0["tiers"] as Dictionary, v0["owned"] as Array, kinds)
	var secret: int = int(sc["secret"])
	var idx: int = 0
	for row_v: Variant in (sc["ops"] as Array):
		var row: Dictionary = row_v
		var op: Dictionary = row["op"]
		var kind: String = str(op["op"])
		var tag: String = str(sc["name"]) + " op " + str(idx) + " " + kind
		idx += 1
		if kind == "view":
			view = MHStaffView.make(op["tiers"] as Dictionary, op["owned"] as Array, kinds)
		elif kind == "hire":
			var r: Dictionary = st.hire(str(op["role"]), int(op["day"]), view, int(op["cash"]))
			var want: Array = row["r"]
			var got_ok: int = 1 if bool(r["ok"]) else 0
			if got_ok != int(want[0]) or str(r["reason"]) != str(want[1]) or int(r["serial"]) != int(want[2]) or int(r["cost"]) != int(want[3]):
				_note(errs, tag + " hire result " + str(r) + " want " + str(want))
		elif kind == "fire":
			var f: int = 1 if st.fire(int(op["serial"])) else 0
			if f != int(row["r"]):
				_note(errs, tag + " fire")
		elif kind == "assign":
			var a: String = st.assign(int(op["serial"]), op["areas"] as Array, view)
			if a != str(row["r"]):
				_note(errs, tag + " assign '" + a + "' want '" + str(row["r"]) + "'")
		elif kind == "auto":
			if st.auto_assign(view) != int(row["r"]):
				_note(errs, tag + " auto")
		elif kind == "mow":
			if st.personal_mow(int(op["parcel"]), int(op["cells"]), int(op["cpp"]), view) != int(row["r"]):
				_note(errs, tag + " mow")
		elif kind == "patrol":
			if st.personal_patrol(int(op["parcel"]), int(op["cells"]), int(op["cpp"]), view) != int(row["r"]):
				_note(errs, tag + " patrol")
		elif kind == "pay":
			if st.pay_hour(int(op["hour"])) != int(row["r"]):
				_note(errs, tag + " pay")
		elif kind == "day":
			var res: Dictionary = st.on_day(int(op["day"]), view, secret)
			var wr: Array = row["r"]
			if (1 if bool(res["ran"]) else 0) != int(wr[0]):
				_note(errs, tag + " ran flag")
			var winc: Array = wr[1]
			var ginc: Array = res["incidents"]
			if ginc.size() != winc.size():
				_note(errs, tag + " incident count " + str(ginc.size()) + " want " + str(winc.size()))
			else:
				for i: int in range(ginc.size()):
					var gi: Dictionary = ginc[i]
					var wi: Array = winc[i]
					if int(gi["parcel"]) != int(wi[0]) or str(gi["kind"]) != str(wi[1]) or (1 if bool(gi["positive"]) else 0) != int(wi[2]) or (1 if bool(gi["handled"]) else 0) != int(wi[3]):
						_note(errs, tag + " incident " + str(gi) + " want " + str(wi))
			var gs: PackedInt64Array = st.state_list()
			var ws: Array = row["s"]
			var gsa: Array = []
			for x: int in gs:
				gsa.append(x)
			if not _same_ints(gsa, ws):
				_note(errs, tag + " state differs")
			if not _same_ints(_agg(st, view), row["a"] as Array):
				_note(errs, tag + " aggregates " + str(_agg(st, view)) + " want " + str(row["a"]))
	if not _same_ints(_agg(st, view), sc["final_agg"] as Array):
		_note(errs, str(sc["name"]) + " final aggregates")
	var got_save: Dictionary = st.to_save_block()
	var want_save: Dictionary = (sc["final_block"] as Dictionary).duplicate(true)
	# The Python reference goldens predate the optional equipment extension. Compare the
	# legacy state they actually specify while equipment has its own deterministic tests.
	if not want_save.has("equipment"):
		got_save.erase("equipment")
	var got_block: String = JSON.stringify(got_save, "", true)
	var want_block: String = JSON.stringify(want_save, "", true)
	if got_block != want_block:
		_note(errs, str(sc["name"]) + " final save block differs")
	return errs


func _scenario(scn: String) -> Dictionary:
	var g: Dictionary = MHStaffFixture.golden()
	for s: Variant in (g["scenarios"] as Array):
		if str((s as Dictionary)["name"]) == scn:
			return s
	return {}


func test_golden_file_loads() -> void:
	var g: Dictionary = MHStaffFixture.golden()
	assert_bool(g.is_empty()).is_false()
	assert_int((g["scenarios"] as Array).size()).is_equal(5)
	assert_array(g["kinds"] as Array).is_equal(MHStaffFixture.kinds())


func test_golden_split_matches() -> void:
	var g: Dictionary = MHStaffFixture.golden()
	for row: Variant in (g["split"] as Array):
		var r: Array = row
		var parts: Array = r[1]
		for h: int in range(11):
			assert_int(MHStaffMath.split_hour(int(r[0]), h)).is_equal(int(parts[h]))


func test_scenario_starter() -> void:
	assert_array(_replay(_scenario("starter"))).is_empty()


func test_scenario_neglect() -> void:
	assert_array(_replay(_scenario("neglect"))).is_empty()


func test_scenario_personal() -> void:
	assert_array(_replay(_scenario("personal"))).is_empty()


func test_scenario_rangers_handled_and_unhandled_incidents() -> void:
	assert_array(_replay(_scenario("rangers"))).is_empty()


func test_scenario_late_full_roster_grades_and_sightings() -> void:
	assert_array(_replay(_scenario("late"))).is_empty()

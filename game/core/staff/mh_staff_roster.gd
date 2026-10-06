class_name MHStaffRoster
extends RefCounted
## The employees: hiring, firing, area assignment, wages, gate head count. Pure integer logic; it never touches cash, the
## clock or the save. The caller takes `cost` from the economy after hire() and pays wages with pay_hour().
## Mirror of the roster part of tools/reference/staff/mh_staff.py. Spec: docs/spec/staff.md. NOT YET RUN.
##
## An employee is a Dictionary {serial, role, hired_day, tenure, areas}. areas is an ascending Array of parcel ids and is
## empty for station roles. Grade (trainee, regular, veteran) comes from tenure, so it is never stored.

var employees: Array = []
var next_serial: int = 1
var hires: int = 0
var fires: int = 0
var wages_cents: int = 0


func count() -> int:
	return employees.size()


func count_role(role_id: String) -> int:
	var n: int = 0
	for e: Variant in employees:
		if str((e as Dictionary)["role"]) == role_id:
			n += 1
	return n


func find_index(serial: int) -> int:
	for i: int in range(employees.size()):
		if int((employees[i] as Dictionary)["serial"]) == serial:
			return i
	return -1


## Copy of one employee, {} when the serial is unknown.
func employee(serial: int) -> Dictionary:
	var i: int = find_index(serial)
	if i < 0:
		return {}
	return (employees[i] as Dictionary).duplicate(true)


## Daily payroll in cents at the current grades.
func payroll(defs: MHStaffDefs) -> int:
	var total: int = 0
	for e: Variant in employees:
		var ed: Dictionary = e
		total += defs.wage(str(ed["role"]), int(ed["tenure"]))
	return total


## Wage due in game hour hour_index (0..10): the payroll split exactly over the 11 hours.
func hour_wage(defs: MHStaffDefs, hour_index: int) -> int:
	return MHStaffMath.split_hour(payroll(defs), hour_index)


## Same amount as hour_wage and also added to wages_cents. Call once per game hour, then take it from the economy.
func pay_hour(defs: MHStaffDefs, hour_index: int) -> int:
	var w: int = hour_wage(defs, hour_index)
	wages_cents += w
	return w


## "" when a trainee of this role can be hired now, else a reason code:
## bad_role, roster_full, no_building, role_cap, cash.
func check_hire(defs: MHStaffDefs, role_id: String, view: Dictionary, cash_cents: int) -> String:
	if not defs.has_role(role_id):
		return "bad_role"
	if employees.size() >= defs.param("max_employees"):
		return "roster_full"
	var t: int = MHStaffView.tier_of(view, defs.role_building(role_id))
	if t <= 0:
		return "no_building"
	if count_role(role_id) >= defs.cap(role_id, t):
		return "role_cap"
	var need: int = defs.hire_cost(role_id) + defs.param("hire_reserve_days") * (payroll(defs) + defs.wage(role_id, 0))
	if cash_cents < need:
		return "cash"
	return ""


## Adds a trainee when check_hire allows it. Returns {ok, reason, serial, cost}; the caller must take `cost` (cents)
## from the economy (spend) when ok. cash_cents is only used for the affordability check.
func hire(defs: MHStaffDefs, role_id: String, day: int, view: Dictionary, cash_cents: int) -> Dictionary:
	var why: String = check_hire(defs, role_id, view, cash_cents)
	if not why.is_empty():
		return {"ok": false, "reason": why, "serial": 0, "cost": 0}
	var s: int = next_serial
	next_serial += 1
	employees.append({"serial": s, "role": role_id, "hired_day": day, "tenure": 0, "areas": []})
	hires += 1
	return {"ok": true, "reason": "", "serial": s, "cost": defs.hire_cost(role_id)}


func fire(serial: int) -> bool:
	var i: int = find_index(serial)
	if i < 0:
		return false
	employees.remove_at(i)
	fires += 1
	return true


## Sets the areas (parcel ids) an employee works. [] unassigns. "" on success, else: no_employee, not_area_role,
## too_many_areas, bad_area, duplicate_area, not_owned. Nothing changes on an error.
func assign(defs: MHStaffDefs, serial: int, areas: Array, view: Dictionary) -> String:
	var i: int = find_index(serial)
	if i < 0:
		return "no_employee"
	var ed: Dictionary = employees[i]
	if defs.role_kind(str(ed["role"])) == MHStaffDefs.KIND_STATION:
		return "not_area_role"
	if areas.size() > defs.param("max_areas_per_employee"):
		return "too_many_areas"
	var seen: Array = []
	for a: Variant in areas:
		if typeof(a) != TYPE_INT:
			return "bad_area"
		var pid: int = int(a)
		if pid < 0 or pid >= MHStaffDefs.NPARCELS:
			return "bad_area"
		if seen.has(pid):
			return "duplicate_area"
		if not MHStaffView.is_owned(view, pid):
			return "not_owned"
		seen.append(pid)
	seen.sort()
	ed["areas"] = seen
	return ""


## How many employees of this kind ("grounds" or "pest") have the parcel in their areas.
func coverage_count(defs: MHStaffDefs, kind: String, parcel: int) -> int:
	var n: int = 0
	for e: Variant in employees:
		var ed: Dictionary = e
		if defs.role_kind(str(ed["role"])) == kind and (ed["areas"] as Array).has(parcel):
			n += 1
	return n


## Gives every grounds or pest employee with no area up to auto_assign_span parcels, least covered first (golf, then
## facility, then homes; ties by lowest id). Employees are taken in serial order. Returns how many were assigned.
func auto_assign(defs: MHStaffDefs, view: Dictionary) -> int:
	var span: int = defs.param("auto_assign_span")
	var order: Array = []
	for k: String in MHStaffDefs.PARCEL_KINDS:
		for pid: int in range(MHStaffDefs.NPARCELS):
			if MHStaffView.kind_of(view, pid) == k and MHStaffView.is_owned(view, pid):
				order.append(pid)
	var assigned: int = 0
	if order.is_empty():
		return 0
	# employees are appended in serial order and never reordered, so index order is serial order
	for e: Variant in employees:
		var ed: Dictionary = e
		var kind: String = defs.role_kind(str(ed["role"]))
		if kind == MHStaffDefs.KIND_STATION or not (ed["areas"] as Array).is_empty():
			continue
		var chosen: Array = []
		var picks: int = mini(span, order.size())
		for _i: int in range(picks):
			var best: int = -1
			var best_c: int = 1 << 30
			for pid2: Variant in order:
				var pp: int = int(pid2)
				if chosen.has(pp):
					continue
				var c: int = coverage_count(defs, kind, pp)
				if c < best_c:
					best = pp
					best_c = c
			chosen.append(best)
		chosen.sort()
		ed["areas"] = chosen
		assigned += 1
	return assigned


## Head count the tournament gate sees: employees with tenure >= tenure_gate_days whose building stands.
func gate_count(defs: MHStaffDefs, view: Dictionary) -> int:
	var n: int = 0
	var need: int = defs.param("tenure_gate_days")
	for e: Variant in employees:
		var ed: Dictionary = e
		if int(ed["tenure"]) >= need and MHStaffView.tier_of(view, defs.role_building(str(ed["role"]))) >= 1:
			n += 1
	return n


## The four counters of save.schema.json club.staff, derived from the roster. Their sum is the head count.
func legacy_counts(defs: MHStaffDefs) -> Dictionary:
	var out: Dictionary = {"greenkeepers": 0, "marshals": 0, "pro_shop_staff": 0, "caterers": 0}
	for e: Variant in employees:
		var g: String = defs.role_legacy(str((e as Dictionary)["role"]))
		out[g] = int(out[g]) + 1
	return out


## Sum over the employees of a role of their work_permille (1000 per trainee).
func role_work_sum(defs: MHStaffDefs, role_id: String) -> int:
	var total: int = 0
	for e: Variant in employees:
		var ed: Dictionary = e
		if str(ed["role"]) == role_id:
			total += defs.work_permille(int(ed["tenure"]))
	return total


## Adds the points of one employee over its owned areas into acc (ascending parcel id, remainder to the lowest ids).
func _split_over_areas(ed: Dictionary, total: int, view: Dictionary, acc: Array) -> void:
	var areas: Array = []
	for a: Variant in (ed["areas"] as Array):
		if MHStaffView.is_owned(view, int(a)):
			areas.append(int(a))
	if areas.is_empty() or total <= 0:
		return
	var n: int = areas.size()
	var share: int = MHStaffMath.idiv(total, n)
	var rem: int = total - share * n
	for i: int in range(n):
		var pid: int = int(areas[i])
		acc[pid] = int(acc[pid]) + share + (1 if i < rem else 0)


## {"work": Array of 16, "ctrl": Array of 16}: grounds work points and pest control points each owned parcel gets today.
func work_by_parcel(defs: MHStaffDefs, view: Dictionary, equipment: MHStaffEquipment = null) -> Dictionary:
	var work: Array = []
	var ctrl: Array = []
	for _i: int in range(MHStaffDefs.NPARCELS):
		work.append(0)
		ctrl.append(0)
	for e: Variant in employees:
		var ed: Dictionary = e
		var kind: String = defs.role_kind(str(ed["role"]))
		var wp: int = defs.work_permille(int(ed["tenure"]))
		if equipment != null and (kind == MHStaffDefs.KIND_GROUNDS or kind == MHStaffDefs.KIND_PEST):
			wp = MHStaffMath.idiv(wp * equipment.multiplier_for_employee(int(ed["serial"]), kind), 1000)
		if kind == MHStaffDefs.KIND_GROUNDS:
			_split_over_areas(ed, MHStaffMath.idiv(defs.param("keeper_work") * wp, 1000), view, work)
		elif kind == MHStaffDefs.KIND_PEST:
			_split_over_areas(ed, MHStaffMath.idiv(defs.param("ranger_control") * wp, 1000), view, ctrl)
	return {"work": work, "ctrl": ctrl}


## Every employee is one day older.
func age_one_day() -> void:
	for e: Variant in employees:
		var ed: Dictionary = e
		ed["tenure"] = int(ed["tenure"]) + 1


func reset() -> void:
	employees = []
	next_serial = 1
	hires = 0
	fires = 0
	wages_cents = 0

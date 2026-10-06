class_name MHStaff
extends RefCounted
## Facade the game session talks to: roster + grounds + effects behind one narrow API. It never touches cash, the clock,
## the economy or the save file; the caller takes money out of the economy and writes to_save_block() into the save.
## Spec: docs/spec/staff.md. Status: docs/phase1/staff.md. NOT YET RUN.
##
## Session wiring (all calls once per event):
##   hire:      var r = staff.hire(role, day, view, cash_cents); if r.ok: economy.spend(r.cost)
##   each hour: var w = staff.pay_hour(hour_index_before_tick); economy.incur_loss(w)
##   each day:  var res = staff.on_day(day, view, save_secret); economy.set_demand_modifier(events_permille * staff.demand_permille(view) / 1000)
##   gates:     view_for_tournaments["staff"] = staff.gate_staff_count(view)
##   save:      club.staff_roster = staff.to_save_block(); club.staff = staff.legacy_counts()
## "view" is built with MHStaffView.make(tiers, owned_parcel_ids, parcel_kinds).

const SAVE_VERSION: int = 1
const STAT_KEYS: Array = ["hires", "fires", "wages_cents", "incidents_hit", "incidents_handled", "sightings"]
const MAX_STAT: int = 9007199254740991
const MAX_DAY: int = 1000000

var defs: MHStaffDefs
var roster: MHStaffRoster = MHStaffRoster.new()
var grounds: MHStaffGrounds = MHStaffGrounds.new()
var equipment: MHStaffEquipment = MHStaffEquipment.new()


## A fresh club with no employees. Returns null when the defs are not loaded.
static func create(staff_defs: MHStaffDefs) -> MHStaff:
	if staff_defs == null or not staff_defs.is_loaded():
		return null
	var s: MHStaff = MHStaff.new()
	s.defs = staff_defs
	s.grounds.reset(staff_defs)
	return s


# ------------------------------------------------------------------ roster
func check_hire(role_id: String, view: Dictionary, cash_cents: int) -> String:
	return roster.check_hire(defs, role_id, view, cash_cents)


func hire(role_id: String, day: int, view: Dictionary, cash_cents: int) -> Dictionary:
	return roster.hire(defs, role_id, day, view, cash_cents)


func fire(serial: int) -> bool:
	if not roster.fire(serial):
		return false
	equipment.unassign_employee(serial)
	return true


func assign(serial: int, areas: Array, view: Dictionary) -> String:
	return roster.assign(defs, serial, areas, view)


func auto_assign(view: Dictionary) -> int:
	return roster.auto_assign(defs, view)


func head_count() -> int:
	return roster.count()


## Head count for MHTournamentRules.entry_report ("staff"): only employees with tenure >= tenure_gate_days count, so hiring
## for one day to pass the gate does not work.
func gate_staff_count(view: Dictionary) -> int:
	return roster.gate_count(defs, view)


func legacy_counts() -> Dictionary:
	return roster.legacy_counts(defs)


# ------------------------------------------------------------------ money
func daily_payroll_cents() -> int:
	return roster.payroll(defs)


## Wage in cents due in game hour hour_index (0..10) without side effects.
func hour_wage_cents(hour_index: int) -> int:
	return roster.hour_wage(defs, hour_index)


## Wage in cents due in game hour hour_index, counted in the stats. The caller takes it from the economy, for example
## with MHEconomy.incur_loss(wage) right after tick_hour() (use the hour index the tick just handled).
func pay_hour(hour_index: int) -> int:
	return roster.pay_hour(defs, hour_index)



# ------------------------------------------------------------------ equipment
func equipment_price(type_id: String) -> int:
	if not MHStaffEquipment.TYPES.has(type_id):
		return 0
	return int((MHStaffEquipment.TYPES[type_id] as Dictionary)["price"])


func equipment_capacity(view: Dictionary) -> int:
	var tier: int = MHStaffView.tier_of(view, "maintenance")
	return [0, 3, 6, 10, 16, 24][clampi(tier, 0, 5)]


func buy_equipment(type_id: String, cash_cents: int, view: Dictionary = {}) -> Dictionary:
	var price: int = equipment_price(type_id)
	if price <= 0:
		return {"ok": false, "reason": "bad_type", "serial": 0, "cost": 0}
	if cash_cents < price:
		return {"ok": false, "reason": "cash", "serial": 0, "cost": 0}
	if not view.is_empty() and equipment.units.size() >= equipment_capacity(view):
		return {"ok": false, "reason": "workshop_capacity", "serial": 0, "cost": 0}
	var result: Dictionary = equipment.add_unit(type_id)
	if not bool(result["ok"]):
		return {"ok": false, "reason": "capacity", "serial": 0, "cost": 0}
	return {"ok": true, "reason": "", "serial": int(result["serial"]), "cost": price}




func sell_equipment(equipment_serial: int) -> Dictionary:
	var value: int = equipment.sell_unit(equipment_serial)
	return {"ok": value > 0, "value": value}


func assign_equipment(equipment_serial: int, employee_serial: int) -> bool:
	var ed: Dictionary = roster.employee(employee_serial)
	if ed.is_empty():
		return false
	var kind: String = defs.role_kind(str(ed["role"]))
	if kind != MHStaffDefs.KIND_GROUNDS and kind != MHStaffDefs.KIND_PEST:
		return false
	return equipment.assign_unit(equipment_serial, employee_serial, kind)



func technician_work_permille() -> int:
	# Technician support is intentionally separate from grounds output: it maintains machines.
	# The role becomes active when present in staff definitions; until then there is no free repair labor.
	if not defs.has_role("equipment_technician"):
		return 0
	return roster.role_work_sum(defs, "equipment_technician")


func superintendent_coordination_permille() -> int:
	if not defs.has_role("superintendent"):
		return 1000
	var work: int = roster.role_work_sum(defs, "superintendent")
	return 1000 + mini(200, MHStaffMath.idiv(work, 10))



func equipment_operating_cost_cents() -> int:
	return equipment.operating_cost_for_day()


func equipment_repair_cost_cents() -> int:
	return equipment.repair_cost_for_day()



func management_warnings(view: Dictionary) -> Array:
	var out: Array = []
	var worn: int = 0
	var broken: int = 0
	for v: Variant in equipment.units:
		var u: Dictionary = v
		var state: String = equipment.condition_state(int(u["serial"]))
		if state == "broken":
			broken += 1
		elif state == "worn":
			worn += 1
	if broken > 0:
		out.append({"kind": "equipment_broken", "severity": 2, "count": broken})
	elif worn > 0:
		out.append({"kind": "equipment_worn", "severity": 1, "count": worn})
	if equipment.units.size() >= equipment_capacity(view) and equipment_capacity(view) > 0:
		out.append({"kind": "workshop_capacity", "severity": 1, "count": equipment.units.size()})
	if grounds.avg_cond(defs, view) < defs.param("sat_cond_floor"):
		out.append({"kind": "course_condition", "severity": 2, "value": grounds.avg_cond(defs, view)})
	if broken > 0 and technician_work_permille() <= 0:
		out.append({"kind": "technician_needed", "severity": 2, "count": broken})
	return out

# ------------------------------------------------------------------ grounds
func personal_mow(parcel: int, cells: int, cells_per_parcel: int, view: Dictionary) -> int:
	return grounds.personal_mow(defs, parcel, cells, cells_per_parcel, view)


func personal_patrol(parcel: int, cells: int, cells_per_parcel: int, view: Dictionary) -> int:
	return grounds.personal_patrol(defs, parcel, cells, cells_per_parcel, view)


## One game day: grounds update with the incident rolls, then every employee gets one day of tenure. Idempotent per day.
## Returns {"ran": bool, "incidents": Array of {parcel, kind, positive, handled}}.
func on_day(day: int, view: Dictionary, secret: int) -> Dictionary:
	var res: Dictionary = grounds.on_day(defs, roster, day, view, secret, equipment)
	if bool(res["ran"]):
		equipment.on_day(MHStaffView.tier_of(view, "maintenance"), technician_work_permille(), res.get("used_employees", []) as Array)
	if bool(res["ran"]):
		roster.age_one_day()
	return res


func condition_of(parcel: int) -> int:
	if parcel < 0 or parcel >= MHStaffDefs.NPARCELS:
		return 0
	return int(grounds.condition[parcel])


func pest_of(parcel: int) -> int:
	if parcel < 0 or parcel >= MHStaffDefs.NPARCELS:
		return 0
	return int(grounds.pest[parcel])


# ------------------------------------------------------------------ effects
func demand_permille(view: Dictionary) -> int:
	return MHStaffEffects.demand_permille(defs, roster, grounds, view)


func pace_points() -> int:
	return MHStaffEffects.pace_points(defs, roster)


func condition_penalty_permille(view: Dictionary) -> int:
	return MHStaffEffects.condition_penalty_permille(defs, grounds, view)


func overlay(view: Dictionary) -> Dictionary:
	return MHStaffEffects.overlay(defs, grounds, view)


func service_avg(view: Dictionary) -> int:
	return MHStaffEffects.service_avg(defs, roster, view)


## Everything a status screen needs in one Dictionary.
func report(view: Dictionary) -> Dictionary:
	var ov: Dictionary = overlay(view)
	return {
		"head_count": roster.count(), "gate_staff": gate_staff_count(view), "payroll_cents": daily_payroll_cents(),
		"avg_condition": grounds.avg_cond(defs, view), "avg_pest": grounds.avg_pest(view),
		"service": service_avg(view), "demand_permille": demand_permille(view), "pace_points": pace_points(),
		"satisfaction_penalty_permille": condition_penalty_permille(view), "equipment_units": equipment.units.size(), "equipment_capacity": equipment_capacity(view),
		"equipment_operating_cost_cents": equipment_operating_cost_cents(), "equipment_repair_cost_cents": equipment_repair_cost_cents(),
		"warnings": management_warnings(view),
		"beauty_delta_pm": int(ov["beauty_delta_pm"]), "fairness_delta_pm": int(ov["fairness_delta_pm"]),
	}


# ------------------------------------------------------------------ save
func stats() -> Dictionary:
	return {
		"hires": roster.hires, "fires": roster.fires, "wages_cents": roster.wages_cents,
		"incidents_hit": grounds.incidents_hit, "incidents_handled": grounds.incidents_handled, "sightings": grounds.sightings,
	}


## Flat list of every state integer, in the same order as the Python reference state_list(): used by the golden tests.
func state_list() -> PackedInt64Array:
	var out: PackedInt64Array = PackedInt64Array()
	out.append(roster.next_serial)
	out.append(grounds.last_day)
	out.append(roster.employees.size())
	for e: Variant in roster.employees:
		var ed: Dictionary = e
		var areas: Array = ed["areas"]
		out.append(int(ed["serial"]))
		out.append(defs.role_index(str(ed["role"])))
		out.append(int(ed["hired_day"]))
		out.append(int(ed["tenure"]))
		out.append(areas.size())
		for a: Variant in areas:
			out.append(int(a))
	for arr: Array in [grounds.condition, grounds.pest, grounds.personal_work, grounds.personal_pest]:
		for x: Variant in arr:
			out.append(int(x))
	var st: Dictionary = stats()
	for k: Variant in STAT_KEYS:
		out.append(int(st[str(k)]))
	return out


## Exactly the shape of save.schema.json club.staff_roster (optional in the schema). Plain ints, Strings, Arrays.
func to_save_block() -> Dictionary:
	var emps: Array = []
	for e: Variant in roster.employees:
		var ed: Dictionary = e
		emps.append({"serial": int(ed["serial"]), "role": str(ed["role"]), "hired_day": int(ed["hired_day"]), "tenure": int(ed["tenure"]), "areas": (ed["areas"] as Array).duplicate()})
	return {
		"v": SAVE_VERSION,
		"next_serial": roster.next_serial,
		"last_day": grounds.last_day,
		"employees": emps,
		"condition": grounds.condition.duplicate(),
		"pest": grounds.pest.duplicate(),
		"personal_work": grounds.personal_work.duplicate(),
		"personal_pest": grounds.personal_pest.duplicate(),
		"stats": stats(),
		"equipment": equipment.to_save_block(),
	}


## Replaces the whole state from a save block. A save written before staff existed has no block: do not call this, the
## fresh state from create() is the documented default. Returns false and changes nothing when the block is invalid.
func from_save_block(block: Dictionary) -> bool:
	var errs: Array = []
	var norm: Variant = MHDataJson.normalize(block, errs, "$")
	if not errs.is_empty() or typeof(norm) != TYPE_DICTIONARY:
		return false
	var b: Dictionary = norm
	if not MHDataJson.is_int_in(b.get("v", null), SAVE_VERSION, SAVE_VERSION):
		return false
	if not MHDataJson.is_int_in(b.get("next_serial", null), 1, 1000000000):
		return false
	if not MHDataJson.is_int_in(b.get("last_day", null), -1, MAX_DAY):
		return false
	if b.has("equipment") and typeof(b["equipment"]) != TYPE_DICTIONARY:
		return false
	var emps: Array = []
	if typeof(b.get("employees", null)) != TYPE_ARRAY:
		return false
	var src: Array = b["employees"]
	if src.size() > defs.param("max_employees"):
		return false
	var last_serial: int = 0
	for v: Variant in src:
		var ed: Variant = _clean_employee(v, int(b["next_serial"]), last_serial)
		if typeof(ed) != TYPE_DICTIONARY:
			return false
		last_serial = int((ed as Dictionary)["serial"])
		emps.append(ed)
	var cond: Variant = _clean_array(b.get("condition", null), 0, 1000)
	var pst: Variant = _clean_array(b.get("pest", null), 0, 1000)
	var pw: Variant = _clean_array(b.get("personal_work", null), 0, defs.param("personal_daily_cap"))
	var pp: Variant = _clean_array(b.get("personal_pest", null), 0, defs.param("personal_patrol_cap"))
	if cond == null or pst == null or pw == null or pp == null:
		return false
	if typeof(b.get("stats", null)) != TYPE_DICTIONARY:
		return false
	var restored_equipment: MHStaffEquipment = MHStaffEquipment.new()
	var equipment_block: Variant = b.get("equipment", null)
	if equipment_block != null and (typeof(equipment_block) != TYPE_DICTIONARY or not restored_equipment.from_save_block(equipment_block as Dictionary)):
		return false
	var st: Dictionary = b["stats"]
	if st.size() != STAT_KEYS.size():
		return false
	for k: Variant in STAT_KEYS:
		if not MHDataJson.is_int_in(st.get(str(k), null), 0, MAX_STAT):
			return false
	equipment = restored_equipment
	roster.employees = emps
	roster.next_serial = int(b["next_serial"])
	roster.hires = int(st["hires"])
	roster.fires = int(st["fires"])
	roster.wages_cents = int(st["wages_cents"])
	grounds.condition = cond as Array
	grounds.pest = pst as Array
	grounds.personal_work = pw as Array
	grounds.personal_pest = pp as Array
	grounds.last_day = int(b["last_day"])
	grounds.incidents_hit = int(st["incidents_hit"])
	grounds.incidents_handled = int(st["incidents_handled"])
	grounds.sightings = int(st["sightings"])
	return true


## Returns a cleaned employee Dictionary, or null when the entry is invalid. Serials must rise strictly (that is the
## order auto_assign relies on) and stay under next_serial.
func _clean_employee(v: Variant, next_serial: int, last_serial: int) -> Variant:
	if typeof(v) != TYPE_DICTIONARY:
		return null
	var e: Dictionary = v
	if e.size() != 5:
		return null
	if not MHDataJson.is_int_in(e.get("serial", null), last_serial + 1, next_serial - 1):
		return null
	if typeof(e.get("role", null)) != TYPE_STRING or not defs.has_role(str(e["role"])):
		return null
	if not MHDataJson.is_int_in(e.get("hired_day", null), 0, MAX_DAY) or not MHDataJson.is_int_in(e.get("tenure", null), 0, MAX_DAY):
		return null
	if typeof(e.get("areas", null)) != TYPE_ARRAY:
		return null
	var areas: Array = e["areas"]
	if areas.size() > defs.param("max_areas_per_employee"):
		return null
	if defs.role_kind(str(e["role"])) == MHStaffDefs.KIND_STATION and not areas.is_empty():
		return null
	var out_areas: Array = []
	var prev: int = -1
	for a: Variant in areas:
		if not MHDataJson.is_int_in(a, 0, MHStaffDefs.NPARCELS - 1) or int(a) <= prev:
			return null
		prev = int(a)
		out_areas.append(int(a))
	return {"serial": int(e["serial"]), "role": str(e["role"]), "hired_day": int(e["hired_day"]), "tenure": int(e["tenure"]), "areas": out_areas}


func _clean_array(v: Variant, lo: int, hi: int) -> Variant:
	if not MHDataJson.is_int_array(v, MHStaffDefs.NPARCELS, lo, hi):
		return null
	var out: Array = []
	for x: Variant in (v as Array):
		out.append(int(x))
	return out

class_name MHStaffEquipment
extends RefCounted
## Deterministic equipment fleet used by grounds and pest staff. Equipment is capacity, not decoration:
## operator tenure determines skill, machine condition determines reliability, and maintenance tier determines recovery.

const SAVE_VERSION: int = 1
const MAX_UNITS: int = 64
const TYPES: Dictionary = {
	"greens_mower": {"kind": "grounds", "work_pm": 1250, "wear": 18, "price": 180000},
	"fairway_mower": {"kind": "grounds", "work_pm": 1150, "wear": 14, "price": 240000},
	"utility_vehicle": {"kind": "grounds", "work_pm": 1080, "wear": 10, "price": 120000},
	"aerator": {"kind": "grounds", "work_pm": 1200, "wear": 16, "price": 160000},
	"sprayer": {"kind": "pest", "work_pm": 1200, "wear": 15, "price": 110000},
	"ranger_vehicle": {"kind": "pest", "work_pm": 1125, "wear": 12, "price": 140000},
}
var units: Array = []
var next_serial: int = 1
var operating_cost_cents: int = 0
var repair_cost_cents: int = 0

func add_unit(type_id: String) -> Dictionary:
	if not TYPES.has(type_id) or units.size() >= MAX_UNITS:
		return {"ok": false, "serial": 0, "price": 0}
	var d: Dictionary = TYPES[type_id]
	var serial: int = next_serial
	next_serial += 1
	units.append({"serial": serial, "type": type_id, "condition": 1000, "broken": false, "assigned_employee": 0})
	return {"ok": true, "serial": serial, "price": int(d["price"])}

func assign_unit(serial: int, employee_serial: int, employee_kind: String) -> bool:
	for v: Variant in units:
		var u: Dictionary = v
		if int(u["serial"]) != serial:
			continue
		var d: Dictionary = TYPES[str(u["type"])]
		if str(d["kind"]) != employee_kind or bool(u["broken"]):
			return false
		# The current work model has one active machine per worker. Moving an operator to
		# another compatible unit must release the old machine or both units would wear/cost.
		unassign_employee(employee_serial)
		u["assigned_employee"] = employee_serial
		return true
	return false


func unassign_employee(employee_serial: int) -> void:
	for v: Variant in units:
		var u: Dictionary = v
		if int(u.get("assigned_employee", 0)) == employee_serial:
			u["assigned_employee"] = 0


func condition_state(serial: int) -> String:
	for v: Variant in units:
		var u: Dictionary = v
		if int(u["serial"]) != serial:
			continue
		if bool(u["broken"]):
			return "broken"
		return "worn" if int(u["condition"]) < 550 else "good"
	return "missing"


func sale_value(serial: int) -> int:
	for v: Variant in units:
		var u: Dictionary = v
		if int(u["serial"]) == serial:
			var price: int = int((TYPES[str(u["type"])] as Dictionary)["price"])
			return MHStaffMath.idiv(price * maxi(200, int(u["condition"])), 2000)
	return 0


func sell_unit(serial: int) -> int:
	for i: int in range(units.size()):
		var u: Dictionary = units[i]
		if int(u["serial"]) == serial:
			var value: int = sale_value(serial)
			units.remove_at(i)
			return value
	return 0


func multiplier_for_employee(employee_serial: int, kind: String) -> int:
	var best: int = 1000
	for v: Variant in units:
		var u: Dictionary = v
		if int(u.get("assigned_employee", 0)) != employee_serial or bool(u["broken"]):
			continue
		var d: Dictionary = TYPES[str(u["type"])]
		if str(d["kind"]) != kind:
			continue
		best = maxi(best, MHStaffMath.idiv(int(d["work_pm"]) * int(u["condition"]), 1000))
	return best


func operating_cost_for_day() -> int:
	return operating_cost_cents


func repair_cost_for_day() -> int:
	return repair_cost_cents

func on_day(maintenance_tier: int, technician_work_pm: int = 0, used_employees: Array = [], pressure_pm: int = 1000, service_pm: int = 1000) -> void:
	operating_cost_cents = 0
	repair_cost_cents = 0
	for v: Variant in units:
		var u: Dictionary = v
		var d: Dictionary = TYPES[str(u["type"])]
		if bool(u["broken"]):
			if maintenance_tier >= 2 and technician_work_pm > 0:
				var repair_gain: int = MHStaffMath.idiv(maintenance_tier * 80 * technician_work_pm * service_pm, 1000000)
				u["condition"] = mini(1000, int(u["condition"]) + repair_gain)
				repair_cost_cents += repair_gain * 8
				if int(u["condition"]) >= 400:
					u["broken"] = false
			continue
		var was_used: bool = used_employees.has(int(u.get("assigned_employee", 0)))
		if was_used:
			u["condition"] = maxi(0, int(u["condition"]) - MHStaffMath.idiv(int(d["wear"]) * pressure_pm, 1000))
			operating_cost_cents += 75 + int(d["wear"]) * 5
		if int(u["condition"]) < 150:
			u["broken"] = true
		elif maintenance_tier > 0 and technician_work_pm > 0:
			var service_gain: int = MHStaffMath.idiv(maintenance_tier * 6 * technician_work_pm * service_pm, 1000000)
			u["condition"] = mini(1000, int(u["condition"]) + service_gain)
			repair_cost_cents += service_gain * 3

func to_save_block() -> Dictionary:
	return {"v": SAVE_VERSION, "next_serial": next_serial, "operating_cost_cents": operating_cost_cents, "repair_cost_cents": repair_cost_cents, "units": units.duplicate(true)}

func from_save_block(block: Dictionary) -> bool:
	var errs: Array = []
	var norm: Variant = MHDataJson.normalize(block, errs, "$")
	if not errs.is_empty() or typeof(norm) != TYPE_DICTIONARY:
		return false
	var b: Dictionary = norm
	if b.size() != 5 or not MHDataJson.is_int_in(b.get("v", null), SAVE_VERSION, SAVE_VERSION):
		return false
	if not MHDataJson.is_int_in(b.get("next_serial", null), 1, 1000000000):
		return false
	if not MHDataJson.is_int_in(b.get("operating_cost_cents", null), 0, 1000000000):
		return false
	if not MHDataJson.is_int_in(b.get("repair_cost_cents", null), 0, 1000000000):
		return false
	if typeof(b.get("units", null)) != TYPE_ARRAY:
		return false
	var ns: int = int(b["next_serial"])
	var src: Array = b["units"]
	if src.size() > MAX_UNITS:
		return false
	var cleaned: Array = []
	var assigned_employees: Dictionary = {}
	var last: int = 0
	for v: Variant in src:
		if typeof(v) != TYPE_DICTIONARY:
			return false
		var u: Dictionary = v
		if u.size() != 5:
			return false
		if not MHDataJson.is_int_in(u.get("serial", null), last + 1, ns - 1):
			return false
		if typeof(u.get("type", null)) != TYPE_STRING or not TYPES.has(str(u["type"])):
			return false
		if not MHDataJson.is_int_in(u.get("condition", null), 0, 1000):
			return false
		if typeof(u.get("broken", null)) != TYPE_BOOL:
			return false
		if not MHDataJson.is_int_in(u.get("assigned_employee", null), 0, 1000000000):
			return false
		var serial: int = int(u["serial"])
		var condition: int = int(u["condition"])
		var broken: bool = bool(u["broken"])
		# Runtime only marks a machine broken once it falls below 150, and repairs clear it at 400.
		# Reject impossible restored combinations rather than allowing save edits to manufacture state.
		if broken and condition >= 400:
			return false
		var assigned_employee: int = int(u["assigned_employee"])
		if assigned_employee != 0:
			if assigned_employees.has(assigned_employee):
				return false
			assigned_employees[assigned_employee] = true
		cleaned.append({"serial": serial, "type": str(u["type"]), "condition": condition,
			"broken": broken, "assigned_employee": assigned_employee})
		last = serial
	units = cleaned
	next_serial = ns
	operating_cost_cents = int(b["operating_cost_cents"])
	repair_cost_cents = int(b["repair_cost_cents"])
	return true

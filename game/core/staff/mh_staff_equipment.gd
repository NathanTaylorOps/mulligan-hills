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
	if int(block.get("v", 0)) != SAVE_VERSION or not MHRValidate.is_int_value(block.get("next_serial", null)):
		return false
	var ns: int = int(block["next_serial"])
	var saved_cost: int = int(block.get("operating_cost_cents", 0))
	var saved_repair: int = int(block.get("repair_cost_cents", 0))
	if saved_cost < 0 or saved_repair < 0:
		return false
	if ns < 1 or typeof(block.get("units", null)) != TYPE_ARRAY:
		return false
	var src: Array = block["units"]
	if src.size() > MAX_UNITS:
		return false
	var cleaned: Array = []
	var last: int = 0
	for v: Variant in src:
		if typeof(v) != TYPE_DICTIONARY:
			return false
		var u: Dictionary = v
		var serial: int = int(u.get("serial", 0))
		var type_id: String = str(u.get("type", ""))
		var condition: int = int(u.get("condition", -1))
		if serial <= last or serial >= ns or not TYPES.has(type_id) or condition < 0 or condition > 1000 or typeof(u.get("broken", null)) != TYPE_BOOL:
			return false
		var assigned: int = int(u.get("assigned_employee", 0))
		if assigned < 0:
			return false
		cleaned.append({"serial": serial, "type": type_id, "condition": condition, "broken": bool(u["broken"]), "assigned_employee": assigned})
		last = serial
	units = cleaned
	next_serial = ns
	operating_cost_cents = saved_cost
	repair_cost_cents = saved_repair
	return true

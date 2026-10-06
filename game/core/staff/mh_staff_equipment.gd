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

func add_unit(type_id: String) -> Dictionary:
	if not TYPES.has(type_id) or units.size() >= MAX_UNITS:
		return {"ok": false, "serial": 0, "price": 0}
	var d: Dictionary = TYPES[type_id]
	var serial: int = next_serial
	next_serial += 1
	units.append({"serial": serial, "type": type_id, "condition": 1000, "broken": false})
	return {"ok": true, "serial": serial, "price": int(d["price"])}

func available_multiplier_permille(kind: String) -> int:
	var best: int = 1000
	for v: Variant in units:
		var u: Dictionary = v
		if bool(u["broken"]) or str((TYPES[str(u["type"])] as Dictionary)["kind"]) != kind:
			continue
		var condition_pm: int = int(u["condition"])
		var work_pm: int = int((TYPES[str(u["type"])] as Dictionary)["work_pm"])
		best = maxi(best, MHStaffMath.idiv(work_pm * condition_pm, 1000))
	return best

func on_day(maintenance_tier: int) -> void:
	for v: Variant in units:
		var u: Dictionary = v
		var d: Dictionary = TYPES[str(u["type"])]
		if bool(u["broken"]):
			if maintenance_tier >= 2:
				u["condition"] = mini(1000, int(u["condition"]) + maintenance_tier * 80)
				if int(u["condition"]) >= 400:
					u["broken"] = false
			continue
		u["condition"] = maxi(0, int(u["condition"]) - int(d["wear"]))
		if int(u["condition"]) < 150:
			u["broken"] = true
		elif maintenance_tier > 0:
			u["condition"] = mini(1000, int(u["condition"]) + maintenance_tier * 6)

func to_save_block() -> Dictionary:
	return {"v": SAVE_VERSION, "next_serial": next_serial, "units": units.duplicate(true)}

func from_save_block(block: Dictionary) -> bool:
	if int(block.get("v", 0)) != SAVE_VERSION or not MHRValidate.is_int_value(block.get("next_serial", null)):
		return false
	var ns: int = int(block["next_serial"])
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
		cleaned.append({"serial": serial, "type": type_id, "condition": condition, "broken": bool(u["broken"])})
		last = serial
	units = cleaned
	next_serial = ns
	return true

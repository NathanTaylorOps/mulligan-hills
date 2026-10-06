class_name MHStaffFixture
extends RefCounted
## Shared helpers for the staff tests. NOT YET RUN.

const DATA_PATH: String = "res://data/staff.json"
const GOLDEN_PATH: String = "res://tests/staff/golden/staff_golden.json"
const DOCS_COPY: String = "../docs/spec/data/staff.json"
const STRINGS_PATH: String = "res://core/staff/staff_strings_en.json"
const ALL_BUILDINGS: Array = [
	"clubhouse", "pro_shop", "driving_range", "restaurant", "pool_spa", "cart_barn", "maintenance", "lodging", "homes",
	"landmark",
]


static func defs() -> MHStaffDefs:
	var d: MHStaffDefs = MHStaffDefs.new()
	d.load_from_file(DATA_PATH)
	return d


static func staff() -> MHStaff:
	return MHStaff.create(defs())


static func kinds() -> Array:
	return MHStaffView.kinds_from_defs(MHBuildingDefs.load_default())


## A view over the shipped land layout. tiers: {building id: tier}; owned: parcel ids.
static func view(tiers: Dictionary, owned: Array) -> Dictionary:
	return MHStaffView.make(tiers, owned, kinds())


## The start plot of buildings.json (parcels 5, 6, 8, 9, 10).
static func start_owned() -> Array:
	return [5, 6, 8, 9, 10]


static func all_tiers(tier: int) -> Dictionary:
	var out: Dictionary = {}
	for b: Variant in ALL_BUILDINGS:
		out[str(b)] = tier
	return out


static func golden() -> Dictionary:
	var r: Dictionary = MHDataJson.load_file(GOLDEN_PATH)
	if not bool(r["ok"]):
		return {}
	return r["value"] as Dictionary


static func data_dict() -> Dictionary:
	var r: Dictionary = MHDataJson.load_file(DATA_PATH)
	return r["value"] as Dictionary


static func same_list(a: PackedInt64Array, b: PackedInt64Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in range(a.size()):
		if a[i] != b[i]:
			return false
	return true

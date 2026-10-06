class_name MHStaffView
extends RefCounted
## The club snapshot every staff call reads. A plain Dictionary so the session can build it without the staff classes:
##   "tiers"  : {building id String: purchased tier 0..5}
##   "owned"  : Array of owned parcel ids (ints 0..15)
##   "kinds"  : Array of 16 Strings, "golf" | "facility" | "homes", index = parcel id (from buildings.json land.parcels)
## Always build it with make() so packed arrays from MHLandModel.owned_ids() become plain Arrays of ints. NOT YET RUN.

const NPARCELS: int = 16
const KINDS: Array = ["golf", "facility", "homes"]


static func make(tiers: Dictionary, owned: Variant, kinds: Variant) -> Dictionary:
	var o: Array = []
	for v: Variant in owned:
		o.append(int(v))
	var k: Array = []
	for s: Variant in kinds:
		k.append(str(s))
	return {"tiers": tiers.duplicate(), "owned": o, "kinds": k}


## The kinds list of the shipped land layout, read from an MHBuildingDefs (res://data/buildings.json).
static func kinds_from_defs(defs: MHBuildingDefs) -> Array:
	var out: Array = []
	var land: Dictionary = defs.land_config()
	for p: Variant in (land["parcels"] as Array):
		out.append(str((p as Dictionary)["kind"]))
	return out


static func is_valid(view: Dictionary) -> bool:
	if typeof(view.get("tiers", null)) != TYPE_DICTIONARY or typeof(view.get("owned", null)) != TYPE_ARRAY or typeof(view.get("kinds", null)) != TYPE_ARRAY:
		return false
	var kinds: Array = view["kinds"]
	if kinds.size() != NPARCELS:
		return false
	for s: Variant in kinds:
		if not KINDS.has(str(s)):
			return false
	for p: Variant in (view["owned"] as Array):
		if typeof(p) != TYPE_INT or int(p) < 0 or int(p) >= NPARCELS:
			return false
	return true


static func tier_of(view: Dictionary, building: String) -> int:
	var t: Dictionary = view["tiers"]
	return int(t.get(building, 0))


static func is_owned(view: Dictionary, parcel: int) -> bool:
	var o: Array = view["owned"]
	return o.has(parcel)


static func kind_of(view: Dictionary, parcel: int) -> String:
	var k: Array = view["kinds"]
	if parcel < 0 or parcel >= k.size():
		return ""
	return str(k[parcel])

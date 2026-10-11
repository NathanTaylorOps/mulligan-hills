class_name MHLandModel
extends RefCounted
## 16 parcels on a 4x4 grid (12 golf, 2 facility, 2 homes), layout and prices from buildings.json.
## The player starts with the 6-hole plot. A parcel can be bought only when it touches an owned
## parcel along an edge (orthogonal). Price of the n-th purchase (n from 0) is
## parcel_base_cost grown by parcel_growth_pct n times, integer math. Golf parcels hold holes:
## hole capacity = owned golf parcels * 3 / 2 (integer division), so 12 golf parcels hold 18.
## Homes parcels hold home slots (3 each, 6 max). NOT YET RUN.

var _defs: MHBuildingDefs
var _owned: PackedByteArray = PackedByteArray()
var _kinds: Array = []
var _cols: int = 4
var _rows: int = 4
var _start_count: int = 5
var _base_cost: int = 0
var _growth_pct: int = 100
var _holes_per_two: int = 3
var _slots_per_homes: int = 3
var _heavy_extra: int = 1


static func create(defs: MHBuildingDefs) -> MHLandModel:
	var m: MHLandModel = MHLandModel.new()
	m._defs = defs
	m._load_config()
	m.reset_to_start()
	return m


func _load_config() -> void:
	var land: Dictionary = _defs.land_config()
	var grid: Dictionary = land["grid"]
	_cols = int(grid["cols"])
	_rows = int(grid["rows"])
	_start_count = int(land["start_parcels"])
	_base_cost = int(land["parcel_base_cost"])
	_growth_pct = int(land["parcel_growth_pct"])
	_holes_per_two = int(land["holes_per_two_golf_parcels"])
	_slots_per_homes = int(land["home_slots_per_homes_parcel"])
	_heavy_extra = int(land["heavy_extra_parcels"])
	_kinds = []
	var plist: Array = land["parcels"]
	for p: Variant in plist:
		var pd: Dictionary = p
		_kinds.append(str(pd["kind"]))


func parcel_count() -> int:
	return _kinds.size()


func grid_cols() -> int:
	return _cols


func grid_rows() -> int:
	return _rows


func parcel_id_at_world_mm(x_mm: int, y_mm: int, world_width_mm: int, world_height_mm: int) -> int:
	if x_mm < 0 or y_mm < 0 or x_mm >= world_width_mm or y_mm >= world_height_mm or _cols <= 0 or _rows <= 0:
		return -1
	var col: int = mini(_cols - 1, x_mm * _cols / world_width_mm)
	var row: int = mini(_rows - 1, y_mm * _rows / world_height_mm)
	var id: int = row * _cols + col
	return id if id >= 0 and id < parcel_count() else -1


func owns_world_mm(x_mm: int, y_mm: int, world_width_mm: int, world_height_mm: int) -> bool:
	var id: int = parcel_id_at_world_mm(x_mm, y_mm, world_width_mm, world_height_mm)
	return id >= 0 and is_owned(id)


func reset_to_start() -> void:
	var land: Dictionary = _defs.land_config()
	var plist: Array = land["parcels"]
	_owned = PackedByteArray()
	_owned.resize(plist.size())
	for i: int in range(plist.size()):
		var pd: Dictionary = plist[i]
		_owned[i] = 1 if bool(pd["start_owned"]) else 0


func kind_of(id: int) -> String:
	if id < 0 or id >= _kinds.size():
		return ""
	return str(_kinds[id])


func is_owned(id: int) -> bool:
	return id >= 0 and id < _owned.size() and _owned[id] == 1


func owned_count() -> int:
	var n: int = 0
	for i: int in range(_owned.size()):
		n += _owned[i]
	return n


func owned_count_of_kind(kind: String) -> int:
	var n: int = 0
	for i: int in range(_owned.size()):
		if _owned[i] == 1 and str(_kinds[i]) == kind:
			n += 1
	return n


## Owned parcel ids, ascending.
func owned_ids() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in range(_owned.size()):
		if _owned[i] == 1:
			out.append(i)
	return out


## Edge neighbours of a parcel, ascending id.
@warning_ignore("integer_division")
func neighbors(id: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if id < 0 or id >= _kinds.size():
		return out
	var c: int = id % _cols
	var r: int = id / _cols
	if r > 0:
		out.append(id - _cols)
	if c > 0:
		out.append(id - 1)
	if c < _cols - 1:
		out.append(id + 1)
	if r < _rows - 1:
		out.append(id + _cols)
	return out


func _touches_owned(id: int) -> bool:
	for n: int in neighbors(id):
		if _owned[n] == 1:
			return true
	return false


## "" if id can be bought now, else "bad_id", "already_owned" or "not_adjacent".
func check_buy(id: int) -> String:
	if id < 0 or id >= _kinds.size():
		return "bad_id"
	if _owned[id] == 1:
		return "already_owned"
	if not _touches_owned(id):
		return "not_adjacent"
	return ""


## Parcel ids that can be bought now, ascending.
func buyable_parcels() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in range(_owned.size()):
		if check_buy(i) == "":
			out.append(i)
	return out


func purchases_made() -> int:
	return owned_count() - _start_count


@warning_ignore("integer_division")
func price_for_purchase_index(n: int) -> int:
	var p: int = _base_cost
	for i: int in range(maxi(n, 0)):
		p = p * _growth_pct / 100
	return p


## Price of the next purchase (same for every parcel), 0 once everything is owned.
func next_price() -> int:
	if owned_count() >= _owned.size():
		return 0
	return price_for_purchase_index(purchases_made())


## Buy a parcel. Returns the price to charge (>= 0), or -1 if the purchase is not allowed
## (see check_buy). The caller spends the cash; this model only records ownership.
func buy(id: int) -> int:
	if check_buy(id) != "":
		return -1
	var price: int = next_price()
	_owned[id] = 1
	return price


## Suggested next parcel for a guided plan: golf first, then facility, then homes; lowest id
## within a kind. Free choice among buyable parcels is still allowed. -1 if none left.
func recommended_next() -> int:
	var buyable: PackedInt32Array = buyable_parcels()
	for kind: String in ["golf", "facility", "homes"]:
		for id: int in buyable:
			if str(_kinds[id]) == kind:
				return id
	return -1


## How many holes the owned golf parcels can hold.
@warning_ignore("integer_division")
func hole_capacity() -> int:
	return mini(owned_count_of_kind("golf") * _holes_per_two / 2, _defs.hole_cap())


func home_slot_capacity() -> int:
	return mini(owned_count_of_kind("homes") * _slots_per_homes, _defs.home_slots_max())


## Parcels a building tier needs owned (heavy buildings carry the extra parcel at tiers 2..5).
func parcels_required(id: String, tier: int) -> int:
	return MHUnlockRules.parcels_required(_defs, id, tier)


## How many of the required parcels are the heavy-building extra (0 for light or tier 1).
func heavy_extra_for(id: String, tier: int) -> int:
	if _defs.is_heavy(id) and tier >= 2:
		return _heavy_extra
	return 0


func parcel_requirement_met(id: String, tier: int) -> bool:
	return owned_count() >= parcels_required(id, tier)


## Fill the parcel fields of a gate view from the current land.
func fill_view(view: MHGateView) -> void:
	view.parcels_owned = owned_count()
	view.parcels_by_kind = {
		"golf": owned_count_of_kind("golf"),
		"facility": owned_count_of_kind("facility"),
		"homes": owned_count_of_kind("homes"),
	}


## Restore from saved owned ids. Returns "" or an error. The set must contain every start parcel,
## have valid unique ids, and be one edge-connected block (so it could have been reached by buying).
func load_owned(ids: PackedInt32Array) -> String:
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(_kinds.size())
	for id: int in ids:
		if id < 0 or id >= _kinds.size():
			return "bad parcel id"
		if seen[id] == 1:
			return "duplicate parcel id"
		seen[id] = 1
	var land: Dictionary = _defs.land_config()
	var plist: Array = land["parcels"]
	for i: int in range(plist.size()):
		var pd: Dictionary = plist[i]
		if bool(pd["start_owned"]) and seen[i] == 0:
			return "start parcel missing"
	# connectivity flood fill from the lowest owned id
	var stack: Array = [ids[0]] if ids.size() > 0 else []
	var reached: PackedByteArray = PackedByteArray()
	reached.resize(_kinds.size())
	var reached_n: int = 0
	while not stack.is_empty():
		var cur: int = int(stack.pop_back())
		if reached[cur] == 1:
			continue
		reached[cur] = 1
		reached_n += 1
		for n: int in neighbors(cur):
			if seen[n] == 1 and reached[n] == 0:
				stack.append(n)
	if reached_n != ids.size():
		return "owned parcels are not connected"
	_owned = seen
	return ""

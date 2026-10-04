class_name MHGateReport
extends RefCounted
## Result of one gate check. rows are [requirement_key: String, met: bool, have: int, need: int].
## Keys: previous_tier, demo_limit, holes, avg_hole_score, parcels_owned, parcel_kind:<kind>,
## members, building:<id>, any_others, hosted_tournament, unknown_tier.

var met: bool = false
var demo_locked: bool = false
var rows: Array = []


func add(key: String, ok: bool, have: int, need: int) -> void:
	rows.append([key, ok, have, need])


func finish() -> void:
	met = true
	for r: Variant in rows:
		var row: Array = r
		if not bool(row[1]):
			met = false


func missing_keys() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for r: Variant in rows:
		var row: Array = r
		if not bool(row[1]):
			out.append(str(row[0]))
	return out


func row_met(key: String) -> bool:
	for r: Variant in rows:
		var row: Array = r
		if str(row[0]) == key:
			return bool(row[1])
	return false


func has_row(key: String) -> bool:
	for r: Variant in rows:
		var row: Array = r
		if str(row[0]) == key:
			return true
	return false

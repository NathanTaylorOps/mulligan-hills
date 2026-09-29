class_name MHHole
extends RefCounted
## Hole data for the prototype shot simulator: an integer lie grid (4 m cells) plus tee and pin
## positions in Q16.16 metres. Built by MHShotSim.make_hole(); mirror of mh_shotsim.py.

const LIE_TEE: int = 0
const LIE_FAIRWAY: int = 1
const LIE_ROUGH: int = 2
const LIE_BUNKER: int = 3
const LIE_WATER: int = 4
const LIE_GREEN: int = 5
const LIE_TREES: int = 6
const LIE_OB: int = 7

const GRID_W: int = 128
const CELL_SHIFT: int = 18 ## cell = 4 m = 4 * 65536 raw = 2^18

var par: int = 4
var w: int = GRID_W
var h: int = 0
var tee_x: int = 0
var tee_y: int = 0
var pin_x: int = 0
var pin_y: int = 0
var lies: PackedByteArray = PackedByteArray()


func lie_at(x: int, y: int) -> int:
	if x < 0 or y < 0:
		return LIE_OB
	var cx: int = x >> CELL_SHIFT
	var cy: int = y >> CELL_SHIFT
	if cx >= w or cy >= h:
		return LIE_OB
	return lies[cy * w + cx]


func lie_hash_hex() -> String:
	var f: MHHash = MHHash.new()
	for i in range(lies.size()):
		f.add_byte(lies[i])
	return f.hex()

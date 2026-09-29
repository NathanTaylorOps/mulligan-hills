# Interface: Terrain (`game/terrain/`, owner C)

RECONCILIATION NEEDED: workstream C's Phase 0 status doc (docs/phase0/terrain.md) implements `MHHeightGrid`, `MHTerrainEditor`, `MHTerrainChunks` and `MHTerrainSave` (1 m cells, `cell_size_mm` 1000, own binary format with FNV-1a hash and CRC32, cells+1 height samples per side). The `MHTerrain` facade below is the contract other modules should code against; C provides it as a thin wrapper over those classes, or the lead adopts C's names and this file is updated. Method-level equivalents: `apply_stroke` = `begin_stroke/apply_brush_at/end_stroke`, `to_bytes/from_bytes` = `MHTerrainSave`, `content_hash` = FNV-1a hash today (course schema field `content_hash`). Note C's grid has (cells+1)^2 samples; `width()` here means cells, not samples.

Purpose: authoritative integer height and surface data, edit tools, undo, serialisation, and the dirty-region feed for the renderer. Heights are int16 millimetres (hard requirement from CONTRACT.md); coordinates are integer cells. Horizontal world units in the data files are decimetres; `cell_size_dm` converts (C's 1 m cell = `cell_size_dm` 10).

```gdscript
class_name MHTerrain extends RefCounted
signal region_dirty(x0: int, y0: int, x1: int, y1: int)     # UI/render only; sim never listens
func create(width_cells: int, height_cells: int, cell_size_dm: int) -> MHResult
func width() -> int
func height() -> int
func cell_size_dm() -> int
func height_mm(cx: int, cy: int) -> int                     # clamped read at the edges, int16 range
func surface(cx: int, cy: int) -> int                       # MHSurface.* constant
func height_at_dm(x_dm: int, y_dm: int) -> int              # integer bilinear in fixed-point, no floats
func slope_permille(x_dm: int, y_dm: int, dir_deg: int) -> int
func apply_stroke(stroke: MHStroke) -> MHResult             # integer brush tools: raise, lower, smooth, flatten, paint; returns a stroke id
func cancel_stroke() -> void                                # second finger cancels the open stroke
func undo() -> bool
func redo() -> bool
func history_depth() -> int                                 # capped by memory (cap documented in terrain.md)
func to_bytes() -> PackedByteArray                          # canonical blob (format_version in the course.terrain reference)
static func from_bytes(bytes: PackedByteArray) -> MHTerrain # null on invalid data, never a partial object
func content_hash() -> PackedByteArray                      # sha256, stored in course.terrain.sha256
```
```gdscript
class_name MHStroke extends RefCounted
var tool: int          # MHTerrainTool.RAISE, LOWER, SMOOTH, FLATTEN, PAINT_SURFACE
var points: PackedInt32Array   # x0,y0,x1,y1,... in dm, appended as the finger moves
var radius_dm: int
var strength: int      # 1..100
var surface: int       # for PAINT_SURFACE
```

## Guarantees
- All edit tools are integer math; the same stroke list applied to the same terrain gives the same bytes on every platform.
- `apply_stroke` is atomic per stroke; undo of 50 strokes restores bytes exactly (Gate 0 item 5).
- Height range always inside int16; strokes clamp, never wrap.
- `from_bytes` rejects wrong sizes, out-of-range enums and hash mismatch with an error code.
- No physics colliders; picking is by heightmap ray march in `game/terrain/`.

## Consumers
Core sim, rating (read), render (dirty regions and read), input (picking), save (bytes and hash).

## Contract tests
Stroke/undo/redo round trip, save/load byte equality, edge clamping, stroke cancel.

## Lead note (29 Sep 2026)
The implementation in `game/terrain/` (MHHeightGrid, MHTerrainEditor, 1 m cells) is authoritative for Phase 0. The MHTerrain facade above is a target for later phases and must be reconciled to the implemented API before use.

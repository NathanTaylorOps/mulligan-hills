# Interface: Terrain (`game/terrain/`, owner C)

Status: describes the code as implemented in Phase 0 (reconciled 29 Sep 2026 against `game/terrain/*.gd`). The implemented API is authoritative (`docs/CONTRACT.md`, lead decisions). Nothing here has been run: Godot cannot run in the authoring sandbox and CI has not yet validated the GDScript (see `docs/phase0/terrain.md`, "NOT YET RUN"). The earlier invented `MHTerrain` / `MHStroke{tool,points,...}` facade is no longer an interface; a possible thin future wrapper is described only in section 8, with an exact mapping.

Purpose: authoritative integer height and splat data, brush edits with stroke-level undo, a dirty-region feed for the renderer, integer picking output, and a crash-safe save format.

## 1. Units and layout
| Item | Implemented value |
| --- | --- |
| Height | int16 millimetres, range -32768..32767 (about +-32.7 m). Stored one per int32 in a `PackedInt32Array` (memory choice; values always clamped to int16). Written to disk as int16. |
| Horizontal | integer cell/sample coordinates. `cell_size_mm` default 1000 (1 m). Configurable, minimum 1. |
| Sample grid | (cells + 1) samples per axis: `samples_x = cells_x + 1`, `samples_y = cells_y + 1`. A 512 x 512 cell map is 513 x 513 samples. Index = `y * samples_x + x`, row-major. All editor coordinates are SAMPLE coordinates `0..cells` inclusive. |
| Chunk size | 32 cells (parameter `chunk_size`, default 32 in `MHTerrainEditor._init`, `MHDirtyTracker._init`, `MHTerrainChunks.setup`). 512 cells = 16 x 16 = 256 chunks. |
| Splat | RGBA8, one texel per height sample: R fairway, G rough, B sand, A green. Weights 0..255, need not sum to 255. Not undoable in Phase 0. |
| Floats | None in `MHHeightGrid`, `MHBrush`, `MHSplatMap`, `MHStroke`, `MHUndoStack`, `MHDirtyTracker`, `MHTerrainSave`. Floats exist only in `MHPicking` and `MHTerrainChunks` (rendering side). |

Relation to the data specs (`docs/spec/data/README.md`, `course.schema.json`): the course `terrain.width_cells` / `height_cells` equal `cells_x` / `cells_y` (cells, not samples). `cell_size_dm = cell_size_mm / 100`, so only whole multiples of 100 mm can be referenced from a course (the default 1000 mm is `cell_size_dm` 10). The course schema limit is 16..2048 cells per side; `MHTerrainSave.MAX_CELLS` is 4096 (the schema is the stricter, effective limit for courses).

## 2. `MHHeightGrid` (extends RefCounted)
```gdscript
const MIN_H_MM: int = -32768
const MAX_H_MM: int = 32767
const FNV_OFFSET: int = 2166136261
const FNV_PRIME: int = 16777619
var cells_x: int; var cells_y: int; var samples_x: int; var samples_y: int
var cell_size_mm: int = 1000
var heights: PackedInt32Array          # int16 mm values
var stroke_mark: PackedByteArray       # scratch, all zero between strokes
func _init(p_cells_x: int = 512, p_cells_y: int = 512, p_cell_size_mm: int = 1000) -> void   # dims clamped to >= 1
func sample_count() -> int
func idx(x: int, y: int) -> int
func in_bounds(x: int, y: int) -> bool
func get_h(x: int, y: int) -> int                  # unchecked, caller keeps in bounds
func get_h_clamped(x: int, y: int) -> int          # clamps coordinates to the edge
func set_h(x: int, y: int, value_mm: int) -> void  # clamps value to int16; setup/tests only, NOT undoable
func ensure_stroke_marks() -> void
func fill(value_mm: int) -> void
func fill_lcg_noise(seed_value: int, amplitude_mm: int) -> void   # must match tools/reference/terrain/brush_ref.py
func hash_fnv1a() -> int                           # FNV-1a 32 bit over (h + 32768) as low byte then high byte
func duplicate_grid() -> MHHeightGrid
func equals(other: MHHeightGrid) -> bool           # dims, cell size and heights (not splat)
```

## 3. `MHBrush` (static, extends RefCounted)
```gdscript
enum Mode { RAISE = 0, LOWER = 1, SMOOTH = 2, FLATTEN = 3 }
static func falloff_table() -> PackedInt32Array    # 1025 entries, integer smoothstep
static func falloff_hash() -> int
static func idiv(a: int, b: int) -> int            # truncates toward zero
static func apply_dab(grid: MHHeightGrid, mode: int, cx: int, cy: int, radius: int,
        strength: int, level_mm: int, stroke: MHStroke) -> Rect2i   # returns clipped footprint or empty Rect2i
```
Math: footprint `dx^2 + dy^2 <= r^2` clipped to the grid; `t = ((r^2 - d^2) * 1024) / r^2`; `w = FALLOFF[t]` (0..1024). RAISE/LOWER add/subtract `(strength_mm * w + 512) / 1024`. SMOOTH blends toward the 3x3 mean, FLATTEN toward `level_mm`, by `strength_per_mille * w / (1024 * 1000)`, truncating toward zero. New values are computed from pre-dab heights, then written (order independent). Results clamp to int16, never wrap. There is NO paint or surface mode in `MHBrush`.

## 4. `MHTerrainEditor` (extends RefCounted, headless): the public editing API
```gdscript
signal stroke_began()
signal stroke_ended(changed_cells: int)
signal stroke_cancelled()
signal history_applied(is_undo: bool)
signal cells_dirty(rect: Rect2i)                   # rect.end is exclusive; UI/render only
const FLATTEN_AUTO: int = -2147483648
var grid: MHHeightGrid
var splat: MHSplatMap
var undo_stack: MHUndoStack
var dirty: MHDirtyTracker
var brush_mode: int = MHBrush.Mode.RAISE
var brush_radius: int = 8                          # cells
var brush_strength: int = 100                      # RAISE/LOWER mm at centre per dab; SMOOTH/FLATTEN per mille 0..1000
var flatten_level_mm: int = FLATTEN_AUTO           # AUTO = height under the first dab of the stroke
func _init(p_grid: MHHeightGrid, p_splat: MHSplatMap = null, p_chunk_size: int = 32) -> void
func set_brush(mode: int, radius_cells: int, strength: int) -> void     # radius clamped to >= 1
func is_stroke_open() -> bool
func begin_stroke() -> bool                        # false if a stroke is already open
func apply_brush_at(cell_x: int, cell_y: int) -> void                   # warns and ignores if no open stroke
func apply_brush_segment(x0: int, y0: int, x1: int, y1: int) -> void    # dabs every max(1, radius/2) cells, excluding the start point
func end_stroke() -> int                           # cells changed; 0 = nothing changed, no undo entry
func cancel_stroke() -> void                       # exact rollback, no undo entry, redo untouched
func undo() -> bool                                # false while a stroke is open or history empty
func redo() -> bool
func paint_splat_at(cell_x: int, cell_y: int, radius: int, layer: int, strength_per_mille: int) -> void   # NOT undoable, no cancel
func mark_all_dirty() -> void
```
Call order: `begin_stroke()`, many `apply_brush_at()`, then `end_stroke()` or `cancel_stroke()`. A second finger cancels the open stroke (`cancel_stroke`). A new committed stroke clears redo. Coordinates are integer sample coordinates; the gesture layer converts a touch to a cell and passes the integer.

## 5. Stroke and history classes
- `MHStroke` (RefCounted): per-stroke diff. Fields `indices`, `old_h`, `new_h` (PackedInt32Array), `flatten_level_mm`, `has_level`, `dab_count`, `is_open`, `min_x/min_y/max_x/max_y`. Methods `touch(grid, idx)`, `finalize(grid)`, `rollback(grid)`, `apply_old(grid)`, `apply_new(grid)`, `changed_count()`, `byte_size()`, `bounds() -> Rect2i`. Dabs themselves are NOT stored, only the resulting per-cell old/new heights (12 bytes per changed cell).
- `MHUndoStack` (RefCounted): `max_strokes = 128`, `max_bytes = 16 MiB` (oldest entries trimmed, at least one kept). Methods `begin(grid)`, `commit(grid)`, `cancel(grid)`, `undo(grid)`, `redo(grid)`, `clear()`, `has_open_stroke()`, `open_stroke()`, `undo_count()`, `redo_count()`, `undo_bytes()`. History is session only and never saved.
- Gate 0 item 5 ("50 strokes then 50 undos restores the exact bytes") is within the 128 stroke cap.

## 6. Rendering feed and picking
- `MHDirtyTracker` (RefCounted): `_init(samples_x, samples_y, chunk_size = 32)`, `mark_rect(x0, y0, x1, y1)` (inclusive sample coords), `mark_all()`, `take() -> PackedInt32Array` (5 ints per dirty chunk: chunk_id, x0, y0, x1, y1, first-dirtied order, clears), `dirty_count()`, `is_dirty(id)`, `peek_rect(id)`, `chunk_count()`. A chunk owns samples `[c*S-1, c*S+S+1]` (one border sample for normals), so one changed sample can dirty up to 2 x 2 chunks.
- `MHTerrainChunks` (extends Node3D): `setup(grid, splat, chunk_size = 32)`, `flush(tracker)` once per frame, `chunk_count()`, stats `last_flush_chunks/texels/usec`. One shared 33 x 33 vertex mesh, per-chunk RG8 height texture and RGBA8 splat texture of (chunk_size + 3)^2 texels, shader `res://terrain/terrain.gdshader`. `ImageTexture.update` takes a whole image, so an update rewrites one small chunk texture, not a sub-rectangle. Grids whose cell count is not a multiple of 32 (for example the 600 x 400 Gate 0 course) get a partial last chunk; out-of-grid texels are clamped edge copies. No LOD, no skirts.
- `MHPicking` (static, RENDERING SIDE, uses floats): `pick(grid, origin: Vector3, dir: Vector3, max_dist_m: float = 2000.0) -> Vector2i` returns the rounded integer sample cell or `MHPicking.MISS = Vector2i(-1, -1)`; also `sample_height_m(grid, gx, gz) -> float`. World mapping: `world_x = cell_x * cell_size_m`, `world_z = cell_y * cell_size_m`, `world_y = height_mm / 1000`. Only the returned integer may be recorded or replayed.
- No physics colliders. There is no integer `height_at` or slope query yet (see gaps).

## 7. Save format: `MHTerrainSave` (static)
Little endian. File magic `MHTS`, format version 1.
```
Header (20 bytes)
   0  4  magic "MHTS"
   4  2  format version = 1
   6  2  flags (1 = body is zstd compressed)
   8  4  compressed body size
  12  4  uncompressed body size
  16  4  CRC32 over bytes [0..15] followed by the compressed body
Body (zstd, after decompression)
   0  4  cells_x     4  4 cells_y     8  4 cell_size_mm     12  4 FNV-1a height hash
  16  2*n  int16 heights, n = (cells_x+1)*(cells_y+1)   then   4*n splat bytes (RGBA)
```
```gdscript
const VERSION: int = 1
const HEADER_SIZE: int = 20
const INNER_HEADER: int = 16
const MAX_CELLS: int = 4096
class LoadResult: var error: int; var message: String; var grid: MHHeightGrid; var splat: MHSplatMap
static func encode(grid: MHHeightGrid, splat: MHSplatMap) -> PackedByteArray
static func decode(data: PackedByteArray) -> LoadResult
static func save_to_file(path: String, grid: MHHeightGrid, splat: MHSplatMap) -> int          # Godot Error code
static func write_atomic(path: String, data: PackedByteArray) -> int    # "<path>.tmp", flush, close, rename over path
static func load_from_file(path: String) -> LoadResult
static func cleanup_stale_temp(path: String) -> void
static func temp_path(path: String) -> String
static func crc32(data: PackedByteArray) -> int
static func fault_from_cmdline() -> void          # fault-injection hooks for the kill-during-save test
static var fault_point: int; static var fault_action: int
```
Errors are Godot `Error` values in `LoadResult.error` (ERR_FILE_CORRUPT, ERR_FILE_UNRECOGNIZED, ERR_FILE_NOT_FOUND, ...), not an `MHResult` (no such class exists in `game/`). Decode never returns a partial object: it checks size, CRC32, flags, decompressed size, dimensions (1..4096), body size vs dimensions, and the FNV-1a height hash. Only the heights are hashed; the splat bytes are protected by the CRC32 only. Atomic write is process-kill safe by design; `FileAccess.flush()` is not a guaranteed fsync, so power-loss durability is NOT claimed. The course and save data examples name the blob file `terrain_0.mhts`.

## 8. Possible thin future wrapper `MHTerrain` (NOT IMPLEMENTED)
No class named `MHTerrain` exists. If a Phase 1 module wants a single facade (the drafted `MHRatingEngine` and `MHSimEngine` interfaces take a terrain argument), it must be a wrapper over the classes above. Exact mapping of the previously drafted facade:

| Drafted `MHTerrain` member | Implemented equivalent |
| --- | --- |
| `create(width_cells, height_cells, cell_size_dm)` | `MHHeightGrid.new(cells_x, cells_y, cell_size_dm * 100)` plus `MHTerrainEditor.new(grid)` |
| `width()`, `height()` | `grid.cells_x`, `grid.cells_y` (CELLS; samples are `samples_x`, `samples_y`) |
| `cell_size_dm()` | `grid.cell_size_mm / 100` |
| `height_mm(cx, cy)` | `grid.get_h_clamped(cx, cy)` |
| `surface(cx, cy)` | none; splat weights via `splat.get_weight(x, y, layer)`; no `MHSurface` enum exists |
| `height_at_dm`, `slope_permille` | NOT IMPLEMENTED (integer bilinear and slope queries are a gap) |
| `apply_stroke(MHStroke)` | `begin_stroke()`, `apply_brush_at()` per point, `end_stroke()`; there is no stroke object with `tool`, `points`, `radius_dm`, `strength`, `surface` |
| `cancel_stroke()`, `undo()`, `redo()` | same names on `MHTerrainEditor` |
| `history_depth()` | `undo_stack.undo_count()` (cap 128 strokes or 16 MiB) |
| `region_dirty` signal | `MHTerrainEditor.cells_dirty(rect: Rect2i)` (exclusive end) or the `editor.dirty` tracker |
| `to_bytes()`, `from_bytes()` | `MHTerrainSave.encode(grid, splat)`, `MHTerrainSave.decode(bytes)` |
| `content_hash()` sha256 | `grid.hash_fnv1a()` (32-bit FNV-1a, 8 hex digits). Course schema `content_hash` accepts 8 to 64 hex digits; a sha256 is NOT implemented |

## 9. Guarantees (as implemented, subject to CI)
- Edit tools are integer math and mirror `tools/reference/terrain/brush_ref.py`; golden vectors in `game/tests/terrain/golden/brush_golden.json` (55 ops, hash after each op).
- `end_stroke` commits one undo entry; `cancel_stroke` restores the exact pre-stroke heights.
- Heights clamp to int16, never wrap.
- Load rejects wrong sizes, bad magic or version, CRC or hash mismatch.

## 10. Known gaps (as of 29 Sep 2026)
1. No `MHTerrain` facade, no `MHResult`, no `MHSurface`, no `MHStroke` with tool/points fields.
2. No integer `height_at` or slope query for the sim or rating. `MHPicking.sample_height_m` is float and rendering-only. The Phase 0 shot sim (`game/core/`, `MHHole`) does not read terrain at all (it uses a 128-wide lie grid of 4 m cells built from a seed).
3. Splat painting is not undoable, not cancellable, not part of the stroke API, and there is no paint mode in `MHBrush`. Splat has 4 layers (fairway, rough, sand, green); `course.schema.json` `surface_layers` lists 11 names (rough, fairway, first_cut, green, fringe, tee, bunker_sand, water, path, waste, dirt). Not reconciled.
4. Content hash is FNV-1a 32-bit over heights only, not sha256; splat is not covered by it.
5. The course schema references `width_cells`, `height_cells`, `cell_size_dm` but no loader connects a course file to `MHTerrainSave`.
6. Picking returns `MHPicking.MISS = Vector2i(-1, -1)` while `MHStrokeBridge.NO_CELL = Vector2i(-2147483648, -2147483648)`. The `screen_to_cell` callable given to `MHInputRouter.setup` must translate MISS to NO_CELL. Nothing does yet; a raw MISS would dab at (-1, -1), and a dab of radius r there still clips onto the grid corner (cells 0..r-1), so the edit would land in the wrong place instead of being ignored. `MHForwardingStrokeSink` forwards by dynamic `call()` with string method names, so a rename in `MHTerrainEditor` breaks it only at runtime.
7. `MHTerrainEditor` has no command log; replay would need (mode, radius, strength, cell) per dab.
8. Save is synchronous on the main thread; no threaded or chunked save.
9. Height range limited to about +-32.7 m by int16 mm.
10. No LOD or skirts; 256 chunk draws at 512 x 512 is unmeasured on the target phone.

## Consumers
Render (`MHTerrainChunks`, dirty tracker), input (`MHStrokeSink` / `MHForwardingStrokeSink` forward to `MHTerrainEditor`; `MHPicking`), save (`MHTerrainSave`). Core sim and rating do not consume terrain yet (gap 2).

## Contract tests (present)
`game/tests/terrain/test_brush.gd`, `test_stroke_undo.gd`, `test_dirty.gd`, `test_save.gd`, `test_picking.gd`. None have been run.

# Phase 0 status: Terrain (workstream C)

**Status: code written, Python reference RUN, all GDScript, shader, scene and gdUnit4 tests NOT YET RUN.** Nobody has executed Godot in this sandbox. Treat everything under "GDScript" below as unverified until CI is green.

## README block
- **Purpose:** prove that editable 3D terrain is feasible on a low-end phone and that terrain edits are deterministic.
- **Public API (for the gesture workstream):** class `MHTerrainEditor` (headless `RefCounted`). `begin_stroke() -> bool`, `apply_brush_at(cell_x: int, cell_y: int)`, `end_stroke() -> int` (cells changed, 0 = discarded), `cancel_stroke()`. Extras: `apply_brush_segment(x0,y0,x1,y1)`, `undo()`, `redo()`, `set_brush(mode, radius_cells, strength)`. Signals: `stroke_began`, `stroke_ended(changed_cells)`, `stroke_cancelled`, `history_applied(is_undo)`, `cells_dirty(rect)`. Picking: `MHPicking.pick(grid, ray_origin, ray_dir) -> Vector2i` (float, rendering side only; the returned integer cell is what must be recorded and replayed).
- **How tests run:** gdUnit4 suites in `game/tests/terrain/`. Python: `python3 tools/reference/terrain/brush_ref.py` (self-test plus regenerate golden) and `--check`.
- **Gate 0 criteria addressed:** editable terrain on low-end phone (proof needs device run); deterministic edits (golden vectors, hash); undo/redo/cancel; crash-safe save. Check the exact item numbers in `docs/phase0/GATE0.md`.

## 1. What was built
`game/terrain/`
- `mh_height_grid.gd` MHHeightGrid: authoritative int16 mm heights in a PackedInt32Array, (cells+1)^2 samples (512 cells = 513x513), FNV-1a hash, LCG noise fill.
- `mh_splat_map.gd` MHSplatMap: RGBA8 bytes (R fairway, G rough, B sand, A green), integer disc paint. Splat edits are NOT undoable in Phase 0.
- `mh_brush.gd` MHBrush: raise, lower, smooth, flatten. Integer only, integer smoothstep falloff table (1025 entries).
- `mh_stroke.gd` MHStroke, `mh_undo_stack.gd` MHUndoStack: per-stroke diffs (index, old, new), undo, redo, cancel by exact rollback, trim by count (128) and bytes (16 MiB).
- `mh_dirty_tracker.gd` MHDirtyTracker: dirty rect per chunk including a one-sample border.
- `mh_terrain_chunks.gd` MHTerrainChunks (Node3D) plus `terrain.gdshader`.
- `mh_picking.gd` MHPicking: heightmap ray-march.
- `mh_terrain_save.gd` MHTerrainSave: versioned binary, CRC32, zstd, atomic temp-then-rename, fault injection.
- `mh_terrain_editor.gd` MHTerrainEditor: the API above.
- `demo/terrain_demo.tscn` + `terrain_demo.gd` (desktop click-drag demo with stats), `demo/save_probe.gd` (kill-during-save probe).

`game/tests/terrain/`: `test_brush.gd`, `test_stroke_undo.gd`, `test_dirty.gd`, `test_save.gd`, `test_picking.gd`, `golden/brush_golden.json`.
`tools/reference/terrain/brush_ref.py`: Python reference and golden vector generator.

## 2. How it is tested
- **RUN here:** `brush_ref.py` self-test passed (falloff shape, FNV constant, raise/lower cancel, flatten exact, clamping, smooth bounds, determinism); it generated `golden/brush_golden.json` (55 ops on a 65x65 LCG-noise grid, hash after every op) and `--check` confirms it is current.
- **NOT YET RUN:** every GDScript file, the shader, the demo scene, the save probe, and all gdUnit4 tests. The golden test in `test_brush.gd` is the check that GDScript integer math equals the Python reference.
- Tests cover: stroke apply, undo, redo, undo chain back to the start, cancel rollback identical to before (full array equality, redo/undo counts unchanged, scratch marks all zero), brush determinism hash, golden vectors, save/load round trip (memory and file), every single byte flip in a small file detected, truncation/extension/bad magic/future version, fault injection (mid-temp-write and after-temp-write keep the old file loadable; the temp file is invalid or ignored), dirty tracking (interior, borders, 4-chunk corner, ordering, union, clipping), picking.

## 3. Gate 0 evidence CI must produce
1. gdUnit4 `game/tests/terrain` all green on Ubuntu and macOS. In particular `test_golden_vectors_match_python_reference` (cross-check with Python) and `test_cancel_rolls_back_with_no_residue`.
2. CI step running `python3 tools/reference/terrain/brush_ref.py --check` (fails if golden is stale).
3. Headless kill test, see "Kill-during-save test" below, exit code 0.
4. Device evidence (workstream D/I harness, not built here): frame time and stroke cost from `terrain_demo.gd` style stats on the low-end Android phone, per the device runbook. Nothing here proves phone performance yet.

## Design details
**Heights.** int16 millimetres (range +-32.767 m), 1 m cells (`cell_size_mm` = 1000, configurable). Stored one per int32 for GDScript speed.

**Brush math.** Footprint: `dx^2+dy^2 <= r^2`, clipped to the grid. `t = ((r^2-d^2)*1024)/r^2`; weight `w = (3*t^2*1024 - 2*t^3)/1024^2` from a precomputed table. RAISE/LOWER: `h +- (strength_mm*w + 512)/1024`. SMOOTH: blend toward the 3x3 mean by `strength_per_mille*w/(1024*1000)`. FLATTEN: same blend toward a level (default: height under the first dab of the stroke). Each dab computes all new values from pre-dab heights, then writes, so the result does not depend on iteration order. Divisions use non-negative operands or `idiv` (truncate toward zero), so GDScript and Python agree. Values clamp to int16.

**Chunks.** `chunk_size` 32 cells (const parameter, tune later; 64 halves the draw calls). 512x512 cells = 16x16 = 256 chunks. One shared flat mesh of 33x33 vertices (1,089 vertices, 2,048 triangles per chunk), reused by all chunk `MeshInstance3D`s; `custom_aabb` covers +-33 m. Vertex shader reads height from the chunk's own RG8 texture (35x35: 33 vertices plus one border texel each side for normals), decoded as `R*256+G-32768` mm using `texelFetch`, nearest filter. Normals are computed in the shader from the 4 neighbouring texels.

**Region updates.** Godot's `ImageTexture.update()` takes a whole image (I know of no sub-rectangle upload in the stable API; unverified, check the docs). So the "region" is one small per-chunk texture (2,450 bytes height, 4,900 bytes splat at chunk 32). `MHDirtyTracker` keeps a rect per dirty chunk so only that rect is rewritten in the CPU byte buffer; then `Image.set_data` + `ImageTexture.update` on that one chunk. Call `MHTerrainChunks.flush(tracker)` once per frame, not per dab.

**Seams.** Shared edge vertices of neighbouring chunks read the same height value, and border texels are refreshed when a neighbour changes (a changed sample dirties up to 4 chunks). So no cracks, no LOD, no skirts. If LOD is added later, skirts or stitching will be needed. Out-of-grid texels are clamped copies of the edge sample.

**Picking.** Ray-march at half-cell steps up to 2,000 m, bilinear height (floats), 10 bisections to refine, returns the rounded integer cell. Floats are used only here (rendering side). The gesture layer stores the integer cell in its command, so replays never depend on float results.

**Save format** (little endian): 20-byte header (`MHTS`, version u16=1, flags u16=1, compressed size, uncompressed size, CRC32 over header bytes 0..15 plus the compressed body), then zstd body: cells_x, cells_y, cell_size_mm, FNV-1a height hash, int16 heights, RGBA splat. Load verifies size, CRC, decompressed size, dimension sanity, and the height hash.
Atomic write: write `<path>.tmp`, flush, close, rename over `<path>`. `flush()` is not a documented fsync, so power-loss durability is not claimed. Process-kill safety is the target.

**Kill-during-save test.** Hooks: `MHTerrainSave.fault_point` (`MID_TEMP_WRITE` = half the bytes written, `AFTER_TEMP_WRITE` = full temp written and closed, rename not done) and `fault_action` (`RETURN_ERROR` for unit tests, `KILL_PROCESS` calls `OS.kill` on itself). Unit tests use RETURN_ERROR. The real kill test is `demo/save_probe.gd`: run write mode (saves v1, then saves v2 with the fault and dies), then verify mode in a fresh process, which must load a complete v1. Expected CI commands (paths relative to repo root, replace `godot` with the pinned binary):
```
godot --headless --path game --script res://terrain/demo/save_probe.gd -- write user://probe.mhts mid   # expected to be killed, exit code non-zero
godot --headless --path game --script res://terrain/demo/save_probe.gd -- verify user://probe.mhts     # must print PASS, exit 0
godot --headless --path game --script res://terrain/demo/save_probe.gd -- write user://probe.mhts after
godot --headless --path game --script res://terrain/demo/save_probe.gd -- verify user://probe.mhts
```
Workstream A owns CI; this is a request to add these steps. (Note: `write` deliberately dies, so CI must not treat its exit code as failure.)

## Numbers (ESTIMATES unless stated; nothing measured)
Computed arithmetic (exact, from formulas): 513x513 = 263,169 samples.
| Item | Size |
| --- | --- |
| Authoritative heights (int32 each) | 1,052,676 B (1.0 MiB) |
| Splat map RGBA8 | 1,052,676 B (1.0 MiB) |
| Height textures, 256 chunks x 35x35x2 B | 627,200 B (0.6 MiB) GPU, plus the same in the CPU byte buffer and again in the Image |
| Splat textures, 256 x 35x35x4 B | 1,254,400 B (1.2 MiB) GPU, plus CPU buffer and Image copies |
| Shared mesh | about 1,089 vertices x 12 B + 6,144 indices x 4 B, about 40 KB total (once) |
| Undo diff | 12 B per changed cell; a 100-dab drag of radius 8 touching about 3,000 cells is about 36 KB |
| Total RAM estimate for terrain data | roughly 8 to 10 MiB (rough, includes the triple copies) |

Draw calls: up to 256 chunk draws for a fully visible 512x512 map (one unique material each), 524,288 triangles in total if everything is visible. That may be too heavy for a low-end phone. Frustum culling helps; chunk size 64 or a merged material path are the fallbacks. To be measured on device.

Per-stroke cost (ESTIMATES, guesses from typical GDScript speed, must be measured): a dab of radius 8 visits about 289 cells (about 201 inside the disc); brush pass maybe 0.1 to 0.3 ms on desktop and maybe 1 to 3 ms on a low-end phone (GDScript is slow). Chunk upload per dab usually 1 to 4 chunks, each about 2.4 KB height + 4.9 KB splat: probably under 1 ms desktop, unknown on phone. Smooth is about 9x the reads of raise. Undo/redo of a 3,000-cell stroke: a tight loop, probably a few ms. Save of a 513x513 map: encode loops 263k cells (int16 encode plus hash plus CRC over the compressed body); estimate 50 to 300 ms on desktop, more on phone; run it off the main thread or at a quiet moment later. Load is similar. Picking: up to about 4,000 bilinear samples per pick worst case; estimate 1 to 5 ms on phone; a coarse max-height grid would speed it up (follow-up).

## 4. Unverified assumptions
- All GDScript syntax and types compile in Godot 4.3 to 4.7 (static vars, typed arrays, inner class `LoadResult`, `class_name` globals need an import/cache pass: run `godot --headless --import` before tests).
- Typed `Array[PackedByteArray]` element write-back semantics (code writes back explicitly).
- `PackedByteArray.compress/decompress` with `FileAccess.COMPRESSION_ZSTD`, `encode_s16/decode_s16`, `slice`, `Image.create_from_data` with `FORMAT_RG8`, `Image.set_data`, `ImageTexture.update` on RG8. Docs: https://docs.godotengine.org/en/stable/classes/class_packedbytearray.html and class_imagetexture.html.
- `DirAccess.rename` overwrites an existing destination on all platforms (docs say so; unverified on Android/iOS `user://`).
- Shader: `texelFetch` in the vertex stage, `filter_nearest`/`filter_linear` hints, NORMAL written in `vertex()`, triangle winding (a-b-c clockwise from above, reasoned on paper). If the terrain is invisible or dark, first try `cull_disabled`. Vertex texture fetch on the Compatibility renderer and old mobile GPUs is untested.
- Splat alpha channel is used as a paint layer; the engine might premultiply RGBA8 textures on some paths.
- `OS.kill(OS.get_process_id())` kills the process on Android/iOS/desktop (probe intended for desktop CI only).
- gdUnit4 API: `assert_int/assert_bool/assert_object`, `override_failure_message`, `before_test/after_test` names for the pinned gdUnit4 version.
- JSON numbers load as floats; code uses `int()` (values below 2^53 so exact).
- `test_cancel_rolls_back_with_no_residue` and others use integer `/` which only warns; if CI treats warnings as errors, the tests need `@warning_ignore`.

## 5. Risks and follow-ups
- 256 unique materials and draw calls, and 4 textures per chunk: likely the first thing to measure. Options: chunk 64, one shared material with a texture array or atlas, view-limited chunk streaming.
- GDScript brush speed on the low-end phone; fallback is a GDExtension in C++ using the same integer math and the golden vectors.
- Splat painting is not in undo and not in the stroke API; needs adding if paint tools are undoable.
- Redo is lost on new stroke (standard). Undo history is not saved.
- Save is synchronous on the main thread; large maps may hitch. Chunked or threaded save is a follow-up.
- No fsync: power loss could still lose the newest save (old file should remain thanks to rename, but the filesystem decides).
- Height range limited to +-32.7 m by int16 mm.
- The gesture layer must call `apply_brush_at` with integer cells, and use `apply_brush_segment` (or its own interpolation) for fast drags to avoid gaps.
- Phase 0 has no separate command log; if replay is required, log (mode, radius, strength, cell) per dab. `MHStroke.dab_count` exists but dabs are not stored.

## 5a. Spec reconciliation notes (workstream H, 29 Sep 2026; no code was changed)
- `docs/spec/interfaces/terrain.md` now describes this module exactly; the drafted `MHTerrain` facade is marked NOT IMPLEMENTED with a mapping table.
- Open follow-ups found while reconciling: (1) `MHPicking.MISS` is `Vector2i(-1, -1)` but `MHStrokeBridge.NO_CELL` is `Vector2i(INT_MIN, INT_MIN)`, so the `screen_to_cell` callable must translate, otherwise a miss dabs the grid corner region; (2) no integer height or slope query exists for the sim and rating; (3) `content_hash` in the course schema is FNV-1a 32-bit over heights only; (4) course schema lists 11 `surface_layers` but the splat has 4 layers; (5) Gate 0 item 5 uses a 600 x 400 cell grid, which is not a multiple of chunk size 32 (partial last chunk, clamped edge texels; the header comment says cells "should be" a multiple, so add a 600 x 400 case to `test_dirty.gd` and `test_save.gd`); (6) `MHSplatMap` edits are not undoable, so "a terrain stroke, undo and integer save round trip" covers heights only.

## 6. For Nathan
Nothing is required from you now. When CI is set up (workstream A), the terrain tests and the Python check run automatically. To try the demo on a desktop later: install Godot 4 (the version in `docs/GODOT_VERSION.md`), open the `game` folder, open `terrain/demo/terrain_demo.tscn` and press F6. Left mouse drag raises, right drag lowers, Ctrl+Z undoes.

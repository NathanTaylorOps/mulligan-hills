# Workstream D: Forest render benchmark

> **Historical Phase 0 record.** This file captures the initial forest/render benchmark plan. Current performance policy is in `docs/verification/PERFORMANCE.md`; only exact-device measurements count as current evidence.

Status: written, **NOT YET RUN**. No Godot binary was available. Nothing in this document is a measurement.

## README block

- **Purpose:** prove (or disprove) that a stylized 3D course with about 800 trees, shadows, water and 40 golfers holds 30 fps on a budget Android phone, and produce numbers a human can photograph.
- **Public API:** `MHQuality` (tier configs, `validate`, `apply_shadows`), `MHTreePlacement` (`place`, `checksum`, `group_by_chunk`), `MHForestRng`, `MHTreeMeshes` (`build_lod0/1/2`), `MHForest` (`build`, `apply_tier`, `set_brush`), `MHWater`, `MHGolfers`, `MHCameraRig`, `MHAdaptiveScale`, `MHBenchStats`, `MHBenchRunner`, `MHResultsScreen`, `MHBenchScene`.
- **Run the scene:** open `game/` in Godot, run `res://bench/bench_scene.tscn`. User args after `--`: `--tier=low|medium|high`, `--autostart`, `--mode=quick|soak`, `--seconds=N`, `--no-adaptive`, `--no-orbit`, `--quit-after-bench`.
- **Run the tests:** gdUnit4 suites in `game/tests/render/` (workstream A wires gdUnit4 into CI).
- **Gate 0 addressed:** the "30 fps forest on a budget Android phone" proof item. Confirm the exact wording in `docs/phase0/GATE0.md` (not present when this was written).

## 1. What was built

`game/render/`
- `mh_forest_rng.gd`: integer-only RNG and hash (`mul32` avoids int64 overflow).
- `mh_tree_placement.gd`: 800 trees in integer millimetres, 4x4 = 16 chunks, pond and fairway exclusion rectangles, checksum.
- `mh_tree_meshes.gd`: procedural conifers. LOD0 42 tris, LOD1 20 tris, LOD2 billboard 3 tris.
- `mh_forest.gd`: one `MultiMeshInstance3D` per chunk per LOD (48) plus one blob-shadow MultiMesh per chunk (16). LOD via `visibility_range_begin/end`.
- `mh_quality.gd`: Low, Medium, High configs, validation, shadow application (off, single-cascade low-res, 2-split higher).
- `mh_water.gd`, `mh_golfers.gd` (40 capsules, bob, visible cap via `visible_instance_count`), `mh_camera_rig.gd` (auto-orbit), `mh_adaptive_scale.gd`.
- `shaders/tree.gdshader` (lit, dither fade by world-space brush), `tree_billboard.gdshader` (Y billboard + dither), `blob_shadow.gdshader`, `water.gdshader`.

`game/bench/`
- `bench_scene.tscn` + `bench_scene.gd`: builds the whole scene in code, HUD with tier buttons (Low, Medium, High) and Quick 60s / Soak 20min buttons.
- `mh_bench_runner.gd`: logs every 5 s and at the end to stdout (`MH_BENCH_WINDOW`, `MH_BENCH_SUMMARY` lines) and `user://bench.json` (rewritten each window so a crash keeps data).
- `mh_bench_stats.gd`: nearest-rank percentiles, summary, verdict rule.
- `mh_results_screen.gd`: full-screen black page, 30 px text of the JSON summary, Copy JSON and Close buttons.

`game/tests/render/`: `test_tree_placement.gd`, `test_quality_tiers.gd`, `test_bench_helpers.gd`.

Logged per window and in the summary: avg fps and ms, p50, p95, p99, max ms, min fps, % frames over 33.4 ms and 50 ms, draw calls (avg, max), primitives (avg, max), static memory, video memory, battery percent, tier, render scale, device model, GPU name, renderer, Godot version, throttle ratio.

**What Godot cannot expose (as far as we know; verify):** device temperature, thermal state or thermal headroom, CPU/GPU clock speeds, throttling level. The harness records battery percent (`OS.get_power_percent_left`, Android availability unverified) and a **throttle ratio** (last-window avg fps divided by first-window avg fps) as a proxy only. Real thermal data needs a native plugin (workstream F) or `adb shell dumpsys thermalservice` run by a person during the soak. The JSON says this explicitly in the `thermal` field.

**Pass rule used by the harness (assumption):** average fps at least 30 and p95 frame time at most 34.0 ms. Change in `MHBenchStats.verdict` if GATE0.md says otherwise.

## Choosing the renderer (one build has one renderer)

A single exported build runs exactly one renderer, chosen at project level. You cannot switch at runtime, so Compatibility and Mobile need two builds and two APKs. All shaders here are written to compile in both.

Both paths need these lines in the `[rendering]` section of `game/project.godot` (owned by workstream A; ask A to add them, or apply as an override in CI):

Compatibility (OpenGL ES 3):
```
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```
Mobile (Vulkan):
```
renderer/rendering_method="mobile"
renderer/rendering_method.mobile="mobile"
```
The `.mobile` line matters because Android exports use the mobile feature-tag override. Setting only the plain key can leave the override winning. Also verify the export preset has the matching graphics API (Compatibility needs OpenGL; Mobile needs Vulkan). The bench JSON records `renderer_setting` and, if the engine exposes it, `renderer_active`, so a mislabelled build is detectable from the photo.

CI suggestion for A: build two artifacts by rewriting those two lines before `--export-debug`, named `mh-bench-compat.apk` and `mh-bench-mobile.apk`.

## 2. How it is tested

Written, NOT YET RUN: 3 gdUnit4 suites (placement determinism, tier validity, stats/args/adaptive logic).

What WAS run: a Python 3.11 transcription of the RNG, hash and placement produced the golden vectors embedded in `test_tree_placement.gd`. That checks my algorithm design and the vectors, not the GDScript port. If the GDScript disagrees with Python, the port has a bug.

Reference (Python, for regenerating vectors):
```python
M = 0xFFFFFFFF
def mul32(a, b): return ((a * (b & 0xFFFF)) + (((a * (b >> 16)) & 0xFFFF) << 16)) & M
def hash32(x):
    x &= M; x ^= x >> 16; x = mul32(x, 0x7FEB352D); x ^= x >> 15; x = mul32(x, 0x846CA68B); x ^= x >> 16
    return x & M
class Rng:
    def __init__(s, seed): s.s = hash32((seed & M) ^ 0x9E3779B9)
    def next(s):
        s.s = (mul32(s.s, 1664525) + 1013904223) & M
        return hash32(s.s)
    def rng(s, n): return s.next() % n
W, GRID = 400000, 4
EXCL = [(150000,160000,250000,240000),(40000,90000,360000,130000)]
def place(seed, count):
    r = Rng(seed); out = []
    for _ in range(count):
        ok = False
        for _ in range(64):
            x = r.rng(W); z = r.rng(W)
            if not any(a<=x<=c and b<=z<=d for a,b,c,d in EXCL): ok = True; break
        yaw = r.rng(3600); sc = 80 + r.rng(61); var = r.rng(3)
        if ok: out += [x, z, yaw, sc, var, (x//100000) + (z//100000)*GRID]
    return out
def checksum(a):
    h = 0x811C9DC5
    for v in a: h = mul32(h ^ (v & M), 16777619)
    return h
# place(12345, 800) -> 800 trees, checksum 1635380594; place(777, 800) -> 2579281832
```
Golden results: chunk counts for seed 12345 are 61,55,48,58,48,35,25,57,65,43,39,55,59,65,44,43.

Not run and not testable without a device: everything visual, all shaders, frame times.

## 3. Gate 0 evidence CI or the device run must produce

1. CI: the gdUnit4 suites pass on Godot 4.x (version pinned by A in `docs/GODOT_VERSION.md`).
2. CI: project imports and `bench_scene.tscn` loads with no shader compile errors (headless run with `--tier=medium --autostart --seconds=5 --quit-after-bench`; headless has no real GPU, so this only proves scripts parse and the scene builds. Shader compile is not proven headless).
3. Device (budget Android): `bench.json` from a Quick run per tier per renderer (6 files) and a Soak run of the tier that passes Quick. A photo of the results screen for each.
4. Pass: verdict `PASS_30FPS` on the chosen renderer/tier, with throttle ratio at or above 0.85 on the soak (0.85 is my proposed threshold, not from GATE0).

## 4. Unverified assumptions (check before trusting)

Docs root: https://docs.godotengine.org/en/stable/
- `MODEL_MATRIX` in `vertex()` includes the MultiMesh instance transform (used for `world_pos`, dither distance).
- `COLOR` in a spatial shader is vertex colour multiplied by the MultiMesh instance colour when `use_colors` is on.
- Billboard `MODELVIEW_MATRIX` / `MODELVIEW_NORMAL_MATRIX` override works per instance in both renderers.
- `discard` in tree shaders: correct in both, but disables early-Z on tile GPUs (see risks).
- `GeometryInstance3D.visibility_range_*` on `MultiMeshInstance3D` distance is measured to the whole instance's AABB centre. If it is measured differently, LOD bands shift.
- `RenderingServer.directional_shadow_atlas_set_size(size, bool)` signature.
- Directional shadow modes `SHADOW_ORTHOGONAL` and `SHADOW_PARALLEL_2_SPLITS` behave the same in Compatibility as in Mobile; Compatibility shadow quality settings may differ.
- `Viewport.msaa_3d` in Compatibility on Android (High tier requests 2x).
- `Viewport.scaling_3d_scale` with `SCALING_3D_MODE_BILINEAR` in Compatibility.
- `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_TOTAL_PRIMITIVES_IN_FRAME`, `RENDER_VIDEO_MEM_USED` return real values on Android in both renderers.
- `OS.get_power_percent_left()`, `OS.get_model_name()`, `DisplayServer.screen_set_keep_on()` behaviour on Android.
- `RenderingServer.get_current_rendering_method` / `get_current_rendering_driver_name` exist in the pinned version (guarded with `has_method`).
- Passing user args on Android (`--tier=low`) is device-launch dependent; the on-screen buttons are the reliable path.
- gdUnit4 assertion names used (`is_between`, `is_less_equal`, `is_empty`, `is_not_empty`).
- Godot front-face winding is clockwise; `MHTreeMeshes.Builder.tri` auto-orients faces relative to an outward point. Look for inside-out trees on first run.
- GDScript typed-array warnings and `as Viewport.MSAA` cast may need small edits when the parser runs.

## 5. Risks and follow-ups

Performance risks, most likely first:
1. **Fill rate and overdraw on the phone GPU.** Trees overlap heavily, blob quads and water are blended, and 3D resolution is the main cost on budget GPUs. Mitigated by adaptive scale but this is the most likely reason to miss 30 fps.
2. **Shadow pass cost.** Every shadowed tree is drawn again into the shadow map, and shadow sampling is expensive on low-end GPUs, especially in Compatibility.
3. **`discard` dither** breaks early-Z / hidden-surface removal on tile-based GPUs, so shader cost rises for all tree fragments even away from the brush.
4. **Chunk-level LOD.** Visibility ranges act per MultiMeshInstance3D, so a 100 m chunk swaps LOD as a block. Trees far from the chunk centre may look wrong (too detailed far away or popping near). If it looks bad, split to smaller chunks (2x more nodes) or add per-tree CPU LOD.
5. **Draw calls.** Expected roughly 16 chunk instances + 16 blobs + a handful of others in the main pass, plus shadow pass repeats. Small, but verify against the logged `draw_calls_max`; hidden LOD nodes still cost culling work.
6. **Thermal throttling in the 20 min soak.** Cannot be measured directly (see above). Expect the first 5 min to look better than the last 5.
7. **Transparent water** with per-pixel sine normals on a large screen area.
8. **Memory:** low expected, procedural meshes only. Still logged.
9. **The bench is a synthetic scene.** Real courses add terrain, grass, UI and simulation. Headroom of at least 15 percent is advisable before calling the gate closed.

### Mitigation ladder if 30 fps is missed (apply in order, re-run Quick after each)

1. Turn adaptive render scale floor down (Low min 0.6 to 0.5) and cap it as the default on the phone tier.
2. Switch shadows off (Low tier) and keep blob shadows.
3. Remove `discard` dithering (`foliage_dither` false), replace with a plain alpha-free hide of trees in the brush radius (CPU side, hide instances).
4. Disable MSAA and water waves (flat colour water, no normal animation).
5. Drop LOD0 everywhere (already Low); shorten `lod1_end` so billboards start closer.
6. Cut visible golfers from 40 to 20, then 10 (`max_golfers`), and turn golfer shadows off.
7. Reduce tree count 800 to 500, then 300, thinning the far chunks first.
8. Switch water from blended to opaque flat colour.
9. Switch renderer (Mobile to Compatibility or the reverse) and compare; keep whichever wins on the target phone.
10. Lower the frame target: ship a 30 fps cap with 3D scale 0.6 minimum and reduce the camera far plane from 700 m.
11. If still failing, escalate to a Gate 0 decision (reduce course scope or raise minimum device spec). This is a design decision for the manager, not a code fix.

## 6. For Nathan

Do this only after workstreams A and F have produced an installable debug build (check `docs/phase0/ci.md` and `docs/phase0/platform.md`; package name and download steps are in those documents, and were not available when this was written).

1. Install the Compatibility build on the phone. Unplug the charger (run on battery), set screen brightness to about 50 percent, let the phone cool to room temperature, and take the case off.
2. Open the app. It starts on the Medium tier in the forest scene.
3. Tap **Low**, then tap **Quick 60s**. Wait 60 seconds. A black screen with large text appears. Take a clear photo of it. Tap **Close**.
4. Repeat step 3 for **Medium** and **High**.
5. Tap the tier that looked best and still reported `PASS_30FPS`, then tap **Soak 20min** and leave the phone on a table. When the text screen appears, take a photo.
6. Install the Mobile-renderer build and repeat steps 2 to 5.
7. Send all photos to the lead, labelled with the phone model and renderer.

To also pull the raw file (needs the phone connected by USB with debugging on and `adb` installed; replace PACKAGE with the package name from `docs/phase0/platform.md`):
```
adb shell run-as PACKAGE cat files/bench.json > bench_compat_medium.json
```
(Unverified: `run-as` works only for debug builds; the path may differ. The photo of the results screen is the primary evidence.)

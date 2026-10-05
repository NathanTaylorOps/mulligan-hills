# Phase 1: procedural art, nature + golfers + props (`game/art/nature`, `golfers`, `props`, `shared`)

Status: written 4 Oct 2026. NOT YET RUN. Nobody could start Godot here, so none of this GDScript has been parsed or executed by the engine. The pose keyframes and the `MHArtRng` goldens were computed with Python mirrors (they ran); everything else is unverified until CI. Expect small parse or typing fixes on the first red run (see docs/phase1/README.md lessons).

Art is fully procedural from code (DEC-062): no imported assets, no textures, no downloads. Everything is flat shaded with vertex colours from `MHPalette`, one surface per mesh (MultiMesh friendly), one shared material (`MHArtMaterials.vertex_color()`).

## 1. What was built

Shared (`game/art/shared/`, written by a cut-off agent, reviewed here; API unchanged, additive only)
- `MHMeshBuilder`: triangle, quad, box, tube, frustum, blob (jittered ellipsoid), disc, two-sided helpers, deterministic geometry hash.
- `MHPalette`, `MHArtMaterials`, `MHArtRng` (integer RNG, same family as `MHForestRng`), `MHSkySetup`.

Nature (`game/art/nature/mh_nature_meshes.gd`, `MHNatureMeshes`): pine, oak, birch, palm, bush, rock, rock cluster, flower patch, reeds, cattails, tall grass. 3 LODs each, 4 variants each (any int works, wraps mod 1024), seeded and deterministic. Tree LOD0 156 to 244 triangles (limit 400). Per-kind, per-LOD budgets are in `BUDGETS`.

Golfers (`game/art/golfers/`)
- `MHGolferLook`: colours, hair or hat style (short, long, cap, sun hat), height 0.92 to 1.08, build 0.9 to 1.15. `from_seed(n)` is deterministic and draws from the palette lists (6 skin tones, 7 hair, 8 outfits, 5 trousers, 4 shoes).
- `MHGolferMeshes`: 12-joint low-poly body, part geometry per joint, forward kinematics (`joint_transforms`), `build_posed()` bakes the whole golfer into ONE mesh at a pose. LOD0 about 200 to 230 triangles (budget 250), LOD1 about 145 to 165 (180), LOD2 86 (100, no club, hands, shoes or hair).
- `MHGolferPoses`: keyframe data and `sample(clip, t)` for `idle` (3.0 s loop), `walk` (1.0 s loop), `swing` (2.4 s, impact at 1.25 s) and `putt` (1.6 s, impact at 0.95 s), plus `impact_time`, `is_looping`, `blend`.
- `MHGolferFigure`: Node3D joint tree (one MeshInstance3D per joint), `setup(look, lod, material)`, `play(clip)`, `advance(dt)`, signals `impact` and `clip_finished`. `advance` is public and needs no scene tree.

Props (`game/art/props/mh_prop_meshes.gd`, `MHPropMeshes`): flag, hole cup, tee marker, bench, golf cart, sign (with `SIGN_FACE_CENTER`/`SIGN_FACE_SIZE` for a Label3D), fence section (4 variants: post and rail, picket, post and rope, low stone wall; section runs x = 0 to `FENCE_LENGTH` 2.0 so it tiles along X), golf bag, bin, umbrella, golf ball. 2 LODs, 4 variants each.

Gallery: `res://art/mh_nature_gallery.tscn` (`game/art/mh_nature_gallery.gd`, `MHNatureGallery`). Pages: Trees, Plants, Rocks, Golfers, Props, Stress. LOD button cycles LOD 0, 1, 2, All. Each row is labelled with its largest triangle count and budget. Golfers page: animated joint-tree figures (idle, walk, swing, putt) above baked one-mesh rows. Stress page: 240 trees in MultiMeshes with LOD by distance, fps readout bottom right. Drag to orbit, mouse wheel or Zoom buttons, Pause, Shadows toggle, Back to launcher. Buttons are `MHTapButton` with `MHTouchBridge` (touch works with `emulate_mouse_from_touch` off).

NOT done by me: the gallery is not registered in `MHLauncher.SCENES` (`game/ui/` is not mine). One line to add:
`["Art gallery (nature, golfers, props)", "res://art/mh_nature_gallery.tscn"],`

## 2. Conventions (shared by golfers and props)

Metres, origin on the ground, +Y up. Golfers and fronted props (bench, cart, sign) face +Z. A right-handed golfer aims along +X (the left side is +X), same as `MHProceduralSwing`. Pose values are Euler degrees composed as R = Rx * Ry * Rz built from three explicit axis rotations (no dependence on Godot's Euler order). Hanging limbs swing forward with NEGATIVE x; knees bend with positive x on `leg_*_lower`, elbows with negative x on `arm_*_lower`; spine x bends forward, spine y turns the chest (negative = backswing). `club_scale` scales the club length (putter 0.82). Ball position at address is about (0, 0.04, 0.96) for swings and (0, 0.06, 0.70) for putts (club head centre, golfer frame).

## 3. Tests (NOT YET RUN), `game/tests/art/`

- `test_art_rng.gd`: golden values from a Python port (the first three sequence values for seed 12345 equal the `MHForestRng` goldens, which cross-checks the two generators), ranges, determinism.
- `test_palette.gd`: contrast helpers, `text_on`, `pick` wrapping, list sizes, accents readable on grass (min 1.5).
- `test_mesh_builder.gd`: triangle counts, clockwise winding and outward normals (recomputed from the emitted vertices), tube ends, transform restore, degenerate drop, hash determinism, material and MultiMesh factories.
- `test_nature_meshes.gd`: every kind, LOD and sampled variant stays inside its budget, tree LOD0 under 400, LODs strictly cheaper, determinism, variety (at least 3 distinct of 4 variants), variant and LOD clamping, plausible size and ground contact, valid vertices, normals, colours.
- `test_golfer_meshes.gd`: 40 looks inside the golfer budgets at all 3 LODs, parts sum to the baked total, determinism, look variety, standing height 1.6 to 2.0 m and feet on the ground, rotation sign conventions, club scale, hips shift.
- `test_golfer_poses.gd`: clip structure, loop closure, clamping, sampling, impact on a keyframe, club head within 0.12 m of the ball at address and impact, two-hand grip gap under 0.08 m at keys and 0.12 m at 20 samples per second, lowest ankle 0 to 8 cm above ground in every clip, club head never below ground, chest turns away then through.
- `test_golfer_figure.gd`: joint tree, one mesh per part, node poses equal forward kinematics, impact fires once, finish fires once, loops, speed, stop, replay.
- `test_prop_meshes.gd`: budgets, LOD, determinism, 4 distinct variants per kind, size, cart and fence dimensions, sign label area, validity.
- `test_gallery_smoke.gd`: scene file loads, every page at every LOD mode builds headless (no tree, no camera), rebuild replaces rather than stacks, stress page is 240 trees in under 80 MultiMesh nodes.
- `test_print_hashes_for_golden_values` (nature and props files) only prints `ART_HASH ...` lines. After the first green CI run, paste those into golden asserts. Golden mesh hashes are not stored now because Godot could not run to produce them.

What actually ran (Python mirrors): `MHArtRng` maths and goldens; pose solving, grip gap, ankle height, club head position, interpolation check (worst grip gap between keys 0.077 m, lowest ankle never under 0.018 m, club head never under 0.018 m); triangle counts were checked by hand against the code.

## 4. Review of the cut-off agent's files (what I changed)

- Palm fronds, bent blades (reeds, cattails) coloured left to right instead of base to tip: `quad_two_sided` colours the a/d edge with `ca` and the b/c edge with `cb`, and callers passed the corners in the wrong order. Fixed in the callers (corner order start-left, end-left, end-right, start-right) and documented on `quad_two_sided`. No behaviour change in the builder, so other users (buildings) are unaffected.
- `hash_arrays` loops are now typed (`for p: Vector3 in v`).
- `_rng` had an unused `lod` parameter (warning), renamed `_lod`. Header comment pointed at `tests/art_nature/`, now `tests/art/`.
- Documented that `hash_mesh` (colours read back after the engine stores them as 8-bit, rounding rule unverified) equals `geometry_hash` only for colours that are exact multiples of 1/255. All tests compare builder hashes with builder hashes.
- Checked by reading: winding (`tri` flips to clockwise by the outward hint), `blob` triangle formula 2*sides*(stacks-1), all tree and ground-cover triangle counts against budgets, `MHArtRng` integer maths (matches the existing forest goldens), `make_multimesh` property order (transform format and colour flag before instance count).
- Not changed, flagged: palette contrast. Yellow and white on sand is 1.1 to 1.3 (FLAG_YELLOW 1.13, TEE_YELLOW 1.14, FLAG_WHITE 1.27, CART_BODY 1.22, BALL_WHITE 1.30), so flags, tee markers and balls will nearly vanish on bunkers. Red on grass is 1.57 (just over the 1.5 test floor). The palette is shared and must stay backward compatible, so I did not touch it.
- The "pine" is a flat cloud-crowned Scots pine, not a cone. A conifer cone would be a cheap add if Nathan wants one.

## 5. Unverified (UNVERIFIED, check on first CI run)

Engine APIs and syntax used from memory of the Godot 4 docs:
- `Basis(Vector3 axis, float angle)`, `Basis.from_scale`, `Basis.scaled`, `Basis.is_equal_approx`, `Basis.x/.y/.z` as columns.
- Vector3 constructors inside `const` Array and Dictionary literals (pose keyframes).
- Typed `for x: Type in` loops, typed signal parameters, `signal.connect(method.bind(extra))` passing emitted arguments first and bound ones after, lambdas appending to a captured Array in tests.
- `@warning_ignore("integer_division")` on a local `var` statement.
- `Node.find_children(pattern, type, recursive, owned)` with `owned = false` (nodes made in code have no owner).
- `ArrayMesh.add_surface_from_arrays` with `PackedColorArray` and an index array, `get_aabb()`, `surface_get_arrays()` colour read-back rounding.
- `MultiMesh` (set `transform_format` and `use_colors` before `instance_count`), `GeometryInstance3D.cast_shadow` on a `MultiMeshInstance3D`.
- `Label3D` properties `font_size`, `pixel_size`, `billboard`, `no_depth_test`, `outline_size`; `HFlowContainer`; `Control.PRESET_TOP_WIDE`, `GROW_DIRECTION_BEGIN`; `MOUSE_BUTTON_MASK_LEFT`; `Engine.get_frames_per_second()`.
- `StandardMaterial3D.vertex_color_is_srgb`, `metallic_specular`; `ProceduralSkyMaterial` property names (existing shared code).
- Instance colours in a MultiMesh multiply vertex colours (assumed; only matters if per-instance tint is used).
- gdUnit4 asserts used: `is_between`, `is_less`, `is_less_equal`, `is_greater`, `is_greater_equal`, `is_equal_approx(value, approx)`, `override_failure_message` (all already used elsewhere in the repo).
- Headless: `MultiMesh`, `ArrayMesh`, `Label3D` created with the dummy renderer and no scene tree.

## 6. Risks and performance notes

- Draw calls: a LOD0 `MHGolferFigure` is 12 MeshInstance3D nodes. 20 golfers (low tier cap) is 240 draw calls, which is too many for the low-end phone. Use figures only for the few golfers near the camera and `MHGolferMeshes.build_posed` (one draw call, one mesh per look and pose, MultiMesh per look) for the rest. A cache of baked walk and swing frames per look is the follow-up if the Gate 0 phone shows the joint tree is too slow. I did not build it because the cost depends on measured phone numbers (DEC-061).
- Triangle budget guide: a full gallery tree page is under 3,000 triangles for 16 trees at LOD0; the stress page (240 trees, LOD by distance) is the number to read on the phone.
- LOD distances: `MHQuality` already has `lod0_end` and `lod1_end` per tier. The art classes take an explicit `lod`; the caller (forest, golfers manager) should map distance to LOD with those values. Not wired, because the old `MHForest` / `MHTreeMeshes` / `MHGolfers` (capsule stand-ins) are not mine.
- Pose data are first guesses solved on stick figures. Expect the swing to need a visual tuning pass in the gallery. Euler lerp between keys keeps the two hands within 8 cm of the grip but intermediate wrist and club angles can look odd for a frame or two. The right hand is the club joint origin and the left hand is only held near the grip by pose data (no IK at runtime).
- `club` joint rotation is relative to the right forearm, so a club that clips into the ground on uneven terrain is not handled (there is no terrain contact logic).
- The walk cycle does not move the golfer; the caller translates the figure root.
- Floats: `cos`/`sin` can differ in the last bit across CPUs; hashes quantise to 1 mm and 1/255 so they should survive, but cross-platform equality of golden hashes is unverified (art is visual only, never feeds the sim hash).

## 7. For Nathan

Questions:
1. Is two-hand grip by pose data (no IK) acceptable for v1, given golfers are small on a phone screen?
2. The golf ball prop is drawn at 2x real size so it reads on a phone. Keep?
3. Do you want a conifer cone tree, hedges, bunker rakes, ball washers or a clubhouse flag added? They are cheap with the builder.
4. Should the old capsule golfers and `MHTreeMeshes` be replaced now by `MHGolferFigure` / `MHNatureMeshes` (touches `game/render/`, which is another workstream)?
5. Yellow and white accents vanish on sand. Change the palette (shared with buildings) or outline-darken accents?

To apply (Nathan, if you want the gallery in the launcher): add the line in section 1 to `MHLauncher.SCENES` in `game/ui/mh_launcher.gd`.

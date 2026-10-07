# Workstream G: golfer characters and animation (Phase 0)

> **Historical Phase 0 record.** This file captures the original character/animation feasibility work. Current art direction, provenance policy and exact build evidence take precedence.

Status date: 2026-09-29. Author: workstream G agent (Claude). Godot pin per `docs/GODOT_VERSION.md` (4.7.2).

## README block

- **Purpose:** remove the "we have no animator" risk. Prove we can get a rigged, animated golfer into Godot with no artist, no mocap and no licence trouble.
- **Public API (GDScript, all typed, NOT YET RUN):**
  - `MHGolferRig` (`game/characters/mh_golfer_rig.gd`): `load_model()`, `missing_bones()`, `build_bone_map()`, `skeleton_track_path()`, `capture_rest_rotations()`, `hips_rest_position()`, `install_animations(lib)`, `attach_to_bone(bone, node)`, `apply_vertex_color_material()`.
  - `MHProceduralSwing` (`mh_procedural_swing.gd`): `build_library(skeleton_path, rest_rot, hips_rest)` returns idle, address, walk, putt, swing_full; `make_animation(...)`; consts `IMPACT_TIME_PUTT`, `IMPACT_TIME_SWING_FULL`.
  - `MHGolferAnimator` (`mh_golfer_animator.gd`): `setup(player)`, `set_state(State.X)`, signals `impact` and `one_shot_finished`.
- **Python tool:** `python3 tools/animation/make_golfer_gltf.py [--seed N] [--name X] [--out-dir D] [--obj] [--validate FILE]`.
- **How tests run:** Python: `python3 -m unittest tools/animation/test_make_golfer_gltf.py` (was run, passes). GDScript: gdUnit4 suite `game/characters/tests/test_animation_build.gd` (NOT YET RUN).
- **Gate 0:** see section 3.

## 1. What was built

| File | What |
| --- | --- |
| `tools/animation/make_golfer_gltf.py` | Pure-stdlib generator: glTF 2.0 JSON + `.bin` written with `struct`. Skinned low-poly golfer, 23 bones, vertex-colour toon palette, variants by `--seed`. Includes a structural validator (`--validate`) that re-reads the files independently of the builder. Optional `--obj` writes a T-pose OBJ for Mixamo. |
| `tools/animation/test_make_golfer_gltf.py` | 4 unittest cases: 40 seeds validate, determinism, required bones, validator catches corrupted weights. |
| `game/characters/golfer_placeholder.gltf` and `.bin` | Seed 1 output: 1306 triangles, 805 vertices, 23 joints, 57 KB bin. |
| `game/characters/mixamo_test/upload/golfer_placeholder_tpose.obj` | Same mesh as static T-pose OBJ (for Mixamo). `mixamo_test/README.md` explains the folder. |
| `game/characters/mh_golfer_rig.gd` | `MHGolferRig`, see above. |
| `game/characters/mh_procedural_swing.gd` | `MHProceduralSwing`: keyframed bone-rotation clips built in code. |
| `game/characters/mh_golfer_animator.gd` | `MHGolferAnimator`: state to clip map, per-pair crossfade table, impact signal. |
| `game/characters/tests/test_animation_build.gd` | gdUnit4 tests. Placed under `game/characters/tests/` because G does not own `game/tests/`; lead may move it. |
| `docs/LICENSE_LEDGER.md` | Licence table, initialised. |

Model facts: T-pose rest, all rest rotations identity, faces +Z, character's left is +X, about 1.85 m tall, big head. Bones use the Godot humanoid names (Hips, Spine, Chest, UpperChest, Neck, Head, LeftShoulder, LeftUpperArm, LeftLowerArm, LeftHand, LeftUpperLeg, LeftLowerLeg, LeftFoot, LeftToes, and Right...) plus an unskinned `Root` above Hips (the full Godot profile has a Root; whether it is required is unverified). Variants: 6 skin tones, 7 hair colours, hair (short, ponytail, bun, bald), headwear (none, cap, visor, bucket), 8 shirt colours, short or long sleeves, shorts or trousers, shoe colour, left glove, height 0.95 to 1.05, girth 0.9 to 1.15. Across seeds 0 to 199 the triangle count ranged 940 to 1354 and every file validated.

## 2. How it is tested, and what has NOT been run

**Run here (Python 3.11):**
- Generator ran; output validated: JSON structure, buffer sizes and alignment, accessor bounds and counts, POSITION min/max match the data, indices in range, no degenerate triangles, positive signed volume (winding), unit normals, colours in 0..1, every vertex has weights summing to 1 with valid joint indices, node graph is a tree with no cycles, inverse bind matrices equal translate(-world position), all 22 required Godot humanoid bone names present, every bone except Root has skin influence. 200 seeds pass. Two deliberate corruptions (truncated bin, bad weights) are caught.
- 4 unittest cases pass.

**NOT RUN (say it plainly):**
- **No GDScript was executed.** No Godot was available. Parse errors, type errors and wrong API names are all possible. CI (workstream A) must run the gdUnit4 suite.
- The glTF was **never imported into Godot or any other viewer**. The structural checks above cannot prove it looks right or imports cleanly. No external glTF validator (Khronos `gltf-validator`) was run.
- The **poses and timings have never been seen moving.** The Euler numbers are geometric first guesses. Expect the swing to need a tuning pass: an hour or two in a Godot scene looking at the rig, changing numbers in `MHProceduralSwing.keys_*`.
- Nothing was tested on a device.

## 3. Gate 0 criteria covered and evidence CI must produce

`docs/phase0/GATE0.md` did not exist when this was written, so I do not know whether Gate 0 has an animation item. Proposed evidence if it does ("a rigged animated golfer runs in the game with zero external assets"):
1. CI job runs `python3 -m unittest tools/animation/test_make_golfer_gltf.py`: must pass.
2. CI regenerates the model and diffs it against `game/characters/golfer_placeholder.gltf/.bin` (generator is deterministic per seed): must match.
3. CI runs gdUnit4 `game/characters/tests/`: must pass.
4. CI headless import: Godot `--headless --import` must finish with no error on the glTF.
5. Device evidence (workstream I): one scene with 4 animated golfers on the low-end Android phone, frame time recorded.

## 4. Unverified assumptions

Code and engine (all from memory, none checked, because the Godot class pages returned only navigation text when fetched and GitHub raw was blocked by the proxy). Check each against https://docs.godotengine.org/en/stable/classes/ :
- `Animation`: `add_track`, `track_set_path`, `rotation_track_insert_key`, `position_track_insert_key`, `track_set_interpolation_type`, `loop_mode`, `LOOP_LINEAR`, `TYPE_ROTATION_3D`, `TYPE_POSITION_3D`, `track_get_key_value`.
- `Basis.from_euler` default order is YXZ (R = Ry * Rx * Rz). Every pose value assumes this.
- `Basis.get_rotation_quaternion()`, `Skeleton3D.find_bone`, `get_bone_rest`, `Node.find_children(pattern, type, recursive, owned)` with `owned=false`, `Node.get_path_to`, `AnimationPlayer.root_node`, `add_animation_library`, `play(name, custom_blend)`, `current_animation_position`, `animation_finished(anim_name)`.
- `BoneAttachment3D.bone_name`, `BoneMap.profile`, `BoneMap.set_skeleton_bone_name`, `SkeletonProfileHumanoid` bone-name strings, and whether `BoneMap` is useful at runtime at all (I believe it is an import-time retargeting tool).
- `const X: PackedStringArray = [...]` and constant Dictionaries keyed by enum values and other classes' constants are accepted by the parser.
- Typed `for x: Type in ...` loops need Godot 4.2 or later (fine for the 4.7 pin).
- The glTF importer turns `COLOR_0` into vertex-colour albedo automatically. If not, call `MHGolferRig.apply_vertex_color_material()`.
- The importer keeps the node name `Skeleton3D` and bone names as authored, and gives a scene root that `AnimationPlayer.root_node` can point at. `skeleton_track_path()` computes the path at run time to avoid depending on that.
- Poses: sign conventions (for example "-X lifts the thigh forward", "-Y turns chest away from the target") were derived by hand for a +Z-facing rig with left = +X and not visually confirmed.

Licence facts (fetched 2026-09-29 by page fetch; **must be re-checked by a human before anything ships**):
- Mixamo FAQ text is quoted in the ledger. The formal Adobe terms governing Mixamo were not located.
- Kenney and Quaternius CC0 statements read from their own pages. Which Quaternius edition (free vs paid) the CC0 text covers is not confirmed.
- Whether Mixamo has golf swing or putt clips: **not verified** (site needs JavaScript and login; web search returned nothing conclusive).
- Mixamo details recalled but not in the fetched FAQ: accepts FBX, OBJ or ZIP uploads (not glTF); marker placement for chin, wrists, elbows, knees, groin; skeleton options with or without fingers; download dialog options "FBX for Unity (.fbx)", with or without skin, frames per second. Step 6 tells Nathan to note what he actually sees.

## 5. Decision analysis

### 5.1 What we need

A golfer who addresses a ball, swings (driver, iron, chip, putt, bunker), reacts (good shot, water, out of bounds), celebrates, and walks between shots, in a chunky stylised look (big head, short limbs), on phones, with no artist and no budget for mocap. The hard part is not generic locomotion. It is (a) hands staying together on a club at address for a body with non-realistic proportions, (b) the ball leaving the club at a moment the game controls, (c) licence certainty.

### 5.2 Options

**A. Mixamo retargeting.**
- Licence (verified from FAQ, https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html): "You can use both characters and animations royalty free for personal, commercial, and non-profit projects including: Create video games." Free with an Adobe ID, no Creative Cloud subscription. Not available to Enterprise/Federated IDs or users with China country codes. The FAQ says nothing about redistributing raw files (so a public GitHub repo full of FBX is a grey area) and nothing about AI/ML use.
- Auto-rigger limits (verified from FAQ): humanoid only ("bipedal humanoids only") with "distinguishable head, body, arm, and leg areas", "default or neutral pose", mesh "clean and error free", no separate appendages, props or extra objects. Our generated golfer is built from overlapping tubes, so it may fail the "clean mesh" rule; hair, ponytail and cap are separate shells inside the same mesh and might be read as extra objects. A Mixamo default character avoids this but is realistic, so it proves little about chunky proportions.
- Chunky proportions (my judgement, not a source): Mixamo clips are authored for realistic adult proportions. On a big-head, short-arm rig, expect foot sliding, hands passing through the body and hands that no longer meet on a club. The auto-rigger places joints from four or five markers you set, so a stylised body can still rig, but the motion is not re-solved for it.
- Coverage: large generic library (locomotion, emotes, reactions). Golf-specific clips: unverified.
- Pipeline cost: import FBX, Godot retarget import with a BoneMap (https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html, not fetched), then fix hands by hand or with IK. Files are FBX: Godot 4 FBX import goes through the bundled FBX importer (check current status in the docs).
- Fits the ball-impact need: no. Impact time is baked into the clip and we would have to read it off by eye.

**B. CC0 packs (Kenney, Quaternius, others).**
- Licence: CC0 statements read on kenney.nl and quaternius.com (see ledger). Cleanest licence of all options; no attribution needed, no redistribution question.
- Content: Quaternius Universal Animation Library lists 120+ animations (locomotion, combat, emotes, push, crawl, swim, sit, death), rig for retargeting in Godot/Unity/Unreal, FBX/GLB/Blend. No golf clips mentioned. Kenney Animated Characters 1 is zombie/survivor themed (CC0), animation list not readable in the fetch. I did not find a CC0 pack with golf swings; a search for golf animation packs surfaced only paid marketplace items (Superhive/Fab "Golf Animations (Motion Cast#05)", not evaluated, not CC0 as far as we know).
- Same chunky-proportion retarget problem as Mixamo. Useful for generic walk/idle/emote, useless for the core golf clips.

**C. Procedural pose-and-tween from code (built here).**
- Zero licence surface. Tiny (a few KB of script, no clip files). Deterministic. We control hand placement exactly because poses are defined on our own skeleton, so proportions do not matter. Impact time is a constant the game reads (`IMPACT_TIME_*`), and clips can be regenerated when the rig changes. Works the same on every platform. Easy to vary per golfer (speed, tempo) by changing constants.
- Weakness: motion quality. Linear interpolation between hand-guessed poses looks robotic. Mitigation options: more keys, cubic interpolation, ease curves, secondary motion (hair, cap) in code. It suits a toon look where held poses and snappy pose-to-pose motion read as style. Real risk: the tuning needs someone looking at a screen, and nobody has yet.
- Weakness: scales poorly to 25 varied clips unless we build a small pose library and helpers. The structure (`pose_*`, `keys_*`, `merged`, `swap_sides`) is meant for that.

**D. Hand-authored bone animation (Blender or Godot animation editor).**
- Best possible control and look, no licence issue. Needs a skilled animator or a lot of Nathan's time to learn; Claude cannot see the result while authoring. Not viable for Phase 0. Revisit if a contractor is hired: the placeholder rig and bone names are already retarget-ready, so a contractor's clips would drop in.

### 5.3 Scoring (1 poor to 5 strong; judgement, not measured)

| Criterion | A Mixamo | B CC0 packs | C Procedural | D Hand-authored |
| --- | --- | --- | --- | --- |
| Licence certainty | 3 (FAQ good, terms not read, redistribution unclear) | 5 | 5 | 5 |
| Golf-specific coverage | 2 (unverified) | 1 | 4 | 5 |
| Works with chunky proportions | 2 | 2 | 5 | 5 |
| Motion quality out of the box | 4 | 4 | 2 | 5 |
| No artist needed | 5 | 5 | 4 (needs a tuning pass) | 1 |
| Control of ball impact timing | 2 | 1 | 5 | 4 |
| Effort to reach 25 clips | 3 | 2 (only generic ones) | 3 | 1 |
| Runtime size on phone | 3 | 3 | 5 | 3 |

### 5.4 Recommendation

- **Primary: C, procedural pose-and-tween, for every golf-specific clip and every clip where hands must meet or timing drives gameplay** (address, all swings, chip, putt, bunker, tee up, pick up ball, rake). It is the only option that is licence-clean, proportion-proof and gives us the impact timing. The build here already covers idle, address, walk, putt and full swing.
- **Fallback: A+B hybrid for generic body motion.** If the procedural walk or emotes look bad after tuning, retarget CC0 Quaternius locomotion and emotes first (clean licence), and use Mixamo only for gaps (for example celebrate, disappointed head-shake). Mixamo goes second because of the unresolved redistribution question and the unread formal terms.
- **Kill or promote rule:** Nathan's Mixamo test (section 6) is cheap and answers two questions: does Mixamo have golf clips, and does the auto-rig accept our chunky mesh. If a Mixamo golf swing exists AND retargets acceptably to the placeholder, promote Mixamo to primary for swing bodies but keep code for impact timing. Decide after one tuning pass on the procedural swing, so we compare like for like.
- **Last resort:** stepped (no interpolation) held poses with a few frames per action. In a toon style this reads as deliberate.

Cost of being wrong: low. Bone names are Godot humanoid, rest pose is a T-pose, so any imported clip set retargets onto the same rig. The procedural clips can be swapped out one by one behind `MHGolferAnimator`.

### 5.5 Clip list (26 clips)

Priority: **P0** needed for the first playable golf loop; **P1** needed before a public alpha; **P2** polish; **P3** later. Duration is the target in seconds (loops marked L). Source: **Proc** = procedural code (primary), **Lib** = CC0/Mixamo retarget candidate (fallback). Built = exists in `MHProceduralSwing` now (NOT YET RUN).

| # | Clip | Priority | Duration (s) | Source | Built | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | idle_stand | P0 | 3.0 L | Proc / Lib | yes | Breathing, small weight shift. |
| 2 | walk | P0 | 1.0 L | Proc / Lib | yes | Walk in place; game moves the node. |
| 3 | walk_fast | P2 | 0.7 L | Lib | no | Hurrying, or bag on shoulder. |
| 4 | address_idle | P0 | 2.0 L | Proc | yes | Stance over ball, tiny sway; hands together. |
| 5 | swing_full_driver | P0 | 2.6 | Proc | yes | Impact at 1.35 s. Slower backswing variant for tempo. |
| 6 | swing_iron | P1 | 2.4 | Proc | no | Steeper, less turn; derive from swing_full. |
| 7 | swing_fairway_wood | P2 | 2.5 | Proc | no | Between driver and iron. |
| 8 | pitch | P1 | 1.8 | Proc | no | Three-quarter swing, short finish. |
| 9 | chip | P0 | 1.6 | Proc | no | Narrow stance, small hinge. |
| 10 | putt | P0 | 1.8 | Proc | yes | Pendulum. Impact at 1.05 s. |
| 11 | putt_long | P2 | 2.2 | Proc | no | Bigger stroke. |
| 12 | bunker_swing | P1 | 2.2 | Proc | no | Open stance, low finish; sand spray is a particle event. |
| 13 | tee_up | P1 | 1.5 | Proc | no | Bend, place tee and ball, stand. |
| 14 | pick_up_ball | P1 | 1.4 | Proc | no | Bend at hole or after a mulligan. |
| 15 | read_green | P2 | 3.0 L | Proc | no | Crouch, hand up to judge slope. |
| 16 | watch_shot | P0 | 2.0 L | Proc | no | Hand shading eyes, head tracking is code. |
| 17 | good_shot_reaction | P1 | 1.5 | Proc / Lib | no | Small fist pump. |
| 18 | bad_shot_reaction | P1 | 1.8 | Proc / Lib | no | Head shake, shoulders drop. |
| 19 | water_splash_reaction | P1 | 1.8 | Proc | no | Flinch, hands to head, slump. |
| 20 | oob_groan | P1 | 2.0 | Proc | no | Head back, arms out, drop. |
| 21 | celebrate | P0 | 2.0 | Proc / Lib | no | Both arms up, hop. |
| 22 | hole_in_one | P1 | 3.0 | Proc / Lib | no | Big jump, spin, arms up; confetti event. |
| 23 | tip_cap | P1 | 1.5 | Proc | no | Right hand to cap brim, nod. Greeting for NPC golfers. |
| 24 | rake_bunker | P1 | 2.0 L | Proc | no | Rake prop on hand bone, sweeping strokes. Staff or golfer. |
| 25 | repair_divot | P2 | 1.8 | Proc | no | Crouch and press. |
| 26 | wave_hello | P3 | 1.6 | Proc / Lib | no | Guest arrival. |

P0 count: 8 clips (idle_stand, walk, address_idle, swing_full_driver, chip, putt, watch_shot, celebrate). Five of the eight are built (idle_stand, walk, address_idle, swing_full_driver, putt); the other three reuse the same helpers.

## 6. For Nathan

Do these in order. If a step does not match what you see on screen, stop and send me a screenshot; do not guess. Total time about 30 minutes. Mixamo's screens may differ slightly from these words, so treat the labels below as approximate.

**Before you start: is the repo private?**
1. Open your Mulligan Hills repository on github.com. Look next to the repository name at the top left. If it says **Public**, stop here and tell me; do not upload Mixamo files to a public repository. If it says **Private**, continue.

**Create the Adobe ID and sign in**
2. Open https://account.adobe.com in your browser and click **Create an account**. (Use a personal email, not a work or school one; Mixamo does not work with Enterprise or Federated IDs.) Choose **Free**, enter your email and a password, and confirm the code Adobe emails you.
3. Open https://www.mixamo.com and click **Sign in** at the top right. Use the Adobe ID from step 2. Accept the terms if asked. Mixamo needs no paid subscription.

**Choose a character**
4. Easiest path (do this first): click the **Characters** tab, pick any default character (for example the plain grey robot), and click **Use this character**.
5. Chunky-golfer path (do this second, optional): download `golfer_placeholder_tpose.obj` from GitHub: in your repository open the folders `game` > `characters` > `mixamo_test` > `upload`, click the file, then click the **download** icon (arrow pointing down, top right of the file view). In Mixamo click **Upload Character**, select that file, and follow the on-screen marker steps: click the spot named on screen (chin, wrists, elbows, knees, groin) and press **Next**. If Mixamo says the model cannot be rigged, take a screenshot of the message and go back to step 4. That message is useful evidence.

**Download 5 test animations**
6. With your character showing, click the **Animations** tab. In the search box type each word below, click the first result that looks right, and watch it play on your character:
   - `idle`
   - `walking`
   - `golf` (write down every golf-related animation name you see; if there are none, write "none found". This matters most.)
   - `victory` (or `cheering` if `victory` finds nothing)
   - `disappointed` (or `defeated` or `sad`)
7. For each animation, click **Download**. In the box that opens choose: **Format:** `FBX for Unity (.fbx)`; **Skin:** `With Skin`; **Frames per second:** `30`; **Keyframe Reduction:** `none`. Click **Download**. Your browser saves the file, usually in your Downloads folder.
8. Rename the five files so they are easy to tell apart: `test1_idle.fbx`, `test2_walking.fbx`, `test3_golf.fbx` (use the best golf swing, or your best guess if none), `test4_victory.fbx`, `test5_disappointed.fbx`. (Right-click each file, choose Rename.)

**Put the files in the repository, using the browser only**
9. In your repository on github.com, click the `game` folder, then `characters`, then `mixamo_test`.
10. Click **Add file** (top right, green or grey button), then **Upload files**.
11. Open your Downloads folder in a separate window, select the five renamed `.fbx` files, and drag them onto the box that says "Drag files here". Wait for all five to show as uploaded. (GitHub's browser upload limit is about 25 MB per file. Mixamo files are usually well under that. If GitHub refuses one, tell me its size.)
12. Scroll down to **Commit changes**. In the message box type `Add Mixamo test animations`. Choose **Commit directly to the main branch** if offered, otherwise **Create a new branch** and accept the suggested name. Click **Commit changes**.
13. Send me: the list of golf animation names from step 6 (or "none found"), and whether step 5 worked or failed. Do not send anything else.

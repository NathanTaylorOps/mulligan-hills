# Phase 1: procedural building art

Status: historical implementation note from 4 Oct 2026. Procedural building source and tests exist; current-head execution/visual evidence belongs in `docs/VERIFICATION.md`. The original Python geometry mirror checked counts, bounds, determinism and winding but was not a substitute for Godot/device acceptance.

## 1. What was built
- `game/art/buildings/mh_building_meshes.gd` `MHBuildingMeshes`: `build(id, tier, spec)`, `build_builder`, `tri_count`, `bounds`, `geometry_hash`, `budget(tier)`. 10 buildings x 5 tiers x spec a/b (spec only from tier 3).
- `mh_building_parts.gd` `MHBuildingParts` (walls, slab, gable, hip, shed, windows, door, column, fence, awning, umbrella, table, cart, wing...), `mh_buildings_golf.gd` (clubhouse, pro shop, driving range, restaurant, pool and spa), `mh_buildings_site.gd` (cart barn, maintenance, lodging, homes, landmark), `mh_building_theme.gd` `MHBuildingTheme` (colours per building and spec, built on `MHPalette`).
- `game/art/mh_building_gallery.tscn` + `.gd` `MHBuildingGallery`: five tiers in a row, prev/next, spec a/b, rotate, triangle counts.
- Tests `game/tests/art/`: `test_building_meshes.gd`, `test_building_theme.gd`, `test_building_gallery.gd`.
- Reused unchanged: `game/art/shared/` (`MHMeshBuilder`, `MHPalette`, `MHArtMaterials`, `MHArtRng`, `MHSkySetup`).

## 2. Numbers (from the Python run)
Triangles tier 1 to 5 (spec a): clubhouse 64/114/254/442/672, pro shop 72/140/230/314/498, driving range 50/122/218/330/512, restaurant 86/178/312/446/682, pool and spa 60/138/218/306/474, cart barn 76/214/332/518/782, maintenance 60/138/234/424/700, lodging 84/156/296/466/750, homes 104/168/288/430/618, landmark 96/198/264/414/642. Max tier 5 is 782, limit 3000. One of every tier-5 building: 6330. Hard per-tier ceilings: 300/600/1000/1500/2200. Spec a and b have equal counts. One surface, one material, no transparency, vertex colours only.
Largest footprint at tier 5 about 28 x 34 m (landmark); units are metres, origin on the ground at the middle of the main block, door side +Z.

## 3. Unverified
- Static functions and constants inherited from `MHBuildingParts` are called without a prefix in `MHBuildingsGolf` and `MHBuildingsSite` (both `extends MHBuildingParts`). If 4.7 rejects this, prefix calls with `MHBuildingParts.`.
- `Basis(Vector3.UP, yaw)`, `Transform3D(Basis, Vector3)`, `Node3D.look_at_from_position`, `Camera3D.make_current`, `Array.has`, ternary expressions, typed `for x: Type in` loops.
- Gallery and its test under the headless dummy renderer.

## 4. Risks and manual review notes
- Spec a/b meaning is a guess (colour scheme and which side the extra wing goes). `strings` has no spec names yet.
- Footprints are art-scale guesses; parcel size is not set (DEC-056). Scale in the placement code if parcels turn out smaller.
- Add the gallery to `MHLauncher.SCENES` (`["Building gallery", "res://art/mh_building_gallery.tscn"]`); not done here because `game/ui/` is not mine.

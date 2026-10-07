# Mulligan Hills visual target

The approved direction is **rich around the course, clean on the course**.

The concept renders are art-direction targets, not geometry budgets. Mulligan Hills should
deliver their perceived richness through strong composition, silhouettes, lighting, surface
separation and reusable clusters rather than literal object density.

## Runtime rules

- Gameplay, save data, terrain relief, ratings and simulation never depend on graphics tier.
- Low-end phones must see the same playable course and receive the same simulation.
- Prefer batched terrain meshes, instancing and reusable prop clusters over per-tile nodes.
- Keep greens, fringe, fairway, rough, bunkers, water and paths immediately distinguishable.
- Concentrate decorative density around clubhouses, water edges, gardens and forest margins.
- Keep playable golf surfaces comparatively quiet so golfers, balls, carts and events read.
- Use a high/isometric camera to avoid detail that is invisible at normal gameplay distance.

## Quality tiers

**Low** — mowing cue retained; simple trees; reduced hazard response; no decorative edge
accents or terrain shadows.

**Medium** — default mobile target; mowing, useful surface accents, two-layer trees, richer
water and shadows.

**High** — default desktop target and capable-phone goal; three-layer vegetation silhouettes,
full course accents and richer environment density.

**Ultra** — future flagship/desktop tier. Same simulation, highest decorative density.

Automatic selection is deliberately conservative until device profiling exists. Do not infer
device power from model names in gameplay code.

## Asset budgets

Hero buildings should use medium-detail meshes and baked/material detail. Trees and shrubs
should be instanced variants. Flowers, reeds and garden beds should be cluster assets. Rocks
should come from a small rotated/scaled library. Water should remain one inexpensive surface
treatment with optional presentation layers. Mowing variation should be material/batched
geometry, never thousands of independent blades or decals.

Any future visual feature must have a graceful lower-tier representation before it becomes
part of the core art direction.

# Mobile performance validation

Performance decisions should be driven by measured target-hardware behavior.

## Measure representative states

At minimum profile:

- empty/new course;
- dense edited hole;
- sculpting/painting drag;
- multi-hole course view;
- golfer/activity-heavy course;
- building/vegetation-heavy club;
- long sustained session.

## Capture

Where tooling permits, record:

- frame time / FPS distribution;
- CPU/main-thread cost;
- render cost/draw calls;
- memory and allocations;
- node/instance counts;
- redraw/update cost;
- sustained thermal behavior.

## Editor-specific focus

The editor should be profiled while continuously sculpting/painting, not only while the camera is idle.

If whole-world rebuilds are materially expensive, prefer dirty-region/chunk updates and cached immutable resources. Do not introduce complexity before profiling proves the need.

## Quality tiers

Gameplay and course state must be identical across visual tiers. Quality tiers may change density, shadows, decoration and visual effects, but not authoritative simulation.

## Acceptance

A performance claim belongs to the exact device, quality tier and commit measured. Emulator results are useful for compatibility, not thermal/performance acceptance.

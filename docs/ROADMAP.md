# Mulligan Hills roadmap

This roadmap uses Now / Next / Later rather than unsupported delivery dates.

## Now — verified stabilization

- Restore GitHub Actions runner execution and diagnostics.
- Run Godot import and the full automated suite on an exact SHA.
- Run the live UI smoke probe on that SHA.
- Complete the three-hole active-context regression path.
- Complete customer/staff/economy save round-trip coverage.
- Add one end-to-end EDIT -> BUILD -> PLAY -> progression -> SAVE -> RELOAD regression.
- Keep broad feature work frozen until the gate passes.

## Next — multi-hole course foundation

- implement real per-hole world placement;
- define stable slot identity/index rules;
- ensure terrain, aiming, camera, scoring and persistence use the same active-hole context;
- begin behavior-preserving decomposition of the editor/practice panel;
- profile editor redraw/input cost on Android hardware;
- introduce dirty/chunked rendering only where profiling supports it.

## Then — integrated club game

- customer progression and recurring golfer behavior;
- staff, condition and maintenance feedback;
- economy/building/tournament integration;
- personal golfer progression and shot-style play;
- living-club events and visible rewards;
- explainable management effects in the UI.

## Platform and service readiness

- validate Android export/toolchain versions end to end;
- compile and exercise Play Integrity integration on a real device;
- validate billing restore/purchase lifecycles;
- deploy a staging Supabase project;
- test cloud-save conflicts, account deletion, entitlement and offline/reconnect behavior;
- establish iOS implementation only against verified current APIs.

## Later / post-launch

- player-shared hole codes / broader UGC;
- simultaneous multiplayer;
- additional courses/biomes and scenario expansions;
- other features explicitly classified as post-launch in DECISIONS.md.

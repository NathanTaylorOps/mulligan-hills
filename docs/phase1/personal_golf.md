# Personal golfer reference status

5 October 2026. First envelope reference implemented in `tools/reference/personal_golf/`: strict versioned seven-attribute profiles, independent carry/lateral/depth controls, bad-lie Recovery, capped safe recovery, putting Touch and bounded competitive Composure. Luck and Shaping are stored but have no fake envelope effects. Coefficients are provisional in `docs/spec/personal_golf_model.md`.

Ten Python tests PASS, including exhaustive monotonicity across all 1001 values for Power, Accuracy, Touch, Recovery lie spread/carry and Composure; independent profile copies and malformed input rejection; repeatable pure preview, explicit numeric vector and minimum-distance boundary. Main CI invokes this reference test before downloading Godot. No external Python packages needed. No Godot APIs introduced.

This is NOT a full shot/round simulator or runtime progression: no RNG, landing/trajectory, hazards, cup capture, penalties, XP, stakes, avatar or encounter implementation. Official rating/sim definitions and their goldens unchanged. Reference carry/dispersion numbers are not calibrated for course scale or the 50-hour campaign. Recovery reduces proportional lie spread; greater reachable distance can increase absolute error for overreaching shots. The 800cy short-shot transition is provisional and needs a smooth boundary before final shot tuning.

Next: separate versioned personal-shot outcomes against existing validated geometry, deterministic random draws and fixed golden vectors; typed GDScript parity; saved profiles and capped training settlement. Luck needs a separate eligible encounter/outcome model with cooldowns and persistent event IDs. Independent review recorded in `personal_golf_verification.md`; CI/device evidence still required for game behavior.

## Shot outcome reference increment

Python `shot.py` now implements automatic clubs, independent PCG32 per-shot/axis streams, integer landing offsets, official primitive geometry/tree interception, a separately versioned stroke-and-distance water/OB reset and sampled putt path/cup capture. `test_shot.py` covers fourteen test methods and twelve checked-in numeric golden cases. All local reference tests PASS; independent review in `personal_shot_verification.md`. Main CI now runs both suites; fresh remote results pending.

Still reference-only: no GDScript port/runtime UI/saves/rewards, wind/rain/roll/mishit, curved paths, Luck breaks or avatar. Inputs are immutable values but production saved snapshots and committed stroke IDs still need integration. Simplified putting capture and tree-height policy require playtests; goldens establish reproducibility, not game feel. The prior envelope-only limitations above describe that component; this increment adds outcomes in a separate module.

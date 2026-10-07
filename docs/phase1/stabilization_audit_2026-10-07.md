# Stabilization Audit Register

Baseline review: 105-item external engineering review supplied 2026-10-07.
Current branch: `fix/canonical-relief-save`.

Status meanings: **FIXED** verified in source and corrected; **CONFIRMED** real but not yet resolved; **PARTIAL** some required work exists; **DEFER** valid but not a current vertical-spine blocker; **VERIFY** not yet proven against current HEAD.

## P0/P1 current-head findings

| Review | Status | Current-head result |
| --- | --- | --- |
| 1 active terrain uses Hole 1 | FIXED | `_ground_height()` and screen aiming now use one authoritative active-play layout. |
| 2 UI hard-codes HOLE 1 | FIXED | Editor/practice title derives current authored/play hole. |
| 3 score display uses scores[0] | FIXED | Score resolves from active slot/index. |
| 4 multi-hole state scattered | PARTIAL | Added centralized active-play index/layout/score helpers. Larger panel decomposition remains later work. |
| 5 membership rule/test disagree | FIXED | Test now proves 3 qualifying visits establish regular, then 2 additional good visits establish eligibility. |
| 6 CI cannot prove health | CONFIRMED BLOCKER | Current push workflows fail before any job step is recorded; no job logs/artifacts are produced. This predates the read-only workflow change. Repository/account Actions startup must be diagnosed. |
| 7 current HEAD unverified | CONFIRMED BLOCKER | Broad feature work is frozen for stabilization. |
| 8 historical PASS risk | CONFIRMED POLICY | No old PASS is treated as current-head evidence. |
| 23 first satisfaction not clamped | FIXED | Incoming visit score is clamped once before all calculations. |
| 24 customer restore invariants weak | FIXED/PARTIAL | Restore now rejects member/eligible/streak states impossible under current rules. Extend if the domain gains more states. |
| 25 independent customer booleans drift | PARTIAL | Strict restore invariants added. Counters/booleans remain explicit for now. |
| 26 completeness omitted from explanation | FIXED | Completeness participates in best/worst reaction explanation. |
| 27 explanations can omit weighted factors | FIXED for current factors | All currently weighted components participate. |
| 29 ambience can trigger progression | FIXED | Opening visual golfers explicitly cannot mutate customer progression. |
| 51 CI jobs have contents:write | FIXED | Core CI, determinism and Android workflows now use contents:read. |
| 52 tests push ci-results | FIXED for core workflows | Core CI/determinism/Android publish artifacts instead of pushing result commits. Screenshots workflow still needs the same cleanup. |
| 54 Godot hard pins empty | CONFIRMED | Populate only after a trusted known-good run; current downloader still checks upstream SHA512 sums. |
| 56 Android toolchain unverified | CONFIRMED | versions.env explicitly marks it unverified. Requires successful real export before freezing. |
| 64 one→many assumption audit | ACTIVE | Hole-1 source assumptions found and corrected in practice panel; repo-wide multi-hole tests still required. |
| 65 no regression guard for Hole 1 | CONFIRMED | Next test slice should deliberately differentiate all 3 holes. |
| 66 slot_id vs index | PARTIAL | Active score/practice restore resolves slot where available; formal identity contract still needed. |
| 67 practice slot/index drift | FIXED/PARTIAL | Active index re-resolves from practice slot; add explicit regression test. |
| 68 fixed origin | CONFIRMED | Still uses one `ORIGIN`. |
| 69 shared terrain window | CONFIRMED | Real multi-hole world placement remains the first post-stabilization feature. |
| 90 integration coverage lag | CONFIRMED | Stabilization sprint is addressing it. |
| 91 ownership integration tests | PARTIAL | Staff/customer/session tests exist; full EDIT→BUILD→PLAY→SAVE→RELOAD test remains. |
| 92 save/schema atomicity | PARTIAL | Customer save path now includes schema/validator/serializer/restore/tests; process rule should be retained. |
| 93 reader-version logic scattered | CONFIRMED | Reader 6 works but capability calculation should later be centralized. |
| 97 MHGameSession growth | WATCH | Keep orchestration only; do not move domain calculations into it. |
| 100 condition satisfaction invisible | PARTIAL | Mechanical connection exists; player-facing explanation needs condition as explicit component. |
| 102 final integration-quality gate | CONFIRMED | This is the stabilization target. |
| 103 stabilization before more systems | ACTIVE | Adopted. |
| 104 rate of change is limiting quality | ACTIVE | Feature scope frozen until a verified checkpoint. |
| 105 velocity vs maturity | ACTIVE | Success metric changed to verified integrated capabilities. |

## Current gate

Do not resume broad feature development until:

1. GitHub Actions jobs actually start and produce diagnostics.
2. Godot import and unit tests pass on an exact SHA.
3. Live UI smoke probe passes on that SHA.
4. Multi-hole regression proves Holes 1/2/3 use their own relief, score, pin and active context.
5. Customer/staff/economy save round-trip passes.
6. One cross-system EDIT → BUILD → PLAY → customer progression → SAVE → RELOAD test passes.

After this gate, implement real per-hole world placement before expanding RPG/content scope.

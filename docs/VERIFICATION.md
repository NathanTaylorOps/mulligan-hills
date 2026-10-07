# Mulligan Hills verification

Verification claims are tied to evidence, not intent.

## Evidence levels

| Level | Meaning |
| --- | --- |
| Static | Source/schema/parser review only |
| Automated runtime | Godot/import/tests ran successfully on an exact SHA |
| Graphical | A graphical build was exercised and presentation/input checked |
| Device | Physical target hardware validated performance/touch/platform behavior |
| Staging | Real external service/store sandbox path validated |
| Release | Release candidate passed all required gates |

A higher level does not automatically apply to later commits.

## Current status

Current source contains substantial regression coverage and recent stabilization fixes, but GitHub Actions runner allocation is preventing a current-head runtime proof. Historical Windows live-probe evidence exists for earlier commits only. Android performance, touch and thermal acceptance for current HEAD is not established, and Supabase/store paths still require real staging/device evidence.

Therefore the current branch is source-stabilized but runtime-unverified until Actions/device gates run.

## Required stabilization evidence

1. Actions job is allocated a runner and produces step-level logs.
2. Godot project import succeeds.
3. Automated tests pass.
4. Live UI probe passes.
5. Three distinct holes prove active relief, score, pin and context selection.
6. Customer/staff/economy save round-trip passes.
7. One cross-system EDIT -> BUILD -> PLAY -> progression -> SAVE -> RELOAD path passes.

Historical reports are traceability records, not current-head certification.

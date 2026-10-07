# Development guide

Current development branch: `fix/canonical-relief-save`. Default branch: `main`.

## Working on the existing game

1. Inspect the current branch, recent commits, relevant implementation and tests. Another session may have advanced HEAD.
2. Reuse the canonical course/relief/save chain and existing UI/input owners. Fetch known paths or inspect directories when private-repository code search misses files.
3. Make focused changes, review the diff, and commit related code with its regression coverage. Preserve other contributors' changes.
4. Separate observed test results from tests that were only written or statically parsed. Do not move a historical PASS forward to a new commit.
5. Use ordinary fast-forward commits on the development branch. Coordinate any future squash at merge time; do not force-push or rebase published work during cleanup.

## Windows verification batch

When ready to test the accumulated editor work, run this batch from the existing checkout on `fix/canonical-relief-save`:

```powershell
cd "$HOME\Documents\GitHub\mulligan-hills"
git branch --show-current
git pull --ff-only
godot --headless --path ".\game" --editor --quit
godot --headless --path ".\game" --script res://tests/manual_verify_live_ui.gd
```

Stop if the branch is wrong, the pull fails, or Godot reports import/parse errors. Return the complete output and the commit SHA (`git rev-parse --short HEAD`). The live probe uses isolated saves under `user://manual_verify_live_ui/`; it does not alter the ordinary live slot and does not require gdUnit4.

The probe covers normal terrain editing, the focused dock, category selection and cancellation, brush footprints and precision, marker preview/history, draft pin disk persistence, owned-land warnings, marker repair, authoritative Build, practice, and actual checkpoint reload.

After headless validation, launch with `godot --path ".\game"` and choose **Course design & practice**. Headless success cannot establish visual polish, readable text, gesture comfort, camera framing, thermal behavior or sustained phone performance.

## Controls in course design

| Action | Touch | Desktop |
| --- | --- | --- |
| Paint / sculpt | One-finger stroke | Left drag |
| Camera | Two-finger gesture; cancels unfinished stroke | Right drag rotates, middle drag pans, wheel zooms |
| Tee / pin | Tap or drag a preview, then Confirm | Click or drag a preview, then Confirm |
| Cancel placement | Cancel, change tool, or close | Cancel or Escape |
| Undo / redo | Dock buttons | Dock buttons; Ctrl/Cmd+Z, Ctrl/Cmd+Shift+Z or Ctrl/Cmd+Y |
| Reduce / close tools | `−` / `+`, then `×` | Same controls; Escape cancels an edit, closes details, collapses, then closes |
| Practice | Tap a target, then Play shot | Click a target, then Play shot |

Level samples exact elevation at the start of a stroke. Switching tools or losing focus rolls back an unfinished stroke. A marker preview is transient and never written to the draft until confirmed. Undo history is session-local; saved geometry survives reload, undo stacks do not.

## Automated checks

CI pins Godot/gdUnit4 in `tools/ci/versions.env`, imports the project, runs gdUnit4 through `tools/ci/run_tests.sh`, then the isolated course probe through `tools/ci/verify_live_ui.sh`, and publishes logs/artifacts. The probe wrapper requires its explicit PASS marker and rejects script errors; an empty successful process is not accepted as a test pass. Reference checks live under `tools/reference`; schema fixtures and their validator live under `docs/spec/data`.

`gdparse` is useful for syntax review but does not run Godot's type analyser, load scenes or validate engine behavior. The editor batch was parsed with gdtoolkit; its new engine regressions are awaiting execution. The inspected CI run for `2af3b50` reported failure without available step logs, so it supplies no successful test evidence.

For the saved-course path, prioritize `manual_verify_live_ui.gd` and the craft, one-hole, terrain-bridge, session-save, input and layout tests. Do not replace behavioral checks with snapshots of implementation details.

## Repository hygiene

- Keep source and reproducible assets in the repo; keep `.godot`, installed test addons, exports, reports, logs, credentials and editor caches out. See `.gitignore`.
- Version generated source/data only when it is an intentional build input. Do not delete assets, fixtures or historical scenes solely because they look old.
- Mark superseded development notes clearly and link current architecture. Preserve dated test evidence as historical evidence.
- Keep presentation demos separate from the player-built course path. New hole/gameplay work belongs on the canonical path.
- Preserve deterministic integer simulation, exact relief, ownership validation, save compatibility and batched terrain meshes.
- Update the README when entry points, setup, major controls or supported capabilities change. Keep detailed design choices in `docs/DECISIONS.md` and implementation notes.

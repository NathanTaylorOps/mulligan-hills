# Mulligan Hills technical debt

This register contains structural work that is known, bounded and not being hidden inside feature notes.

## Current high-priority debt

| Area | Debt | Why it matters | Planned handling |
| --- | --- | --- | --- |
| Verification | Hosted CI jobs are not currently receiving a runner | Current HEAD cannot be proven green | Resolve before broad feature work |
| Multi-hole world | Hole authoring still has legacy development-origin assumptions | Limits real course layout | First major feature after stabilization |
| Editor architecture | Editor/practice panel owns too many responsibilities | Raises regression and maintenance risk | Extract controllers/renderers incrementally |
| Rendering | Editor redraw may rebuild more world state than necessary | Mobile frame/thermal risk | Profile first; chunk/dirty-update if justified |
| Hole identity | Slot identity and list index are not fully formalized everywhere | One-to-many regressions | Establish explicit identity contract |
| Integration coverage | Full player path is not yet one automated integration test | Unit-green can miss ownership mismatch | Add EDIT→BUILD→PLAY→progression→SAVE→RELOAD |
| Platform async | Native purchase/integrity flows require complete timeout/lifecycle proof | Potential stuck UI/restore failures | Harden adapters and device-test |
| Backend | Local/fake validation exceeds real staging validation | Deployment assumptions remain | Stage Supabase and store sandbox paths |
| Mobile evidence | Current editor has not established sustained target-device budgets | Visual scope could outrun hardware | Physical-device profile and soak |
| Player explanation | Some management modifiers are mechanically present before being clearly explained | Hidden systems reduce trust | Add explicit cause/effect UI feedback |

## Debt rule

Technical debt is acceptable when it is explicit, has an owner/boundary and does not silently become a second architecture.

Do not use this file for ordinary feature ideas. Product scope belongs in DECISIONS.md/ROADMAP.md; current blockers belong in STATUS.md.

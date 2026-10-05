# Tap-to-aim independent verification

Date: 2026-10-05. Separate DEC-041 static review of `MHAimTap`, `MHPracticeAimInput`, panel/scene integration and `MHPracticeRound.aim_preview`. No implementation edits or Godot execution.

## Disposition

No concrete blocker identified in the inspected increment. Godot analyser, event dispatch, rendering, CI regressions and phone evidence remain pending; completion/merge certification is withheld.

## Inspected behavior

- A world press/release selects aim only. Shot commitment remains an explicit Play shot action. Contacts beginning on visible UI remain unconsumed and cannot become a world aim by moving off the UI.
- All active contacts, including UI contacts, contribute to multi-contact suppression. Once multiple contacts overlap, neither remaining release can aim until all contacts end. Drag slop, cancelled releases, inactive view/modal and focus/pause clearing reject aims.
- The aim node is the last scene sibling. The intended reverse-depth input ordering lets it observe UI contacts before the touch bridge handles them. Official order verification was supplied by the lead; this review inspected the tree placement and existing bridge behavior but did not execute event dispatch.
- Ray/flat-plane selection rejects parallel, behind-camera and off-patch intersections. Float coordinates are rounded at the input boundary into integer centiyards using the same exact world origin/conversion. Existing camera property and scene APIs match inspected call sites.
- Preview reads the round without advancing RNG, shots, money or progression. Its club/carry/lateral spread scale matches the corresponding integer flight calculations. The ring is explicitly a rough spread estimate, not a probability or promised landing; it does not model mishit, depth distribution or every penalty outcome.
- Draft rendering does not permit a shot against the prior committed hole. Restart restores the committed design and clears draft preview. Path construction uses rendering floats only; no official rating formulas or goldens changed.

## Evidence and remaining scope

This is static source inspection only. Final tests and `aiming.md` were independently inspected: pure ownership tests cover world/UI start, drag-return, cancelled/blocked release, mixed contacts, clear and hybrid pointers; preview tests check unchanged round state/next shot, carry limits and nominal water feedback. The added real-scene test projects a known world point into a 50-yard target and compares cash/round state, then tests focus clearing. All remain **NOT YET RUN** in Godot. They call the pure state machine and projection boundary directly; they do not establish actual viewport input dispatch or UI bridge ordering. Raw touch ordering, UI/world multitouch, cancellation/focus transitions, projection accuracy, scene layout, performance and visible path/spread require Godot/device evidence.

Final changes checked: opening practice explicitly clears aim contacts; restart exits draft preview and restores fields from committed geometry; feedback labels wrap to the initial viewport width. No new concrete blocker identified. Viewport resize/responsive layout remains a device check. `aiming.md` accurately distinguishes implemented prototype behavior, pending engine checks and remaining shot-style/career work. Parser/schema PASS listed there is lead-provided evidence; this review adds no new engine/runtime PASS.

This increment supplies target selection and automatic prototype flight, not completed shot styles, golfer skills/career, rewards, avatar movement, camera follow or production phone authoring. DEC-076 control direction does not certify those features complete. No engine PASS is claimed.

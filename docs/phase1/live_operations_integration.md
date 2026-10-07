# Live Operations Integration

## Authority map

Mulligan Hills now has one live business path:

1. `MHEconomy.tick_hour()` is the sole authority for accepted golfers and revenue.
2. `MHGameSession` publishes the booked whole-golfer count and assigns persistent customer IDs from the 128-person roster.
3. `MHSliceSchedule` only groups those booked golfers into tee slots. It does not recompute demand or acceptance.
4. `MHSliceGolfers` is presentation only. It moves a group through its ordered hole route and reports completion.
5. Completion returns to `MHGameSession.record_customer_visit()`, where satisfaction and relationship progression are applied.
6. `MHStaff` is session-owned. Payroll is charged hourly; grounds/incident state advances daily; condition affects demand and visit satisfaction.
7. Aggregate `MHEconomy.members_milli` remains the calibrated membership-capacity/business model. `MHGolferCustomers` determines which persistent golfers are regular, eligible, and named members. Named members cannot exceed aggregate capacity.

Opening golfers in the vertical slice are explicitly ambience only. They never alter customer progression.

Authoritative booked groups are lossless in the tee queue. Rendering may hide distant golfers, but a booked group is never discarded because a visual queue is busy.

## Current three-hole capability

`MHCraftCourse` owns three editable draft holes in the current development slice. The one-hole panel can switch between them. Finalization converts and validates every hole, submits the full course to `MHGameSession`, and personal practice advances through the finalized course in order.

`MHSliceGolfers` independently supports ordered multi-hole customer routes and emits one completion row after the full route.

## Remaining spatial integration seam

The three craft holes currently reuse one development terrain window and one course-layout origin. That is valid for editing/rating/practice but is not a physical three-hole world layout. Spawning three simultaneous customer routes from those origins would stack the holes and would be misleading.

The next integration milestone is therefore **multi-hole world placement**:

- give every craft hole a persistent world origin/footprint;
- validate that footprints remain inside owned land and do not overlap;
- bridge each craft grid to its own world-terrain region;
- encode those real origins in `MHCourseLayout`;
- render finalized authored holes at those origins;
- feed those same world tee/green positions to the live customer route;
- preserve origins and all three drafts through save/load;
- keep rating/simulation geometry unchanged by presentation LOD.

Only after that seam is complete should the construction scene advertise an **Open Course** action that launches visible customer play on the authored course.

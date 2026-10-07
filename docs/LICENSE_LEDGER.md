# Asset and dependency provenance

This file is the current provenance policy for material that may ship with Mulligan Hills.

## Rule

Nothing is approved for release merely because it was downloaded, researched or mentioned in an old design document.

Every third-party asset, library, dataset, font, audio file or code dependency that ships must have:

- source;
- exact licence/version;
- commercial-use status;
- attribution requirement;
- evidence/date checked;
- repository location;
- release approval status.

## Current categories

| Category | Current treatment |
| --- | --- |
| Project-authored procedural/game code | Project-owned source; normal repository history applies |
| Generated placeholder art from project scripts | Development asset unless explicitly promoted to release asset |
| Godot Engine | Engine licence/notice must be included as required by the exact shipped version |
| gdUnit4 | Development/test dependency; retain its licence as required |
| Candidate third-party character/animation assets | Not release-approved until exact source/licence evidence is rechecked |
| External reference images/competitor media | Research reference only; never copied into shipping assets unless separately licensed |

## Release check

Before a release candidate:

1. enumerate every non-project asset/dependency actually included in the build;
2. verify its licence from the primary source;
3. capture required notices/attribution;
4. remove anything with unclear provenance;
5. store the final notice set with release evidence.

Historical discovery notes are not a release-clearance opinion.

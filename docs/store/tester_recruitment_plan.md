# Closed-test operations

This document describes how to run a useful closed test without tying the repository to personal contacts or a store rule that may later change.

## Before recruiting

1. Verify the current Google Play closed-testing requirements for the actual developer account.
2. Confirm the release-candidate privacy/data behavior.
3. Confirm the test build installs, launches, saves and restores on at least one internal device.
4. Publish the required privacy/support URLs.
5. Define what the test is intended to learn.

## Tester mix

Recruit more testers than the minimum required by the store so attrition does not invalidate the test.

Aim for a mix of:

- golf players;
- management/tycoon players;
- mobile players on lower-end Android hardware;
- players unfamiliar with the project;
- a small number of technically experienced testers who can provide reproducible bug reports.

Participant contact details and recruitment lists should be kept outside the public-facing source repository.

## What to ask testers to do

Keep the requested session simple:

- install from the official test track;
- reach the course editor;
- build and play a hole;
- save, close and reopen;
- use the most important management/progression flows available in that build;
- report crashes, blockers and confusing interactions;
- optionally provide device model and OS for performance issues.

## Evidence to capture

For each test build record:

- exact commit/build;
- number of active testers;
- device coverage;
- crash/ANR summary;
- top usability blockers;
- save/restore failures;
- performance complaints;
- conversion/unlock observations when applicable;
- actions taken before the next build.

## Privacy and incentives

Tell testers what data the test build collects and why. Do not use undisclosed tracking. Verify current store rules before using paid, incentivised or reciprocal testing services.

## Exit criteria

A closed-test cycle is useful when the required store threshold is satisfied **and** the product team has enough evidence to make a release/no-release decision. Meeting the store's minimum alone is not a product-quality gate.

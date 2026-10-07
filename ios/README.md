# iOS platform integration

Status: **design/provisional integration only.** Android remains the first mobile validation target.

This directory records the intended iOS platform boundary so common gameplay systems do not acquire Android-only assumptions.

## Intended responsibilities

- App Store purchase and restore adapter;
- account/sign-in compatibility where required;
- entitlement verification through the common server contract;
- local notifications where used;
- TestFlight build/export path.

## Current rule

Do not promote remembered API names, store-policy assumptions or plugin signatures into production code without verifying them against the exact Godot/iOS plugin and current Apple documentation.

The common gameplay layer should depend on platform-service interfaces, not StoreKit-specific objects.

## Before implementation is accepted

1. Pin the exact iOS plugin/toolchain versions.
2. Verify purchase/restore APIs and transaction lifecycle.
3. Implement the server-side Apple entitlement verification path.
4. Build from a clean CI/macOS environment.
5. Upload a signed archive to TestFlight.
6. Exercise purchase, restore, offline entitlement and account deletion behavior.
7. Reconcile App Store privacy/age-rating/export-compliance answers with the shipping build.

Current platform evidence belongs in **docs/VERIFICATION.md**.

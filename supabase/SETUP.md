# Supabase staging setup

This guide is for creating a staging backend that can validate the existing Supabase code against real services.

## Before starting

Have:

- a Supabase staging project;
- the project URL and client key intended for the game;
- secure access to Edge Function secrets;
- Google Play service-account credentials only when testing purchase verification;
- a non-production test account/store path.

Never commit service-role keys, signing private keys or store credentials.

## Recommended order

1. Create the staging project.
2. Apply migrations in order.
3. Run the SQL test suite locally where practical.
4. Deploy Edge Functions.
5. Configure required secrets.
6. Exercise remote config.
7. Exercise anonymous auth/account flow.
8. Exercise cloud-save upload, download and conflict handling.
9. Exercise account deletion/transfer paths.
10. Exercise analytics consent behavior.
11. Only then connect purchase/integrity sandbox credentials.
12. Record exact results in docs/VERIFICATION.md or a release/staging evidence record.

## Local checks

Backend logic tests and SQL tests are useful preflight checks, but they do not replace deployment validation.

## Client integration

Gameplay should consume backend capability through platform/service adapters rather than direct HTTP calls scattered through game systems.

Failure cases to test explicitly:

- no network;
- timeout;
- expired or invalid token;
- stale cloud version;
- interrupted upload;
- account deletion during pending state;
- service kill switch;
- reconnect after offline play.

See README.md in this directory for backend architecture and known gaps.

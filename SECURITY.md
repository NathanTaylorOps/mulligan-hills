# Security Policy

Mulligan Hills is a pre-release game project with platform, backend, purchase and account-related integration work.

## Reporting a vulnerability

Do **not** publish exploitable security issues, credentials, private keys, purchase-verification bypasses or backend vulnerabilities in a public issue.

For the current private-development phase, report security concerns directly to the repository owner through the existing private project communication channel. Include:

- affected component;
- reproduction steps;
- potential impact;
- relevant logs or screenshots with secrets removed;
- suggested mitigation, if known.

Do not include live credentials or personal data in the report.

## Sensitive areas

Changes involving the following require additional review:

- Supabase authentication, authorization and Row Level Security;
- Edge Functions and server-side verification;
- Play Integrity;
- Google Play Billing;
- App Store / StoreKit purchase verification;
- signing keys and build credentials;
- account deletion and privacy flows;
- leaderboard or anti-cheat trust boundaries;
- save/cloud synchronization.

## Secrets

Never commit:

- Supabase service-role keys;
- database passwords;
- Android keystores or passwords;
- Apple certificates/private keys;
- App Store Connect private keys;
- Google service-account private keys;
- production tokens or API secrets.

Use GitHub Secrets, platform secret stores or local environment configuration.

If a credential enters Git history, assume it is compromised and rotate/revoke it.

## Supported versions

There is currently no public production release. Security fixes apply to the active development branch unless a release-support policy is established later.

# supabase/functions : purchase and integrity verification

Status: SOURCE ONLY. Nothing here has been deployed or called against Google. The pure logic (integrity policy,
purchase-response interpretation, token signing) was run under Node with `_shared/selftest.node.ts`; the TypeScript-signed
token was verified by Python `cryptography`. Network calls to Google were NOT run.

## Functions
| Function | Purpose |
| --- | --- |
| `verify-purchase` | Decode Play Integrity token (optional/policy), verify the purchase token with the Google Play Developer API, acknowledge it, return a signed entitlement `mh1...`. No Supabase login needed. |
| `verify-integrity` | Standalone integrity check (for leaderboard/cloud-save abuse). Returns verdict summary and a 10-minute signed `mhi1` attestation. |

Shared code: `_shared/` (crypto, google_auth, play_purchases, integrity, entitlement). Token format is documented in
`game/platform/mh_entitlement_token.gd` and `_shared/entitlement.ts`; they must stay byte compatible.

## Secrets (Supabase > Edge Functions > Secrets, or `supabase secrets set`)
| Name | Value |
| --- | --- |
| `ANDROID_PACKAGE_NAME` | e.g. `com.mulliganhills.game` |
| `ALLOWED_PRODUCT_IDS` | `mh_full_unlock` |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | the whole JSON key file of the service account (one secret) |
| `ENTITLEMENT_SIGNING_KEY_PEM` | RSA-2048 PKCS#8 PRIVATE key PEM. Public half goes into `MHPlatformConfig.ENTITLEMENT_PUBLIC_KEY_PEM` |
| `INTEGRITY_MODE` | `off`, `log` (default: failures are logged, purchase still honoured), or `enforce` |
| `INTEGRITY_REQUIRE_LICENSED` | `false` (default) or `true` (rejects sideloaded installs) |
| `INTEGRITY_ALLOW_BASIC` | `false` (default) or `true` (accept MEETS_BASIC_INTEGRITY) |
| `ACKNOWLEDGE_ON_SERVER` | `true` (default) |

## Service account setup (summary; numbered steps for Nathan are in docs/phase0/platform.md)
1. One Google Cloud project, the same one linked under Play Console > App integrity.
2. Enable APIs: "Google Play Android Developer API" and "Play Integrity API".
3. Create a service account (no project roles needed), create a JSON key.
4. Play Console > Users and permissions > Invite new users > paste the service account email. Grant app-level
   permissions "View financial data, orders, and cancellation survey responses" and "Manage orders and subscriptions"
   for this app only. Access can take a while (Google says up to ~24 to 48 hours in some cases: UNVERIFIED) to start working.
5. Keep the JSON out of git. Store only in Supabase secrets and a password manager.

## Generate the entitlement signing key pair
```
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out entitlement_private.pem
openssl pkey -in entitlement_private.pem -pubout -out entitlement_public.pem
```
`entitlement_private.pem` -> Supabase secret `ENTITLEMENT_SIGNING_KEY_PEM`. `entitlement_public.pem` -> pasted into `mh_platform_config.gd`.
If the private key leaks, rotate: new pair, update secret and app; old tokens stop verifying so users press Restore.

## Deploy
```
supabase functions deploy verify-purchase
supabase functions deploy verify-integrity
```
The client sends the project anon key as `apikey`/`Authorization` (see `game/platform/mh_verify_api.gd`); JWT verification can stay ON.

## Known gaps
- No rate limiting or purchase-token reuse detection (one purchase token can mint tokens for many devices). Add a table
  of sha256(purchase_token) with a device counter in Phase 1 if abuse appears.
- No Real-time developer notifications (refund revocation). Refunds are noticed only at the next online re-verify after `ref`. The client
  currently keeps a cached token forever offline; a refunded user therefore keeps the unlock until they re-verify. Accepted for a $4.99 game; revisit.
- Apple verification (`verify-apple`, App Store Server API) is not written.

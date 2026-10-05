# supabase/ : Mulligan Hills backend

Owner: backend workstream. Written 2026-10-04. Decisions this implements: DEC-012, DEC-016, DEC-029, DEC-030, DEC-031, DEC-036, DEC-044, DEC-057, DEC-058, DEC-059, PROP-03, PROP-04.
Setup for a non-programmer: `supabase/FOR_NATHAN.md`. Store paperwork: `docs/store/`.

## Status: what was run and what was not
| Part | Status |
| --- | --- |
| `migrations/*.sql` | RUN on a throwaway PostgreSQL 16 with a stub of Supabase's `auth` and `storage` (`tests/00_supabase_stub.sql`). 90 checks pass (`tests/run_sql_tests.sh`): conflict rules, RLS, grants, kill switch, validation, cascades. NOT run on a real Supabase project. |
| Edge Function logic (`_shared/*.ts`, `*/handler.ts`) | RUN under Deno 2.9 with an in-memory fake backend: 47 tests pass (`deno test --allow-read supabase/functions`). `deno check` is clean on every `handler.ts` and `_shared` file except those that import supabase-js. |
| `_shared/supabase_backend.ts`, every `*/index.ts` | NOT run, NOT type-checked (they import `npm:@supabase/supabase-js@2`, npm was blocked in the sandbox). supabase-js method names follow its v2 docs as remembered. First deploy is the real test. |
| Calls to Google (Play Developer API, Play Integrity) | NOT run (as before). Endpoint shapes are still UNVERIFIED, see `docs/phase0/platform.md` section 4. |
| Storage signed URLs, `list()` size metadata | NOT run. `objectInfo` reads `metadata.size` from `storage.list()`; if Storage does not report it, size checking is skipped (the 8 MiB bucket limit still applies). |
| Apple verification (`verify-apple`) | Not written (iOS is after Android, DEC-002). |

## Layout
```
supabase/
  config.toml                  function settings (verify_jwt = false on all, see the comment in the file)
  migrations/                  SQL, run in filename order
  setup_all.sql                GENERATED: all migrations in one file for the SQL Editor (build_setup_all.sh)
  tests/                       SQL tests + a Supabase stub (test only)
  functions/
    _shared/                   crypto, google_auth, integrity, entitlement (existing) + backend, remote_config, analytics, codes ...
    verify-purchase/           existing, now also counts token reuse
    verify-integrity/          existing
    remote-config/             GET the active config (kill switches)
    cloud-save/                list / begin_upload / commit / download / delete
    daily-challenge/           submit / leaderboard
    account/                   transfer code, claim, delete account (in app and from the web)
    ingest-analytics/          opt-in events, validated against the catalog
```

## Tables (all have row level security ON)
| Table | Who can touch it from the app |
| --- | --- |
| `cloud_saves` | a signed-in player may SELECT their own rows. No writes. |
| `transfer_codes` | nobody (service role only) |
| `remote_config_versions` | anyone may SELECT the one active row. No writes. |
| `daily_scores` | nobody directly. Reads go through `daily_leaderboard`, writes through `daily_submit` (service role, via the function). |
| `analytics_events` | nobody |
| `purchase_verifications` | nobody |
| Storage bucket `cloud-saves` | private; no policies, so only signed URLs minted by the `cloud-save` function work |

Every SQL function that writes is `security definer`, has `search_path = ''`, and EXECUTE is revoked from `public, anon, authenticated` (only `service_role` may call them). The SQL tests prove a signed-in player gets "permission denied" on all of them.

## Client contract (for the GDScript side)
All calls: `POST {SUPABASE_URL}/functions/v1/<name>`, headers `Content-Type: application/json`, `apikey: <anon key>`, and for player functions `Authorization: Bearer <player access token>` (the anonymous sign-in session). Errors are always `{ "ok": false, "error": "<code>" }`. Never show `error` text to players; map the codes.

Anonymous sign-in: `POST {SUPABASE_URL}/auth/v1/signup` with body `{}` and the anon key (Supabase "anonymous sign-ins", must be switched on in the dashboard). Keep the returned `access_token` and `refresh_token`.

Every request to `cloud-save` and `daily-challenge` must carry `"app_version": "x.y.z"`; the server answers 426 `update_required` when it is below remote config `min_app_version`.

### remote-config  (no sign in)
`GET /functions/v1/remote-config?have=<config_version>` -> `{ok:true, config}` or `{ok:true, not_modified:true}`. Keep the last good config; on any error use it (or the bundled defaults). `kill_switches.X == false` means feature X is OFF.

### cloud-save  (player token)
| action | body (besides action, app_version) | success | notes |
| --- | --- | --- | --- |
| `list` | none | `{saves:[{slot,version,sha256,size_bytes,summary,updated_at}]}` | |
| `begin_upload` | `slot`, `expected_version`, `size_bytes`, `sha256` | `{upload_id, upload_url, upload_token, max_bytes}` or `{in_sync:true, cloud}` | `expected_version` = the cloud version this device last synced for the slot (0 = never). PUT the bytes to `upload_url`. |
| `commit` | `slot`, `expected_version`, `upload_id`, `size_bytes`, `sha256`, `summary` | `{cloud}` | `summary` keys allowed: day, cash, holes, playtime_s, saved_at_unix, save_version, revision, app_version (whole numbers, app_version a string). Store `cloud.version` as the new last-synced version. |
| `download` | `slot` | `{download_url, expires_in, cloud}` | verify `sha256` after download, then run the normal save validation. |
| `delete` | `slot` | `{deleted}` | works even when `cloud_sync` is switched off |

**Conflicts (DEC-058).** `409 {error:"conflict", cloud:{version,sha256,summary,...}}` means the cloud holds something this device has not seen. Nothing was written. Show the player both sides (day, cash, holes, play time) and let them choose:
- Keep this device's save: call `begin_upload` again with `expected_version = cloud.version` from the 409, then PUT and `commit`.
- Use the cloud save: `download`, replace the local slot (keep a `.bak`).
- Keep both: `download` into a free manual slot.
- Cancel: do nothing.
Never retry automatically with the new version. The retry is the player's decision. `409 stale_upload` or `400 upload_missing` on commit: start again from `begin_upload`. A new phone that has never synced sends `expected_version: 0`, so it is asked as soon as the cloud already has something.

### account  (player token, except `delete_with_code`)
| action | body | success |
| --- | --- | --- |
| `create_transfer_code` | none | `{code:"ABCD-EFGH-JKLM", expires_in:900}`. Show once. 429 `too_fast` if asked again within 10 s. |
| `preview_transfer` | `code` | `{saves:[{slot,summary,...}]}` (nothing changes) |
| `claim_transfer` | `code`, `slots:[..]`, `overwrite_slots:[..]` | `{results:[{slot,status}]}`. 409 `conflict` with `conflicts:[...]` if a chosen slot already holds a cloud save and was not listed in `overwrite_slots`: show those to the player and ask. |
| `delete_account` | `confirm:"DELETE"`, optional `install_id` | `{deleted:true}`. Then call `MHPlatform.on_account_deleted(...)` and wipe the local session. |
| `delete_with_code` | `code`, `confirm:"DELETE"`, optional `install_id` | no sign in; used by the web deletion page |

Deleting an account removes cloud saves, daily scores, transfer codes, the sign-in record and (with `install_id`) analytics events. It never touches the purchase (store account) and never touches local saves.

### daily-challenge  (player token)
`submit`: `day` (UTC day number `floor(unix/86400)`, today or yesterday), `score_pm` 0..1000, `name_preset_id` 0..999, `template_id`, `rating_version` (`MHRATE-x.y.z`), `sim_version` (`MHSIM-x.y.z`), optional `content_hash` (8..64 hex), `app_version`, optional `attestation` (the `mhi1` token from `verify-integrity`, action `daily_submit`; only checked when the secret `DAILY_REQUIRE_ATTESTATION=true`). Limits: 3 attempts per day (`daily_challenges.json attempts_per_day`), 5 s between submits. Answers: `{attempts, best_score_pm, improved}` | 429 `attempts_exhausted` / `too_fast` | 400 `bad_day`, `bad_score`, ... | 503 `feature_disabled` (kill switch).
`leaderboard`: `day`, optional `limit` (max 100) -> `{board:{day,total,top:[{rank,name_preset_id,score_pm,is_me}],me:{rank,...}|null}}`. No user ids are ever returned.
Scores are claims. The server does bounds and rate checks only (DEC-036); do not show the board as proof of anything.

### ingest-analytics  (anon key)
`{events:[...up to 100, one install...]}` -> `{accepted, duplicates, rejected:[{index,reason}]}`; `{delete_install_id}` erases an install. Only send after the player opted in (DEC-057). A `consent_decision` with `analytics:false` is refused by design: if the player says no, send nothing. 429 `throttled` above 600 events per install per hour.

## Secrets
Existing ones are in `functions/README.md`. New:
| Name | Value |
| --- | --- |
| `CLOUD_SAVE_MAX_BYTES` | optional, default 8388608 (8 MiB). Must not exceed the bucket limit set in migration 100 (also 8 MiB). |
| `PURCHASE_MAX_VERIFICATIONS_30D` | optional, default 10 |
| `DAILY_REQUIRE_ATTESTATION` | optional, `false` by default. `true` needs `ENTITLEMENT_PUBLIC_KEY_PEM` (SPKI PEM, same key as in the game) and `ANDROID_PACKAGE_NAME`. |
| `ALLOWED_RATING_VERSIONS` | optional, comma list, e.g. `MHRATE-1.0.0`. Empty = any well formed version. |

`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` are provided to Edge Functions by Supabase itself (UNVERIFIED for projects using the newest key system; if a function logs "missing" for these, add them as secrets by hand).

## Running the tests
```
deno test --allow-read supabase/functions
PGHOST=/tmp PGPORT=5432 PGUSER=postgres ./supabase/tests/run_sql_tests.sh     # any throwaway local PostgreSQL 15+, never a real project
```
Two tests keep copies in step with `docs/spec/data/`: `_shared/analytics_catalog.json` must equal `analytics_catalog.json`, and `ATTEMPTS_PER_DAY` must equal `daily_challenges.json attempts_per_day`. If one fails, copy the docs file over or change the constant.
`_shared/selftest.node.ts` and `make_golden.py` (older, Node and Python) still work; the Deno tests cover the same checks.

## Client work still needed (nothing below exists in `game/` yet)
1. Anonymous sign-in and token refresh (`/auth/v1/signup`, refresh), stored outside save slots.
2. Cloud sync service: per slot `last_synced_version` (stored beside, not inside, the save, so the save checksum stays valid), upload/download as in the contract above, using `MHCloudConflict` (already built) for the prompt. Keep a `.bak` before replacing a local slot with a download.
3. Cloud conflict screen, transfer code screen (create, show once, enter, preview, choose slots, confirm overwrites), "get a deletion code" button (calls `create_transfer_code`; the web page needs it), delete account (`delete_account`, then `MHPlatform.on_account_deleted`).
4. Remote config fetcher with last good config on disk, bundled defaults, clamp by schema, kill switch handling, `banner_key`.
5. Analytics sender: opt-in gate, queue on disk, batches of up to 100 events of one install, erase request on opt-out or identity reset, never send `consent_decision` with `analytics:false`.
6. Daily challenge client: UTC day number, submit with versions, board screen; optional attestation via `MHVerifyApi.verify_integrity(..., action "daily_submit")`.
7. Show the random install id in Settings > Privacy (the web deletion page asks for it).
8. Send `app_version` in every `cloud-save` and `daily-challenge` call.

## Known gaps and open questions
1. **Orphaned uploads.** One pending upload per slot is tracked and deleted on the next `begin_upload`, delete, or account deletion. An abandoned pending upload of a player who never returns stays in Storage. A cleanup job that lists the bucket is not written.
2. **Storage cost.** Free tier storage is small (verify current limits, DEC-059). Typical saves should be well under 1 MiB; the cap is 8 MiB per slot, 5 slots per player.
3. **Web deletion for anonymous accounts** needs a code the player created earlier (15 minute life), so a player who already uninstalled the game cannot use it. The fallback is the support email. Needs a lawyer or Play Console confirmation of what Google accepts (`docs/store/open_questions.md`).
4. **Transfer code attempts are not rate limited per IP** (60 bit codes, 15 minute life, single use make guessing impractical, but there is no counter). Add one if abuse appears.
5. **Leaderboard cheating.** A modified client can submit any score from 0 to 1000 within 3 attempts a day. Play Integrity gating exists but is off by default. Server re-simulation is later work (DEC-036).
6. **`purchase_flow` kill switch** is client side only; `verify-purchase` stays open so Restore always works.
7. **Refund revocation** (Real-time developer notifications) and Apple verification are still not built.
8. **Save content is opaque to the server.** It cannot check that an uploaded save is valid; the game validates after download (SAVE_MIGRATION.md rule 6).
9. **Client schema gaps** noted by the save workstream (`progress.playtime_s`) affect the conflict prompt: the `summary` here already carries `playtime_s`.

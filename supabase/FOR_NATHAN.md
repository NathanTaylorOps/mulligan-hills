# For Nathan: setting up the Mulligan Hills backend (Supabase)

Written 2026-10-04. No programming needed. Every step is copy and paste. Total time: about 90 minutes the first time, plus waiting for downloads.
Cost: nothing for the closed test (free plan, DEC-059). You upgrade to the paid plan before the public launch.

**Honest status.** The database code was run on a test database and the function logic was run with fake data, all passing. It has NOT been run on a real Supabase project, and the screens in Supabase's website change names now and then. Where I am not sure of a menu name I say "(menu name unverified)": if you cannot find it, use the search box at the top of the Supabase page, or send me a screenshot.

**Rules for the whole guide**
- Never paste the `service_role` key, the Google service account file, or the private `.pem` file into chat, email, or GitHub. Not even to me. They go only into the Supabase Secrets screen and your password manager.
- The `anon` / `publishable` key and the project URL are NOT secret. They go into the game.
- Keep a note (password manager) with: Supabase login, database password, project reference, project URL.

---

## Part 1. Create the Supabase project (10 min)

1. Open https://supabase.com in Chrome and choose **Sign in**. "Continue with GitHub" is easiest because you already have a GitHub account.
2. Create an organization if it asks (name: `Mulligan Hills`, type Personal, plan **Free**).
3. Click **New project**.
   - Name: `mulligan-hills`
   - Database password: click **Generate a password**, then **copy it into your password manager right now**. You cannot see it again.
   - Region: pick the one closest to most players. If most testers are in Australia choose Sydney (Oceania); if most are in the USA choose an East US region. It cannot be changed later.
4. Click **Create new project** and wait about 2 minutes until the dashboard appears.
5. Write down two things:
   - **Project URL**: left menu **Project Settings** (cog) > **API** (menu name unverified; newer versions call it "Data API" or show it under **Connect**). It looks like `https://abcdefghijklmnop.supabase.co`.
   - **Project reference**: the `abcdefghijklmnop` part of that address.
6. On the same API screen find the **anon** key (also called **publishable** key). If you see two tabs of keys, the older tab is called "Legacy API keys" and holds a long key starting with `eyJ`. Either one works for the game. Copy it to your notes. Do NOT copy the `service_role` / `secret` key anywhere except where Part 4 says.

## Part 2. Switch on anonymous sign-in (2 min)

The game gives every player a hidden account with no email or password.
1. Left menu **Authentication** > **Sign In / Providers** (menu name unverified).
2. Find **Allow anonymous sign-ins** and turn it **ON**. Click **Save**.
3. While you are in Authentication, look for **Rate Limits** and leave the defaults.

## Part 3. Create the tables (10 min)

1. On your computer open the file `supabase/setup_all.sql` from the game repository (GitHub website: open the repo, go to `supabase`, click `setup_all.sql`, click the **Copy raw file** button).
2. In Supabase click **SQL Editor** (left menu) > **New query**.
3. Paste the whole file. Click **Run** (bottom right).
4. Expected: a result saying "Success. No rows returned" or a small table with the number 1. If it prints a red error, copy the red text to me and do not run anything else. If you only see a NOTICE about `pg_cron`, that is fine (Part 8 covers it).
5. Check: left menu **Table Editor**. You should see these tables: `cloud_saves`, `transfer_codes`, `remote_config_versions`, `daily_scores`, `analytics_events`, `purchase_verifications`. Each should show a small badge **RLS enabled** (or no "RLS disabled" warning). If any says RLS disabled, tell me before going on.
6. Check the first remote config: SQL Editor > New query, paste this, Run:
   ```
   select config_version, is_active, note from public.remote_config_versions;
   ```
   Expected: one row, version 1, active `true`, note `initial config`.
7. Check the private storage bucket: left menu **Storage**. You should see a bucket `cloud-saves` that is **not** marked Public.

**Never run `setup_all.sql` a second time on this project** (it would fail halfway). Later changes come as small new files from me.

## Part 4. Secrets (15 min)

Secrets are settings only the server can read. Open **Edge Functions** (left menu) > **Secrets** (menu name unverified; it may be under Project Settings > Edge Functions). Add each row with **Add new secret**.

| Name | Value | Where it comes from |
| --- | --- | --- |
| `ANDROID_PACKAGE_NAME` | `com.mulliganhills.game` (or the final id, it must match the game) | the id in `mh_platform_config.gd` |
| `ALLOWED_PRODUCT_IDS` | `mh_full_unlock` | |
| `INTEGRITY_MODE` | `log` | leave as `log` for the closed test |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | the whole text of the Google service account key file | `docs/phase0/platform.md` and `supabase/functions/README.md`, "Service account setup" |
| `ENTITLEMENT_SIGNING_KEY_PEM` | the whole text of `entitlement_private.pem` | made with the two `openssl` commands in `supabase/functions/README.md` |

For the two long values, if the box only takes one line, make a one-line copy first. In PowerShell:
```
(Get-Content -Raw C:\keys\service-account.json | ConvertFrom-Json | ConvertTo-Json -Compress) | Set-Clipboard
```
then paste (Ctrl+V) into the value box. For the PEM file:
```
(Get-Content -Raw C:\keys\entitlement_private.pem) -replace "`r?`n", "\n" | Set-Clipboard
```
then paste. (Change `C:\keys\...` to where your files really are.)

You can leave out the Google values until you have the Play Console set up; everything except `verify-purchase` and `verify-integrity` works without them.

The function code also reads `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`. Supabase normally supplies those itself. If a function log later says "missing SUPABASE_URL" or similar, add them here by hand (the service role key is on the API screen; copy it straight into the secret box and nowhere else).

## Part 5. Put the functions online (30 min)

You need Node.js once, to run Supabase's helper program.
1. Download **Node.js LTS** from https://nodejs.org and run the installer with the default choices. Restart PowerShell afterwards.
2. Open **PowerShell** and go to the game repository folder. Replace the path with yours:
   ```
   cd C:\Users\YOURNAME\Documents\golf-tycoon
   ```
3. Log in (a browser window opens, approve it). If it asks "Ok to proceed? (y)" type `y` and Enter.
   ```
   npx supabase@latest login
   ```
4. Link the folder to your project (use YOUR project reference; it asks for the database password from Part 1):
   ```
   npx supabase@latest link --project-ref abcdefghijklmnop
   ```
5. Deploy all functions at once:
   ```
   npx supabase@latest functions deploy
   ```
   Expected: lines like `Deployed Functions on project ...` for `account`, `cloud-save`, `daily-challenge`, `ingest-analytics`, `remote-config`, `verify-integrity`, `verify-purchase`.
   If it says Docker is not running: add `--use-api` to the end of the command and run again.
   If it prints a red error, copy it to me.
6. In the dashboard, open **Edge Functions**. You should see all seven with a green status.

## Part 6. Try it (10 min)

Paste these into PowerShell one at a time. Replace `YOUR_REF` and `YOUR_ANON_KEY` first.
```
$url = "https://YOUR_REF.supabase.co"
$key = "YOUR_ANON_KEY"
```
**Test 1, remote config.** Expected: `ok : True` and a `config` block with `kill_switches`.
```
Invoke-RestMethod -Uri "$url/functions/v1/remote-config" -Headers @{ apikey = $key }
```
**Test 2, make a hidden player and ask for cloud saves.** Expected: `ok : True` and an empty `saves`.
```
$s = Invoke-RestMethod -Method Post -Uri "$url/auth/v1/signup" -Headers @{ apikey = $key; "Content-Type" = "application/json" } -Body "{}"
$jwt = $s.access_token
Invoke-RestMethod -Method Post -Uri "$url/functions/v1/cloud-save" -Headers @{ apikey = $key; Authorization = "Bearer $jwt"; "Content-Type" = "application/json" } -Body '{"action":"list","app_version":"0.1.0"}'
```
If Test 2's first line fails with "Anonymous sign-ins are disabled", redo Part 2.
**Test 3, daily challenge.** Expected: `ok : True`, `attempts : 1`.
```
$day = [int][math]::Floor([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() / 86400)
$body = @{ action="submit"; app_version="0.1.0"; day=$day; score_pm=500; name_preset_id=1; template_id="gem_par3"; rating_version="MHRATE-1.0.0"; sim_version="MHSIM-1.0.0" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$url/functions/v1/daily-challenge" -Headers @{ apikey = $key; Authorization = "Bearer $jwt"; "Content-Type" = "application/json" } -Body $body
```
Run Test 3 again straight away: expected error `too_fast` (PowerShell shows it as a 429 error). That is correct.
**Test 4, kill switch round trip** (also the way you will use it in real life). In the SQL Editor run:
```
select public.mh_set_kill_switch('daily_challenge', false, 'test');
```
Wait 40 seconds, run Test 3 again: expected error `feature_disabled` (503). Then switch it back:
```
select public.mh_set_kill_switch('daily_challenge', true, 'test over');
```
(The functions remember the config for up to 30 seconds. The game itself asks for the config when it starts and from time to time.)

Cleanup of your test data: SQL Editor:
```
delete from auth.users where is_anonymous;
```
This removes the hidden test players and, through them, their saves and scores. Do this only before launch, never once real testers exist.

## Part 7. Give the game its addresses (5 min)

Send me (or paste into `game/platform/mh_platform_config.gd` yourself) these three non-secret values: the **Project URL**, the **anon/publishable key**, and the **public key** of the signing pair (`entitlement_public.pem`). Never the private one.

## Part 8. Looking after it

**The kill switches.** Run in SQL Editor. `false` turns a feature OFF, `true` turns it back ON. Players' games pick the change up next time they fetch config.
```
select public.mh_set_kill_switch('cloud_sync', false, 'why');
select public.mh_set_kill_switch('daily_challenge', false, 'why');
select public.mh_set_kill_switch('analytics', false, 'why');
select public.mh_set_kill_switch('purchase_flow', false, 'why');
select public.mh_set_kill_switch('tournaments', false, 'why');
select public.mh_set_kill_switch('notifications', false, 'why');
```
Which to use when:
- Cloud saves are misbehaving: `cloud_sync` off. Players keep playing offline; their local saves are untouched.
- Daily leaderboard has junk or the function is failing: `daily_challenge` off.
- You want data collection to stop at once: `analytics` off.
- The unlock purchase screen is broken: `purchase_flow` off. Restore still works on purpose.
**Undo the last change:** `select public.mh_rollback_remote_config();`
**See the history:** `select config_version, is_active, note, created_at from public.remote_config_versions order by config_version desc;`
**Force every player to update:** run this, changing `0.2.0` to the oldest version you still allow. Players on older versions see "update required" for cloud saves and the daily challenge:
```
select public.mh_publish_remote_config(
  jsonb_set((select config from public.remote_config_versions where is_active), '{min_app_version}', '"0.2.0"'),
  'min version 0.2.0');
```
The database refuses any config that breaks the rules (for example a start cash of 5), so you cannot break the game with a typo; you will just get an error message.

**Nightly cleanup (deletes old analytics after 180 days, old daily scores after 30 days).** If Part 3 showed a `pg_cron` notice, turn it on once: **Database** > **Extensions** (menu name unverified), search `pg_cron`, switch it on. Then SQL Editor:
```
select cron.schedule('mh-nightly-cleanup', '17 3 * * *', 'select public.mh_nightly_cleanup()');
```
**Logs:** Edge Functions > click a function > **Logs**. Errors are one line each. The functions never log save contents, scores, or codes.

**Free plan limits.** Free projects can be paused after a period of no activity, and have size limits. The exact numbers change, so check the pricing page and your project's **Usage** screen before the closed test starts and again before launch (DEC-059). Before the public launch, switch to the paid plan (Project Settings > **Billing**) so the project is never paused and has daily backups.

## Part 9. Safety check before inviting testers (10 min)
1. Table Editor: every table shows RLS enabled.
2. Storage > `cloud-saves` is not public.
3. Search the repository on GitHub for `service_role` and for `BEGIN PRIVATE KEY`. Nothing should come up outside documentation.
4. The `anon` key is the only Supabase key inside the game.
5. Write down in your notes the date you did this.

## If something goes wrong
| What you see | What to do |
| --- | --- |
| Red error when running `setup_all.sql` | Copy the red text to me. Do not run the file again. |
| `Anonymous sign-ins are disabled` | Part 2. |
| Function returns `server_error` | Edge Functions > that function > Logs. Copy the last few lines to me. |
| Function returns `feature_disabled` | A kill switch is off (Part 8). |
| Function returns `update_required` | The game's version is lower than `min_app_version`. |
| `not_signed_in` | The player token is missing or expired; the game must sign in again. |
| A player says their cloud save asks "which one to keep" | Working as designed (DEC-058). The player picks. |
| A player asks you to delete their data | Ask them for the in-app Delete account, or the web page once it is live (`docs/store/web/delete-account.html`). Without either, ask for the transfer code from the game; you cannot identify an anonymous account any other way. |

## What I could not check (so you know what the first real run may reveal)
- Exact names of Supabase menus and the new API key screens.
- That `supabase functions deploy` works with the `verify_jwt = false` settings and the `npm:@supabase/supabase-js` import without changes.
- Storage signed-URL calls and the object size check (the code is written from the supabase-js documentation as I remember it).
- Everything that talks to Google (purchase check, Play Integrity): see `docs/phase0/platform.md` section 4, items 5 and 8.
- Current Supabase free plan limits and pause rules.

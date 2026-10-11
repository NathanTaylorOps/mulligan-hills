-- SQL tests for the migrations. Run through run_sql_tests.sh (needs a throwaway PostgreSQL, see that file).
-- Each check raises an exception on failure; the script stops at the first failure (ON_ERROR_STOP).
create schema t;
grant usage on schema t to public;
create function t.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is not true then raise exception 'FAIL: %', msg; end if;
  raise notice 'PASS  %', msg;
end $$;
-- true when running the statement raises insufficient_privilege (permission denied)
create function t.denied(stmt text) returns boolean language plpgsql as $$
begin execute stmt; return false;
exception when insufficient_privilege then return true; end $$;

insert into auth.users (id, is_anonymous) values
  ('00000000-0000-4000-8000-000000000001', true), ('00000000-0000-4000-8000-000000000002', true);

-- =============================================================== cloud saves (DEC-058: always ask) ================
do $$
declare
  u1 uuid := '00000000-0000-4000-8000-000000000001'; u2 uuid := '00000000-0000-4000-8000-000000000002';
  r jsonb; sha text := repeat('a', 64); n int;
begin
  r := public.cloud_save_begin(u1, 0, 0, 'u1/slot0/p1');
  perform t.ok(r ->> 'status' = 'ok', 'first begin on an empty slot with expected 0 is ok');
  r := public.cloud_save_begin(u1, 0, 3, 'u1/slot0/px');
  perform t.ok(r ->> 'status' = 'conflict', 'begin with the wrong expected version is a conflict');
  r := public.cloud_save_begin(u1, 0, 0, 'u1/slot0/p1');
  perform t.ok(r ->> 'status' = 'ok', 'begin again replaces the pending upload');
  r := public.cloud_save_commit(u1, 0, 0, 'u1/slot0/WRONG', sha, 1000, '{"day":5}');
  perform t.ok(r ->> 'status' = 'stale_upload', 'commit with a path that is not the pending one is refused');
  r := public.cloud_save_commit(u1, 0, 0, 'u1/slot0/p1', sha, 1000, '{"day":5,"cash":100,"holes":6}');
  perform t.ok(r ->> 'status' = 'ok' and (r #>> '{cloud,version}')::int = 1, 'commit succeeds and version becomes 1');
  r := public.cloud_save_begin(u1, 0, 0, 'u1/slot0/p2');
  perform t.ok(r ->> 'status' = 'conflict' and (r #>> '{cloud,summary,day}')::int = 5,
               'a second device that thinks the slot is empty gets a conflict with the cloud summary');
  r := public.cloud_save_begin(u1, 0, 1, 'u1/slot0/p2');
  perform t.ok(r ->> 'status' = 'ok', 'begin with the right version is ok');
  r := public.cloud_save_commit(u1, 0, 0, 'u1/slot0/p2', sha, 1000, '{}');
  perform t.ok(r ->> 'status' = 'conflict', 'commit with a stale expected version is a conflict (nothing overwritten)');
  perform t.ok((select version from public.cloud_saves where user_id = u1 and slot = 0) = 1, 'cloud version unchanged after refused commit');
  r := public.cloud_save_commit(u1, 0, 1, 'u1/slot0/p2', repeat('b', 64), 2000, '{"day":9}');
  perform t.ok(r ->> 'status' = 'ok' and r ->> 'discard_path' = 'u1/slot0/p1', 'second commit ok, old object is reported for deletion');
  perform t.ok(jsonb_array_length(public.cloud_save_list(u1)) = 1, 'list shows only slots that hold a save');
  perform t.ok(jsonb_array_length(public.cloud_save_all_paths(u1)) = 1, 'all_paths lists the stored object');

  begin perform public.cloud_save_begin(u1, 9, 0, 'x'); perform t.ok(false, 'bad slot must raise');
  exception when raise_exception then perform t.ok(sqlerrm = 'bad_slot', 'slot 9 is rejected'); end;

  -- import (claim with transfer code)
  r := public.cloud_save_import(u2, 1, 'u2/slot1/c1', sha, 10, '{"day":2}', false);
  perform t.ok(r ->> 'status' = 'ok', 'import into an empty slot is ok');
  r := public.cloud_save_import(u2, 1, 'u2/slot1/c2', sha, 10, '{"day":3}', false);
  perform t.ok(r ->> 'status' = 'conflict', 'import over an occupied slot without confirmation is refused');
  r := public.cloud_save_import(u2, 1, 'u2/slot1/c2', sha, 10, '{"day":3}', true);
  perform t.ok(r ->> 'status' = 'ok' and (r #>> '{cloud,version}')::int = 2, 'import with confirmation overwrites and bumps version');

  r := public.cloud_save_delete(u2, 1);
  perform t.ok(r ->> 'status' = 'ok' and jsonb_array_length(r -> 'discard_paths') = 1, 'delete returns the object path');
  r := public.cloud_save_delete(u2, 1);
  perform t.ok(r ->> 'status' = 'not_found', 'delete of an empty slot says not_found');

  -- RLS
  perform set_config('request.jwt.claim.sub', u1::text, true);
  set local role authenticated;
  select count(*) into n from public.cloud_saves;
  perform t.ok(n >= 1 and not exists (select 1 from public.cloud_saves where user_id <> u1), 'a player sees only their own cloud rows');
  perform t.ok(t.denied($q$insert into public.cloud_saves (user_id, slot) values ('00000000-0000-4000-8000-000000000001', 3)$q$), 'a player cannot insert cloud rows');
  perform t.ok(t.denied($q$update public.cloud_saves set version = 99$q$), 'a player cannot update cloud rows');
  perform t.ok(t.denied($q$select public.cloud_save_begin('00000000-0000-4000-8000-000000000001', 0, 2, 'x')$q$), 'a player cannot call the write functions');
  reset role;
  perform set_config('request.jwt.claim.sub', u2::text, true);
  set local role authenticated;
  perform t.ok(not exists (select 1 from public.cloud_saves where user_id = u1), 'another player cannot see the first player rows');
  reset role;
  set local role anon;
  perform t.ok(t.denied('select * from public.cloud_saves'), 'anon (no sign in) cannot read cloud rows');
  reset role;
  perform t.ok((select public from storage.buckets where id = 'cloud-saves') = false, 'the cloud-saves bucket is private');
end $$;

-- =============================================================== transfer codes ===================================
do $$
declare u1 uuid := '00000000-0000-4000-8000-000000000001'; h text := repeat('1', 64); r jsonb;
begin
  r := public.transfer_code_create(u1, h, 900);
  perform t.ok(r ->> 'status' = 'ok', 'a transfer code can be created');
  r := public.transfer_code_create(u1, repeat('2', 64), 900);
  perform t.ok(r ->> 'status' = 'too_fast', 'a second code within 10 seconds is refused');
  perform t.ok(public.transfer_code_peek(h) ->> 'status' = 'ok', 'peek finds a valid code');
  perform t.ok(public.transfer_code_consume(h) ->> 'status' = 'ok', 'consume works once');
  perform t.ok(public.transfer_code_consume(h) ->> 'status' = 'invalid', 'a used code cannot be used again');
  update public.transfer_codes set used_at = null, expires_at = now() - interval '1 second', created_at = now() - interval '1 hour' where code_hash = h;
  perform t.ok(public.transfer_code_peek(h) ->> 'status' = 'invalid', 'an expired code is invalid');
  r := public.transfer_code_create(u1, repeat('3', 64), 900);
  perform t.ok(r ->> 'status' = 'ok' and (select count(*) from public.transfer_codes where user_id = u1) = 1, 'a new code replaces the old one');
  begin perform public.transfer_code_create(u1, repeat('4', 64), 5); perform t.ok(false, 'ttl 5 must raise');
  exception when raise_exception then perform t.ok(sqlerrm = 'bad_ttl', 'a silly time to live is rejected'); end;
  set local role authenticated;
  perform t.ok(t.denied('select * from public.transfer_codes'), 'players cannot read transfer codes');
  reset role;
end $$;

-- =============================================================== remote config ====================================
do $$
declare good jsonb; v int; msg text; cfg jsonb;
begin
  select config into good from public.remote_config_versions where is_active;
  perform t.ok(good is not null and (good #>> '{kill_switches,daily_challenge}') = 'true', 'seed config is active with every switch ON');
  perform t.ok(public.mh_validate_remote_config(good) is null, 'the seed config validates');
  perform t.ok(public.mh_validate_remote_config(good || '{"extra":1}') is not null, 'unknown top level key is refused');
  perform t.ok(public.mh_validate_remote_config(good #- '{kill_switches,tournaments}') is not null, 'missing kill switch is refused');
  perform t.ok(public.mh_validate_remote_config(jsonb_set(good, '{kill_switches,cloud_sync}', '"yes"')) is not null, 'kill switch must be a boolean');
  perform t.ok(public.mh_validate_remote_config(jsonb_set(good, '{economy,start_cash}', '999999999')) is not null, 'out of range start_cash is refused');
  perform t.ok(public.mh_validate_remote_config(jsonb_set(good, '{economy,green_fee_min}', '300')) is not null, 'fee min above fee max is refused');
  perform t.ok(public.mh_validate_remote_config(jsonb_set(good, '{economy,cost_multiplier_x100}', '[100,200,400,800,1400]')) is not null, 'the retired cost multiplier key is refused (DEC-050, PROP-03)');
  perform t.ok(public.mh_validate_remote_config(good || '{"min_app_version":"1.0"}') is not null, 'bad min_app_version is refused');
  perform t.ok(public.mh_validate_remote_config(good || '{"banner_key":"Bad Key"}') is not null, 'bad banner_key is refused');
  perform t.ok(public.mh_validate_remote_config(good || '{"banner_key":"banner.maintenance"}') is null, 'a good banner_key is accepted');
  perform t.ok(public.mh_validate_remote_config(jsonb_set(good, '{economy,sim_speed}', '5')) is not null, 'sim parameters can not be smuggled in (PROP-03)');
  perform t.ok(public.mh_validate_remote_config(jsonb_set(good, '{economy,price}', '5')) is not null, 'a price can not be smuggled in (PROP-03)');

  begin
    insert into public.remote_config_versions (config_version, config) values (50, good || '{"extra":1}');
    perform t.ok(false, 'direct insert of a bad config must raise');
  exception when sqlstate '22023' then perform t.ok(true, 'the table itself refuses a bad config'); end;

  v := public.mh_set_kill_switch('daily_challenge', false, 'test');
  perform t.ok(v = 2 and (select (config #>> '{kill_switches,daily_challenge}') = 'false' from public.remote_config_versions where is_active),
               'kill switch flips daily_challenge OFF as version 2');
  perform t.ok((select count(*) from public.remote_config_versions where is_active) = 1, 'exactly one config is active');
  perform t.ok((select config ->> 'config_version' from public.remote_config_versions where is_active) = '2', 'config_version inside the JSON matches');
  begin perform public.mh_set_kill_switch('nonsense', true); perform t.ok(false, 'unknown switch must raise');
  exception when raise_exception then perform t.ok(sqlerrm like 'unknown kill switch%', 'unknown kill switch name is rejected'); end;
  v := public.mh_rollback_remote_config();
  perform t.ok(v = 3 and (select (config #>> '{kill_switches,daily_challenge}') = 'true' from public.remote_config_versions where is_active),
               'rollback publishes the earlier config as version 3');

  set local role anon;
  perform t.ok((select count(*) from public.remote_config_versions) = 1, 'anon can read only the active config row');
  perform t.ok(t.denied($q$insert into public.remote_config_versions (config_version, config) values (99, '{}')$q$), 'anon cannot write remote config');
  perform t.ok(t.denied($q$select public.mh_set_kill_switch('cloud_sync', false)$q$), 'anon cannot flip a kill switch');
  reset role;
  set local role authenticated;
  perform t.ok(t.denied($q$select public.mh_publish_remote_config('{}')$q$), 'a signed-in player cannot publish a config');
  reset role;
end $$;

-- =============================================================== daily challenge ==================================
do $$
declare
  u1 uuid := '00000000-0000-4000-8000-000000000001'; u2 uuid := '00000000-0000-4000-8000-000000000002';
  now0 timestamptz := '2026-10-10 12:00:00+00'; d int := public.mh_utc_day('2026-10-10 12:00:00+00');
  r jsonb;
begin
  perform t.ok(d = floor(extract(epoch from now0) / 86400), 'utc day number');
  r := public.daily_submit(u1, d, 400, 3, 'gem_par3', 'MHRATE-1.0.0', 'MHSIM-1.0.0', 'deadbeef', '0.1.0', 3, 5, now0);
  perform t.ok(r ->> 'status' = 'ok' and (r ->> 'improved')::boolean, 'first submit ok');
  r := public.daily_submit(u1, d, 500, 3, 'gem_par3', 'MHRATE-1.0.0', 'MHSIM-1.0.0', 'deadbeef', '0.1.0', 3, 5, now0 + interval '2 seconds');
  perform t.ok(r ->> 'status' = 'too_fast', 'two submits 2 seconds apart are refused');
  r := public.daily_submit(u1, d, 300, 3, 'gem_par3', 'MHRATE-1.0.0', 'MHSIM-1.0.0', 'deadbeef', '0.1.0', 3, 5, now0 + interval '10 seconds');
  perform t.ok(r ->> 'status' = 'ok' and not (r ->> 'improved')::boolean and (r ->> 'best_score_pm')::int = 400, 'a worse second attempt keeps the best score');
  r := public.daily_submit(u1, d, 650, 3, 'gem_par3', 'MHRATE-1.0.0', 'MHSIM-1.0.0', 'deadbeef', '0.1.0', 3, 5, now0 + interval '20 seconds');
  perform t.ok((r ->> 'best_score_pm')::int = 650 and (r ->> 'attempts')::int = 3, 'a better third attempt replaces the best');
  r := public.daily_submit(u1, d, 999, 3, 'gem_par3', 'MHRATE-1.0.0', 'MHSIM-1.0.0', 'deadbeef', '0.1.0', 3, 5, now0 + interval '40 seconds');
  perform t.ok(r ->> 'status' = 'attempts_exhausted', 'the 4th attempt of the day is refused');
  r := public.daily_submit(u2, d + 5, 100, 1, 'gem_par3', 'MHRATE-1.0.0', 'MHSIM-1.0.0', null, '0.1.0', 3, 5, now0);
  perform t.ok(r ->> 'status' = 'bad_day', 'a day in the future is refused');
  r := public.daily_submit(u2, d - 3, 100, 1, 'gem_par3', 'MHRATE-1.0.0', 'MHSIM-1.0.0', null, '0.1.0', 3, 5, now0);
  perform t.ok(r ->> 'status' = 'bad_day', 'a day long in the past is refused');
  r := public.daily_submit(u2, d, 1001, 1, 'gem_par3', 'MHRATE-1.0.0', 'MHSIM-1.0.0', null, '0.1.0', 3, 5, now0);
  perform t.ok(r ->> 'status' = 'bad_score', 'score above 1000 is refused');
  r := public.daily_submit(u2, d - 1, 650, 7, 'gem_par3', 'MHRATE-1.0.0', 'MHSIM-1.0.0', null, '0.1.0', 3, 5, now0 + interval '1 second');
  perform t.ok(r ->> 'status' = 'ok', 'submit for yesterday is allowed (late submit across midnight)');
  r := public.daily_submit(u2, d, 650, 7, 'gem_par3', 'MHRATE-1.0.0', 'MHSIM-1.0.0', null, '0.1.0', 3, 5, now0 + interval '30 seconds');
  r := public.daily_leaderboard(u2, d, 50);
  perform t.ok((r ->> 'total')::int = 2, 'leaderboard counts both players');
  perform t.ok((r #>> '{top,0,rank}')::int = 1 and (r #>> '{top,0,is_me}')::boolean = false, 'on a tie the earlier score ranks first (player 1 reached 650 earlier)');
  perform t.ok((r #>> '{me,rank}')::int = 2 and (r #>> '{me,name_preset_id}')::int = 7, 'my own rank is returned');
  perform t.ok(r::text !~ '00000000-0000-4000', 'no user ids appear in the leaderboard');
  perform t.ok(jsonb_array_length(public.daily_leaderboard(u1, d, 1000) -> 'top') <= 100, 'limit is capped at 100');
  set local role authenticated;
  perform t.ok(t.denied('select * from public.daily_scores'), 'players cannot read the raw score table');
  perform t.ok(t.denied($q$select public.daily_submit('00000000-0000-4000-8000-000000000001', 1, 1, 1, 'a', 'b', 'c', null, '1.0.0')$q$), 'players cannot call daily_submit directly');
  reset role;
  insert into public.daily_scores (day, user_id, best_score_pm, name_preset_id, template_id, rating_version, sim_version, app_version)
    values (100, u2, 10, 1, 'gem_par3', 'MHRATE-1.0.0', 'MHSIM-1.0.0', '0.1.0');
  perform t.ok(public.daily_purge(30) = 1, 'purge removes only the very old row (day 100)');
  perform t.ok((select count(*) from public.daily_scores where day = d) = 2, 'purge keeps recent rows');
end $$;

-- =============================================================== analytics ========================================
do $$
declare
  inst uuid := '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d'; r jsonb;
  ev jsonb := jsonb_build_array(
    jsonb_build_object('event_id', '0b5c2a3e-1111-4222-8333-444455556666', 'name', 'building_upgraded', 'ts_unix', 1790000100,
      'session_id', 'aaaaaaaa-1111-4222-8333-444455556666', 'app_version', '0.1.0', 'platform', 'android', 'build_kind', 'demo',
      'props', jsonb_build_object('building', 'clubhouse', 'tier', 2)));
begin
  r := public.analytics_ingest(inst, ev, 600);
  perform t.ok((r ->> 'inserted')::int = 1, 'one event stored');
  r := public.analytics_ingest(inst, ev, 600);
  perform t.ok((r ->> 'inserted')::int = 0 and (r ->> 'duplicates')::int = 1, 'the same event_id is ignored on retry');
  r := public.analytics_ingest(inst, jsonb_build_array(ev -> 0 || '{"event_id":"0b5c2a3e-1111-4222-8333-444455556667"}'), 1);
  perform t.ok(r ->> 'status' = 'throttled', 'hourly cap throttles an install');
  begin perform public.analytics_ingest(inst, (select jsonb_agg(ev -> 0) from generate_series(1, 101)), 600); perform t.ok(false, 'too large');
  exception when raise_exception then perform t.ok(sqlerrm = 'batch_too_large', 'batches above 100 are refused'); end;
  set local role anon;
  perform t.ok(t.denied('select * from public.analytics_events'), 'anon cannot read analytics');
  reset role;
  set local role authenticated;
  perform t.ok(t.denied('select * from public.analytics_events'), 'players cannot read analytics');
  reset role;
  perform t.ok(public.analytics_delete_install(inst) = 1, 'erasure by install id deletes the rows');
  perform t.ok(public.analytics_purge(180) = 0, 'purge keeps recent rows');
end $$;

-- =============================================================== purchase verifications ===========================
do $$
declare r jsonb; h text := repeat('c', 64);
begin
  r := public.purchase_verification_record(h, 'mh_full_unlock', 'GPA.1', false, 30);
  perform t.ok((r ->> 'count')::int = 1, 'first verification counts 1');
  r := public.purchase_verification_record(h, 'mh_full_unlock', 'GPA.1', false, 30);
  perform t.ok((r ->> 'count')::int = 2, 'second verification counts 2');
  update public.purchase_verifications
     set window_started_at = now() - interval '40 days', last_seen = now()
   where token_hash = h;
  r := public.purchase_verification_record(h, 'mh_full_unlock', 'GPA.1', false, 30);
  perform t.ok((r ->> 'count')::int = 1, 'the counter restarts after the fixed 30 day window even when recently seen');
  set local role authenticated;
  perform t.ok(t.denied('select * from public.purchase_verifications'), 'players cannot read purchase hashes');
  reset role;
  perform t.ok(public.mh_nightly_cleanup() ? 'analytics_deleted', 'nightly cleanup runs');
end $$;

-- =============================================================== account deletion cascade =========================
do $$
declare u1 uuid := '00000000-0000-4000-8000-000000000001';
begin
  perform public.daily_submit(u1, public.mh_utc_day(), 100, 1, 'gem_par3', 'MHRATE-1.0.0', 'MHSIM-1.0.0', null, '0.1.0');
  delete from auth.users where id = u1;
  perform t.ok(not exists (select 1 from public.cloud_saves where user_id = u1)
           and not exists (select 1 from public.daily_scores where user_id = u1)
           and not exists (select 1 from public.transfer_codes where user_id = u1),
           'deleting the auth user removes saves, scores and codes (SAVE_MIGRATION rule 11)');
end $$;

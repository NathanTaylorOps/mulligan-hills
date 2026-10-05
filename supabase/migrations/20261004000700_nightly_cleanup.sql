-- Mulligan Hills: one nightly cleanup job. Retention numbers come from docs/spec/data/analytics_catalog.json
-- (analytics 180 days) and docs/spec/data/daily_challenges.json (history_days 30).

create or replace function public.mh_nightly_cleanup() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a int; d int; p int; t int;
begin
  a := public.analytics_purge(180);
  d := public.daily_purge(30);
  p := public.purchase_verifications_purge(400);
  delete from public.transfer_codes where expires_at < now() - interval '1 day';
  get diagnostics t = row_count;
  return jsonb_build_object('analytics_deleted', a, 'daily_deleted', d, 'purchase_rows_deleted', p, 'codes_deleted', t);
end $$;

revoke all on function public.mh_nightly_cleanup() from public, anon, authenticated;
grant execute on function public.mh_nightly_cleanup() to service_role;

-- Schedule it with pg_cron when the extension can be enabled. If this block prints a NOTICE instead, enable
-- "pg_cron" in the Supabase dashboard (Database > Extensions) and run the select cron.schedule line from the
-- setup guide by hand. The migration never fails because of this.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('mh-nightly-cleanup', '17 3 * * *', 'select public.mh_nightly_cleanup()');
  else
    raise notice 'pg_cron is not available here; schedule public.mh_nightly_cleanup() by hand (see supabase/FOR_NATHAN.md).';
  end if;
exception when others then
  raise notice 'could not schedule cleanup automatically (%). See supabase/FOR_NATHAN.md.', sqlerrm;
end $$;

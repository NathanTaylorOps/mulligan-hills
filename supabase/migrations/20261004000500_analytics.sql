-- Mulligan Hills: analytics events, opt-in only (DEC-057, PROP-04).
--
-- Only the Edge Function `ingest-analytics` writes here, and only events that passed the catalog check
-- (docs/spec/data/analytics_catalog.json). No free text, no advertising id, no hardware id. The only identifiers are
-- a random install_id (the player can reset it in settings) and a random per-launch session_id.
-- Nobody can read this table from the app: row level security is on and there is no policy.
-- Rows are deleted after 180 days (catalog retention_days) and on request (`analytics_delete_install`).

create table public.analytics_events (
  event_id     uuid        primary key,                 -- client generated; makes retries safe (duplicates are ignored)
  name         text        not null check (name ~ '^[a-z][a-z0-9_]{1,39}$'),
  ts_unix      bigint      not null check (ts_unix between 0 and 9007199254740991),
  session_id   uuid        not null,
  install_id   uuid        not null,
  app_version  text        not null check (app_version ~ '^[0-9]+\.[0-9]+\.[0-9]+$'),
  platform     text        not null check (platform in ('android', 'ios')),
  build_kind   text        not null check (build_kind in ('demo', 'full')),
  props        jsonb       not null default '{}'::jsonb
                           check (jsonb_typeof(props) = 'object' and pg_column_size(props) <= 1024),
  received_at  timestamptz not null default now()
);
create index analytics_events_install_idx on public.analytics_events (install_id, received_at);
create index analytics_events_received_idx on public.analytics_events (received_at);
create index analytics_events_name_idx on public.analytics_events (name, received_at);

alter table public.analytics_events enable row level security;
revoke all on table public.analytics_events from anon, authenticated;

-- Insert a batch for ONE install. Throttle: at most p_hourly_cap events per install per rolling hour.
create or replace function public.analytics_ingest(p_install uuid, p_events jsonb, p_hourly_cap int default 600) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  incoming int := jsonb_array_length(p_events);
  recent int;
  inserted int;
begin
  if incoming > 100 then raise exception 'batch_too_large'; end if;
  select count(*) into recent from public.analytics_events
   where install_id = p_install and received_at > now() - interval '1 hour';
  if recent + incoming > p_hourly_cap then
    return jsonb_build_object('status', 'throttled', 'inserted', 0);
  end if;
  insert into public.analytics_events (event_id, name, ts_unix, session_id, install_id, app_version, platform, build_kind, props)
  select e.event_id, e.name, e.ts_unix, e.session_id, p_install, e.app_version, e.platform, e.build_kind, coalesce(e.props, '{}'::jsonb)
    from jsonb_to_recordset(p_events) as e(event_id uuid, name text, ts_unix bigint, session_id uuid, app_version text,
                                           platform text, build_kind text, props jsonb)
  on conflict (event_id) do nothing;
  get diagnostics inserted = row_count;
  return jsonb_build_object('status', 'ok', 'inserted', inserted, 'duplicates', incoming - inserted);
end $$;

create or replace function public.analytics_delete_install(p_install uuid) returns integer
language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  delete from public.analytics_events where install_id = p_install;
  get diagnostics n = row_count;
  return n;
end $$;

create or replace function public.analytics_purge(p_keep_days int default 180) returns integer
language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  delete from public.analytics_events where received_at < now() - make_interval(days => p_keep_days);
  get diagnostics n = row_count;
  return n;
end $$;

revoke all on function public.analytics_ingest(uuid, jsonb, int) from public, anon, authenticated;
revoke all on function public.analytics_delete_install(uuid) from public, anon, authenticated;
revoke all on function public.analytics_purge(int) from public, anon, authenticated;
grant execute on function public.analytics_ingest(uuid, jsonb, int) to service_role;
grant execute on function public.analytics_delete_install(uuid) to service_role;
grant execute on function public.analytics_purge(int) to service_role;

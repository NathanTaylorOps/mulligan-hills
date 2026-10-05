-- Mulligan Hills: remote config with kill switches (DEC-044, DEC-059, PROP-03).
--
-- Mirrors docs/spec/data/remote_config.schema.json (schema_version 1). The rules from that schema:
--   * only the listed keys, only values inside the listed ranges (a bad push cannot leave the ranges);
--   * NEVER simulation or rating parameters, NEVER the price (the store owns it);
--   * kill_switches: true = feature ON, false = feature OFF.
-- The database refuses to store a config that breaks the rules, so a typo in the SQL editor cannot reach players.
-- The Edge Function `remote-config` validates again before serving (belt and braces).

create table public.remote_config_versions (
  config_version integer     primary key check (config_version between 1 and 1000000),
  config         jsonb       not null,
  is_active      boolean     not null default false,
  note           text,
  created_at     timestamptz not null default now()
);
create unique index remote_config_one_active on public.remote_config_versions (is_active) where is_active;

-- ---------------------------------------------------------------------------------------------------------------
-- Validation. Returns NULL when the config is fine, otherwise a short message saying what is wrong.
-- ---------------------------------------------------------------------------------------------------------------
create or replace function public.mh__int_in(j jsonb, k text, lo bigint, hi bigint) returns boolean
language sql immutable set search_path = '' as $$
  select jsonb_typeof(j -> k) = 'number'
     and (j ->> k) ~ '^-?[0-9]{1,15}$'
     and (j ->> k)::bigint between lo and hi;
$$;

create or replace function public.mh__keys_ok(j jsonb, required text[], optional text[]) returns boolean
language sql immutable set search_path = '' as $$
  select jsonb_typeof(j) = 'object'
     and not exists (select 1 from jsonb_object_keys(j) k where k <> all (required || optional))
     and not exists (select 1 from unnest(required) r where not (j ? r));
$$;

create or replace function public.mh_validate_remote_config(c jsonb) returns text
language plpgsql immutable set search_path = '' as $$
declare
  ks jsonb; eco jsonb; ev jsonb; k text; m jsonb; i int;
begin
  if jsonb_typeof(c) is distinct from 'object' then return 'config must be an object'; end if;
  if not public.mh__keys_ok(c, array['schema','schema_version','config_version','issued_unix','min_app_version',
                                     'kill_switches','economy','events'], array['banner_key']) then
    return 'top level keys are wrong (unknown key or missing key)';
  end if;
  if c ->> 'schema' is distinct from 'mh.remote_config' then return 'schema must be mh.remote_config'; end if;
  if not public.mh__int_in(c, 'schema_version', 1, 1) then return 'schema_version must be 1'; end if;
  if not public.mh__int_in(c, 'config_version', 1, 1000000) then return 'config_version out of range'; end if;
  if not public.mh__int_in(c, 'issued_unix', 0, 9007199254740991) then return 'issued_unix out of range'; end if;
  if jsonb_typeof(c -> 'min_app_version') is distinct from 'string'
     or (c ->> 'min_app_version') !~ '^[0-9]+\.[0-9]+\.[0-9]+$' then return 'min_app_version must look like 0.1.0'; end if;
  if c ? 'banner_key' and (jsonb_typeof(c -> 'banner_key') is distinct from 'string'
     or (c ->> 'banner_key') !~ '^[a-z][a-z0-9_]*(\.[a-z0-9_]+){1,4}$' or length(c ->> 'banner_key') > 80) then
    return 'banner_key is not a valid string key';
  end if;

  ks := c -> 'kill_switches';
  if not public.mh__keys_ok(ks, array['cloud_sync','daily_challenge','analytics','purchase_flow','tournaments','notifications'],
                            array[]::text[]) then
    return 'kill_switches must hold exactly cloud_sync, daily_challenge, analytics, purchase_flow, tournaments, notifications';
  end if;
  for k in select jsonb_object_keys(ks) loop
    if jsonb_typeof(ks -> k) is distinct from 'boolean' then return 'kill switch ' || k || ' must be true or false'; end if;
  end loop;

  eco := c -> 'economy';
  if not public.mh__keys_ok(eco, array['cost_multiplier_x100','building_cost_scale_pct','parcel_base_cost','parcel_growth_pct',
                                       'hole_cost','start_cash','green_fee_min','green_fee_max'], array[]::text[]) then
    return 'economy keys are wrong';
  end if;
  m := eco -> 'cost_multiplier_x100';
  if jsonb_typeof(m) is distinct from 'array' or jsonb_array_length(m) <> 5 then return 'cost_multiplier_x100 needs 5 numbers'; end if;
  for i in 0..4 loop
    if jsonb_typeof(m -> i) is distinct from 'number' or (m ->> i) !~ '^[0-9]{1,6}$'
       or (m ->> i)::int not between 50 and 5000 then return 'cost_multiplier_x100 values must be 50 to 5000'; end if;
  end loop;
  if not public.mh__int_in(eco, 'building_cost_scale_pct', 25, 400) then return 'building_cost_scale_pct must be 25 to 400'; end if;
  if not public.mh__int_in(eco, 'parcel_base_cost', 1000, 1000000) then return 'parcel_base_cost must be 1000 to 1000000'; end if;
  if not public.mh__int_in(eco, 'parcel_growth_pct', 100, 200) then return 'parcel_growth_pct must be 100 to 200'; end if;
  if not public.mh__int_in(eco, 'hole_cost', 500, 100000) then return 'hole_cost must be 500 to 100000'; end if;
  if not public.mh__int_in(eco, 'start_cash', 1000, 1000000) then return 'start_cash must be 1000 to 1000000'; end if;
  if not public.mh__int_in(eco, 'green_fee_min', 1, 1000) then return 'green_fee_min must be 1 to 1000'; end if;
  if not public.mh__int_in(eco, 'green_fee_max', 1, 10000) then return 'green_fee_max must be 1 to 10000'; end if;
  if (eco ->> 'green_fee_min')::int > (eco ->> 'green_fee_max')::int then return 'green_fee_min is above green_fee_max'; end if;

  ev := c -> 'events';
  if not public.mh__keys_ok(ev, array['random_event_per_day_permille','commission_offer_per_day_permille','event_cash_scale_pct'],
                            array[]::text[]) then return 'events keys are wrong'; end if;
  if not public.mh__int_in(ev, 'random_event_per_day_permille', 0, 500) then return 'random_event_per_day_permille must be 0 to 500'; end if;
  if not public.mh__int_in(ev, 'commission_offer_per_day_permille', 0, 500) then return 'commission_offer_per_day_permille must be 0 to 500'; end if;
  if not public.mh__int_in(ev, 'event_cash_scale_pct', 25, 400) then return 'event_cash_scale_pct must be 25 to 400'; end if;
  return null;
end $$;

create or replace function public.mh__remote_config_guard() returns trigger
language plpgsql set search_path = '' as $$
declare msg text;
begin
  msg := public.mh_validate_remote_config(new.config);
  if msg is not null then raise exception 'invalid remote config: %', msg using errcode = '22023'; end if;
  if (new.config ->> 'config_version')::int is distinct from new.config_version then
    raise exception 'invalid remote config: config_version inside the JSON must equal the row version' using errcode = '22023';
  end if;
  return new;
end $$;

create trigger remote_config_guard before insert or update of config, config_version on public.remote_config_versions
  for each row execute function public.mh__remote_config_guard();

-- ---------------------------------------------------------------------------------------------------------------
-- Row level security: anyone with the app key may READ the active config. Nobody may write from the app.
-- ---------------------------------------------------------------------------------------------------------------
alter table public.remote_config_versions enable row level security;
revoke all on table public.remote_config_versions from anon, authenticated;
grant select on table public.remote_config_versions to anon, authenticated;
create policy remote_config_read_active on public.remote_config_versions
  for select to anon, authenticated using (is_active);

-- ---------------------------------------------------------------------------------------------------------------
-- Admin helpers. Run them in the Supabase SQL Editor (it runs as the owner). The app can never call them.
-- ---------------------------------------------------------------------------------------------------------------

-- Publish a whole new config. config_version and issued_unix are set for you.
create or replace function public.mh_publish_remote_config(p_config jsonb, p_note text default null) returns integer
language plpgsql security definer set search_path = '' as $$
declare nextv integer; cfg jsonb;
begin
  select coalesce(max(config_version), 0) + 1 into nextv from public.remote_config_versions;
  cfg := p_config || jsonb_build_object('config_version', nextv, 'issued_unix', floor(extract(epoch from now()))::bigint);
  update public.remote_config_versions set is_active = false where is_active;
  insert into public.remote_config_versions (config_version, config, is_active, note)
    values (nextv, cfg, true, p_note);
  return nextv;
end $$;

-- Flip one kill switch. true = feature ON, false = feature OFF.
create or replace function public.mh_set_kill_switch(p_name text, p_on boolean, p_note text default null) returns integer
language plpgsql security definer set search_path = '' as $$
declare cur jsonb;
begin
  select config into cur from public.remote_config_versions where is_active;
  if cur is null then raise exception 'no active remote config'; end if;
  if not (cur -> 'kill_switches' ? p_name) then
    raise exception 'unknown kill switch %. Valid: cloud_sync, daily_challenge, analytics, purchase_flow, tournaments, notifications', p_name;
  end if;
  return public.mh_publish_remote_config(
    jsonb_set(cur, array['kill_switches', p_name], to_jsonb(p_on)),
    coalesce(p_note, 'kill switch ' || p_name || ' = ' || p_on::text));
end $$;

-- Go back to the config that was active before the current one (publishes it again as a NEW version number).
create or replace function public.mh_rollback_remote_config() returns integer
language plpgsql security definer set search_path = '' as $$
declare cur integer; prev jsonb;
begin
  select config_version into cur from public.remote_config_versions where is_active;
  select config into prev from public.remote_config_versions where config_version < cur order by config_version desc limit 1;
  if prev is null then raise exception 'there is no earlier config to roll back to'; end if;
  return public.mh_publish_remote_config(prev, 'rollback from version ' || cur);
end $$;

revoke all on function public.mh__int_in(jsonb, text, bigint, bigint) from public, anon, authenticated;
revoke all on function public.mh__keys_ok(jsonb, text[], text[]) from public, anon, authenticated;
revoke all on function public.mh_validate_remote_config(jsonb) from public, anon, authenticated;
revoke all on function public.mh_publish_remote_config(jsonb, text) from public, anon, authenticated;
revoke all on function public.mh_set_kill_switch(text, boolean, text) from public, anon, authenticated;
revoke all on function public.mh_rollback_remote_config() from public, anon, authenticated;
grant execute on function public.mh_validate_remote_config(jsonb) to service_role;
grant execute on function public.mh_publish_remote_config(jsonb, text) to service_role;
grant execute on function public.mh_set_kill_switch(text, boolean, text) to service_role;
grant execute on function public.mh_rollback_remote_config() to service_role;

-- ---------------------------------------------------------------------------------------------------------------
-- First config: the same numbers as docs/spec/data/remote_config.example.json. All six features ON.
-- (analytics being ON here only means the SERVER accepts events; the player still has to opt in, DEC-057.)
-- ---------------------------------------------------------------------------------------------------------------
select public.mh_publish_remote_config(jsonb_build_object(
  'schema', 'mh.remote_config',
  'schema_version', 1,
  'config_version', 1,
  'issued_unix', 0,
  'min_app_version', '0.1.0',
  'kill_switches', jsonb_build_object(
    'cloud_sync', true, 'daily_challenge', true, 'analytics', true,
    'purchase_flow', true, 'tournaments', true, 'notifications', true),
  'economy', jsonb_build_object(
    'cost_multiplier_x100', jsonb_build_array(100, 200, 400, 800, 1400),
    'building_cost_scale_pct', 100, 'parcel_base_cost', 25000, 'parcel_growth_pct', 130,
    'hole_cost', 8000, 'start_cash', 40000, 'green_fee_min', 5, 'green_fee_max', 250),
  'events', jsonb_build_object(
    'random_event_per_day_permille', 60, 'commission_offer_per_day_permille', 40, 'event_cash_scale_pct', 100)
), 'initial config');

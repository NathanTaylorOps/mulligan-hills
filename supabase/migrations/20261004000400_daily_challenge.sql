-- Mulligan Hills: daily challenge leaderboard (DEC-012, DEC-016, DEC-029, DEC-036, DEC-059).
--
-- Trust model (DEC-036): the server does bounds and rate checks only; it does not re-simulate. Scores are claims
-- from the client. The checks here are cheap fences, not proof: score range, only today (or yesterday UTC, for a
-- late submit across midnight), attempt limit per day, minimum gap between submits, engine version format.
-- Names are presets only (DEC-016, DEC-043): the leaderboard shows `name_preset_id`, never free text.
-- The game can switch this off with the remote kill switch `daily_challenge` (the Edge Function checks it).

create table public.daily_scores (
  day                 integer     not null check (day between 0 and 100000),   -- UTC day number: floor(unix / 86400)
  user_id             uuid        not null references auth.users (id) on delete cascade,
  best_score_pm       smallint    not null check (best_score_pm between 0 and 1000),   -- rating engine score_pm, 0..1000
  attempts            smallint    not null default 1 check (attempts between 1 and 10),
  name_preset_id      smallint    not null check (name_preset_id between 0 and 999),
  template_id         text        not null check (template_id ~ '^[a-z][a-z0-9_]{1,39}$'),
  rating_version      text        not null check (rating_version ~ '^MHRATE-[0-9]+\.[0-9]+\.[0-9]+$'),
  sim_version         text        not null check (sim_version ~ '^MHSIM-[0-9]+\.[0-9]+\.[0-9]+$'),
  content_hash        text        check (content_hash ~ '^[0-9a-f]{8,64}$'),
  app_version         text        not null check (app_version ~ '^[0-9]+\.[0-9]+\.[0-9]+$'),
  first_submitted_at  timestamptz not null default now(),
  best_at             timestamptz not null default now(),
  last_submit_at      timestamptz not null default now(),
  primary key (day, user_id)
);
create index daily_scores_rank_idx on public.daily_scores (day, best_score_pm desc, best_at asc);

alter table public.daily_scores enable row level security;
revoke all on table public.daily_scores from anon, authenticated;
-- No policy on purpose: reading goes through daily_leaderboard (no user ids leave the database), writing through
-- daily_submit (service role only).

create or replace function public.mh_utc_day(p_now timestamptz default now()) returns integer
language sql immutable set search_path = '' as $$
  select floor(extract(epoch from p_now) / 86400)::int;
$$;

create or replace function public.daily_submit(
  p_user uuid, p_day int, p_score_pm int, p_name_preset int, p_template text,
  p_rating_version text, p_sim_version text, p_content_hash text, p_app_version text,
  p_max_attempts int default 3, p_min_interval_s int default 5, p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  today int := public.mh_utc_day(p_now);
  r public.daily_scores;
  improved boolean := false;
begin
  if p_day is null or p_day not between today - 1 and today then
    return jsonb_build_object('status', 'bad_day', 'today', today);
  end if;
  if p_score_pm is null or p_score_pm not between 0 and 1000 then return jsonb_build_object('status', 'bad_score'); end if;

  select * into r from public.daily_scores where day = p_day and user_id = p_user for update;
  if not found then
    insert into public.daily_scores (day, user_id, best_score_pm, attempts, name_preset_id, template_id, rating_version,
                                     sim_version, content_hash, app_version, first_submitted_at, best_at, last_submit_at)
    values (p_day, p_user, p_score_pm, 1, p_name_preset, p_template, p_rating_version, p_sim_version, p_content_hash,
            p_app_version, p_now, p_now, p_now)
    on conflict (day, user_id) do nothing;
    if found then
      return jsonb_build_object('status', 'ok', 'attempts', 1, 'best_score_pm', p_score_pm, 'improved', true);
    end if;
    select * into r from public.daily_scores where day = p_day and user_id = p_user for update;  -- lost a race
  end if;

  if r.attempts >= p_max_attempts then
    return jsonb_build_object('status', 'attempts_exhausted', 'attempts', r.attempts, 'best_score_pm', r.best_score_pm);
  end if;
  if p_now - r.last_submit_at < make_interval(secs => p_min_interval_s) then
    return jsonb_build_object('status', 'too_fast', 'attempts', r.attempts, 'best_score_pm', r.best_score_pm);
  end if;

  improved := p_score_pm > r.best_score_pm;
  update public.daily_scores set
    attempts = r.attempts + 1,
    last_submit_at = p_now,
    name_preset_id = p_name_preset,
    best_score_pm = case when improved then p_score_pm else r.best_score_pm end,
    best_at = case when improved then p_now else r.best_at end,
    template_id = case when improved then p_template else r.template_id end,
    rating_version = case when improved then p_rating_version else r.rating_version end,
    sim_version = case when improved then p_sim_version else r.sim_version end,
    content_hash = case when improved then p_content_hash else r.content_hash end,
    app_version = case when improved then p_app_version else r.app_version end
  where day = p_day and user_id = p_user
  returning * into r;
  return jsonb_build_object('status', 'ok', 'attempts', r.attempts, 'best_score_pm', r.best_score_pm, 'improved', improved);
end $$;

-- Top N for a day, plus the caller's own rank. Ties: the earlier best score ranks higher.
create or replace function public.daily_leaderboard(p_user uuid, p_day int, p_limit int default 50) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  lim int := least(greatest(coalesce(p_limit, 50), 1), 100);
  result jsonb;
begin
  with ranked as (
    select row_number() over (order by best_score_pm desc, best_at asc, user_id) as rank,
           user_id, name_preset_id, best_score_pm
      from public.daily_scores where day = p_day)
  select jsonb_build_object(
    'day', p_day,
    'total', (select count(*) from ranked),
    'top', coalesce((select jsonb_agg(jsonb_build_object('rank', rank, 'name_preset_id', name_preset_id,
                       'score_pm', best_score_pm, 'is_me', user_id = p_user) order by rank)
                       from ranked where rank <= lim), '[]'::jsonb),
    'me', (select jsonb_build_object('rank', rank, 'name_preset_id', name_preset_id, 'score_pm', best_score_pm)
             from ranked where user_id = p_user))
  into result;
  return result;
end $$;

create or replace function public.daily_purge(p_keep_days int default 30) returns integer
language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  delete from public.daily_scores where day < public.mh_utc_day() - p_keep_days;
  get diagnostics n = row_count;
  return n;
end $$;

revoke all on function public.mh_utc_day(timestamptz) from public, anon, authenticated;
revoke all on function public.daily_submit(uuid, int, int, int, text, text, text, text, text, int, int, timestamptz) from public, anon, authenticated;
revoke all on function public.daily_leaderboard(uuid, int, int) from public, anon, authenticated;
revoke all on function public.daily_purge(int) from public, anon, authenticated;
grant execute on function public.mh_utc_day(timestamptz) to service_role;
grant execute on function public.daily_submit(uuid, int, int, int, text, text, text, text, text, int, int, timestamptz) to service_role;
grant execute on function public.daily_leaderboard(uuid, int, int) to service_role;
grant execute on function public.daily_purge(int) to service_role;

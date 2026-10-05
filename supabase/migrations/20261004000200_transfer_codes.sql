-- Mulligan Hills: typed transfer codes (DEC-012) and the web account-deletion path (DEC-031).
--
-- A player with an anonymous account asks the app for a code. The code is 12 characters from a 32 character
-- alphabet (60 bits), valid for 15 minutes, shown once. The database stores only sha256(code), never the code.
-- Typing the code on another device lets THAT device copy the saves across (claim), or lets the owner delete
-- the account from a web page. The code never moves the anonymous identity itself, and it never carries the unlock
-- (the unlock belongs to the Google or Apple account, DEC-030: the new device presses Restore).

create table public.transfer_codes (
  code_hash   text        primary key check (code_hash ~ '^[0-9a-f]{64}$'),
  user_id     uuid        not null references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null,
  used_at     timestamptz
);
create index transfer_codes_user_idx on public.transfer_codes (user_id);

alter table public.transfer_codes enable row level security;
revoke all on table public.transfer_codes from anon, authenticated;
-- no policies: only the service role (Edge Function `account`) touches this table.

-- Create a code. Replaces any older code of the same user. At most one new code per 10 seconds per user.
create or replace function public.transfer_code_create(p_user uuid, p_hash text, p_ttl_seconds int)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare last_created timestamptz;
begin
  if p_ttl_seconds is null or p_ttl_seconds not between 60 and 3600 then raise exception 'bad_ttl'; end if;
  select max(created_at) into last_created from public.transfer_codes where user_id = p_user;
  if last_created is not null and last_created > now() - interval '10 seconds' then
    return jsonb_build_object('status', 'too_fast');
  end if;
  delete from public.transfer_codes where user_id = p_user;
  insert into public.transfer_codes (code_hash, user_id, expires_at)
    values (p_hash, p_user, now() + make_interval(secs => p_ttl_seconds));
  return jsonb_build_object('status', 'ok', 'expires_in', p_ttl_seconds);
end $$;

-- Look a code up without using it (the "who owns these saves" preview).
create or replace function public.transfer_code_peek(p_hash text) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select jsonb_build_object('status', 'ok', 'user_id', user_id)
       from public.transfer_codes where code_hash = p_hash and used_at is null and expires_at > now()),
    jsonb_build_object('status', 'invalid'));
$$;

-- Use a code exactly once.
create or replace function public.transfer_code_consume(p_hash text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid;
begin
  update public.transfer_codes set used_at = now()
   where code_hash = p_hash and used_at is null and expires_at > now()
   returning user_id into uid;
  if uid is null then return jsonb_build_object('status', 'invalid'); end if;
  return jsonb_build_object('status', 'ok', 'user_id', uid);
end $$;

revoke all on function public.transfer_code_create(uuid, text, int) from public, anon, authenticated;
revoke all on function public.transfer_code_peek(text) from public, anon, authenticated;
revoke all on function public.transfer_code_consume(text) from public, anon, authenticated;
grant execute on function public.transfer_code_create(uuid, text, int) to service_role;
grant execute on function public.transfer_code_peek(text) to service_role;
grant execute on function public.transfer_code_consume(text) to service_role;

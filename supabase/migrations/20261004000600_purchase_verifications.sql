-- Mulligan Hills: purchase token reuse counter (closes the "Known gap" in supabase/functions/README.md).
--
-- verify-purchase is anonymous: the unlock belongs to the store receipt, not to a Supabase account (DEC-030).
-- To notice one purchase token being replayed on many devices we keep ONLY a hash of the token, the Google order
-- id, and a counter. A normal player verifies a handful of times (install, reinstall, new phone). The function
-- refuses above a limit (secret PURCHASE_MAX_VERIFICATIONS_30D, default 10).

create table public.purchase_verifications (
  token_hash    text        primary key check (token_hash ~ '^[0-9a-f]{64}$'),   -- sha256 of the purchase token
  product_id    text        not null,
  order_id      text,
  is_test       boolean     not null default false,
  first_seen    timestamptz not null default now(),
  last_seen     timestamptz not null default now(),
  verify_count  integer     not null default 1       -- verifications since window_start
);
alter table public.purchase_verifications enable row level security;
revoke all on table public.purchase_verifications from anon, authenticated;

create or replace function public.purchase_verification_record(
  p_hash text, p_product text, p_order text, p_test boolean, p_window_days int default 30) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.purchase_verifications;
begin
  insert into public.purchase_verifications (token_hash, product_id, order_id, is_test)
    values (p_hash, p_product, nullif(p_order, ''), coalesce(p_test, false))
  on conflict (token_hash) do update set
    verify_count = case when public.purchase_verifications.last_seen < now() - make_interval(days => p_window_days)
                        then 1 else public.purchase_verifications.verify_count + 1 end,
    last_seen = now()
  returning * into r;
  return jsonb_build_object('count', r.verify_count, 'first_seen', r.first_seen);
end $$;

create or replace function public.purchase_verifications_purge(p_keep_days int default 400) returns integer
language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  delete from public.purchase_verifications where last_seen < now() - make_interval(days => p_keep_days);
  get diagnostics n = row_count;
  return n;
end $$;

revoke all on function public.purchase_verification_record(text, text, text, boolean, int) from public, anon, authenticated;
revoke all on function public.purchase_verifications_purge(int) from public, anon, authenticated;
grant execute on function public.purchase_verification_record(text, text, text, boolean, int) to service_role;
grant execute on function public.purchase_verifications_purge(int) to service_role;

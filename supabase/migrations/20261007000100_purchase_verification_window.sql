-- Mulligan Hills: make purchase verification throttling use a fixed window start.
-- The original counter compared against last_seen, which moved on every verification and could therefore
-- keep an actively used purchase token in the same window forever.

alter table public.purchase_verifications
  add column if not exists window_started_at timestamptz;

update public.purchase_verifications
   set window_started_at = first_seen
 where window_started_at is null;

alter table public.purchase_verifications
  alter column window_started_at set default now(),
  alter column window_started_at set not null;

create or replace function public.purchase_verification_record(
  p_hash text, p_product text, p_order text, p_test boolean, p_window_days int default 30) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.purchase_verifications;
begin
  insert into public.purchase_verifications (token_hash, product_id, order_id, is_test, window_started_at)
    values (p_hash, p_product, nullif(p_order, ''), coalesce(p_test, false), now())
  on conflict (token_hash) do update set
    verify_count = case
      when public.purchase_verifications.window_started_at < now() - make_interval(days => p_window_days)
        then 1
      else public.purchase_verifications.verify_count + 1
    end,
    window_started_at = case
      when public.purchase_verifications.window_started_at < now() - make_interval(days => p_window_days)
        then now()
      else public.purchase_verifications.window_started_at
    end,
    last_seen = now()
  returning * into r;
  return jsonb_build_object(
    'count', r.verify_count,
    'first_seen', r.first_seen,
    'window_started_at', r.window_started_at);
end $$;

revoke all on function public.purchase_verification_record(text, text, text, boolean, int) from public, anon, authenticated;
grant execute on function public.purchase_verification_record(text, text, text, boolean, int) to service_role;

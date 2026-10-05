-- Mulligan Hills: cloud saves (DEC-012, DEC-058).
--
-- Rules this schema enforces:
--   * The server NEVER picks a winner between a local and a cloud save. Every write is a compare-and-swap on
--     `version`: the client says which cloud version it last saw. If that is not the current version the server
--     answers "conflict" and changes nothing. The game then asks the player (DEC-058). There is no "latest wins".
--   * Save bytes live in a PRIVATE Storage bucket; this table holds only the pointer and a small summary
--     (day, cash, holes, play time) so the conflict prompt can show both sides without downloading anything.
--   * Clients get read access to their own rows only. All writes go through the service-role functions below,
--     which are called by the `cloud-save` and `account` Edge Functions.
--   * A save never carries the paid unlock (SAVE_MIGRATION.md). Nothing here reads or writes entitlements.

-- ---------------------------------------------------------------------------------------------------------------
-- Storage bucket (private, size capped). 8 MiB default cap; raise it in step with CLOUD_SAVE_MAX_BYTES (Edge secret).
-- ---------------------------------------------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit)
values ('cloud-saves', 'cloud-saves', false, 8388608)
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit;
-- No policies are created on storage.objects on purpose: with row level security on and no policy, browsers and
-- the game client cannot touch the bucket. Only signed URLs minted by the Edge Function (service role) work.

create table public.cloud_saves (
  user_id       uuid        not null references auth.users (id) on delete cascade,
  slot          smallint    not null check (slot between 0 and 4),
  version       integer     not null default 0 check (version >= 0),   -- 0 = no cloud save in this slot yet
  storage_path  text,
  sha256        text        check (sha256 ~ '^[0-9a-f]{64}$'),
  size_bytes    integer     check (size_bytes between 1 and 33554432),
  summary       jsonb       not null default '{}'::jsonb
                            check (jsonb_typeof(summary) = 'object' and pg_column_size(summary) <= 2048),
  pending_path  text,                                                  -- an upload in flight (at most one per slot)
  pending_at    timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  primary key (user_id, slot),
  check ((version = 0 and storage_path is null)
      or (version > 0 and storage_path is not null and sha256 is not null and size_bytes is not null))
);

comment on table public.cloud_saves is
  'One row per player and save slot. version is bumped on every successful upload. See migration header.';

alter table public.cloud_saves enable row level security;
revoke all on table public.cloud_saves from anon, authenticated;
grant select on table public.cloud_saves to authenticated;   -- anonymous sign-ins also use the authenticated role

create policy cloud_saves_select_own on public.cloud_saves
  for select to authenticated
  using (user_id = (select auth.uid()));
-- No insert/update/delete policy: clients cannot write. (service_role bypasses RLS.)

create or replace function public.mh_touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;

create trigger cloud_saves_touch before update on public.cloud_saves
  for each row execute function public.mh_touch_updated_at();

-- JSON view of a row, used in every answer so the client always sees the same shape.
create or replace function public.mh_cloud_row_json(r public.cloud_saves) returns jsonb
language sql immutable set search_path = '' as $$
  select jsonb_build_object(
    'slot', r.slot, 'version', r.version, 'sha256', r.sha256, 'size_bytes', r.size_bytes,
    'summary', r.summary, 'updated_at', r.updated_at);
$$;

-- ---------------------------------------------------------------------------------------------------------------
-- begin: reserve an upload. Fails with status 'conflict' unless p_expected equals the current cloud version.
-- ---------------------------------------------------------------------------------------------------------------
create or replace function public.cloud_save_begin(p_user uuid, p_slot int, p_expected int, p_new_path text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  r public.cloud_saves;
  old_pending text;
begin
  if p_slot is null or p_slot not between 0 and 4 then raise exception 'bad_slot'; end if;
  if p_expected is null or p_expected < 0 then raise exception 'bad_expected_version'; end if;
  insert into public.cloud_saves (user_id, slot) values (p_user, p_slot) on conflict do nothing;
  select * into r from public.cloud_saves where user_id = p_user and slot = p_slot for update;
  if r.version <> p_expected then
    return jsonb_build_object('status', 'conflict', 'cloud', public.mh_cloud_row_json(r));
  end if;
  old_pending := r.pending_path;
  update public.cloud_saves set pending_path = p_new_path, pending_at = now()
   where user_id = p_user and slot = p_slot;
  return jsonb_build_object('status', 'ok', 'version', r.version, 'discard_path', old_pending);
end $$;

-- ---------------------------------------------------------------------------------------------------------------
-- commit: finish an upload. Same compare-and-swap. The pending path must be the one begin reserved.
-- ---------------------------------------------------------------------------------------------------------------
create or replace function public.cloud_save_commit(
  p_user uuid, p_slot int, p_expected int, p_path text, p_sha256 text, p_size int, p_summary jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  r public.cloud_saves;
  old_path text;
begin
  select * into r from public.cloud_saves where user_id = p_user and slot = p_slot for update;
  if not found then
    return jsonb_build_object('status', 'stale_upload', 'discard_path', p_path);
  end if;
  if r.version <> p_expected then
    return jsonb_build_object('status', 'conflict', 'cloud', public.mh_cloud_row_json(r), 'discard_path', p_path);
  end if;
  if r.pending_path is distinct from p_path then
    return jsonb_build_object('status', 'stale_upload', 'cloud', public.mh_cloud_row_json(r), 'discard_path', p_path);
  end if;
  old_path := r.storage_path;
  update public.cloud_saves
     set version = r.version + 1, storage_path = p_path, sha256 = p_sha256, size_bytes = p_size,
         summary = coalesce(p_summary, '{}'::jsonb), pending_path = null, pending_at = null
   where user_id = p_user and slot = p_slot
   returning * into r;
  return jsonb_build_object('status', 'ok', 'cloud', public.mh_cloud_row_json(r), 'discard_path', old_path);
end $$;

-- list: only slots that hold a save; includes the storage path (service role only) so the function can sign a URL.
create or replace function public.cloud_save_list(p_user uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(public.mh_cloud_row_json(c) || jsonb_build_object('storage_path', c.storage_path)
                            order by c.slot), '[]'::jsonb)
    from public.cloud_saves c where c.user_id = p_user and c.version > 0;
$$;

-- delete one slot. Returns the object paths the caller must remove from Storage.
create or replace function public.cloud_save_delete(p_user uuid, p_slot int) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.cloud_saves;
begin
  delete from public.cloud_saves where user_id = p_user and slot = p_slot returning * into r;
  if not found then return jsonb_build_object('status', 'not_found', 'discard_paths', '[]'::jsonb); end if;
  return jsonb_build_object('status', 'ok',
    'discard_paths', to_jsonb(array_remove(array[r.storage_path, r.pending_path], null)));
end $$;

-- every object path a user owns (for account deletion).
create or replace function public.cloud_save_all_paths(p_user uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(p), '[]'::jsonb) from (
    select storage_path as p from public.cloud_saves where user_id = p_user and storage_path is not null
    union all
    select pending_path from public.cloud_saves where user_id = p_user and pending_path is not null) t;
$$;

-- import: used by "claim with transfer code". Writes an already-copied object as the next version of a slot.
-- Never overwrites silently: if the slot holds a save and p_overwrite is false the answer is 'conflict'.
create or replace function public.cloud_save_import(
  p_user uuid, p_slot int, p_path text, p_sha256 text, p_size int, p_summary jsonb, p_overwrite boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare r public.cloud_saves; old_path text;
begin
  if p_slot is null or p_slot not between 0 and 4 then raise exception 'bad_slot'; end if;
  insert into public.cloud_saves (user_id, slot) values (p_user, p_slot) on conflict do nothing;
  select * into r from public.cloud_saves where user_id = p_user and slot = p_slot for update;
  if r.version > 0 and not coalesce(p_overwrite, false) then
    return jsonb_build_object('status', 'conflict', 'cloud', public.mh_cloud_row_json(r), 'discard_path', p_path);
  end if;
  old_path := r.storage_path;
  update public.cloud_saves
     set version = r.version + 1, storage_path = p_path, sha256 = p_sha256, size_bytes = p_size,
         summary = coalesce(p_summary, '{}'::jsonb)
   where user_id = p_user and slot = p_slot returning * into r;
  return jsonb_build_object('status', 'ok', 'cloud', public.mh_cloud_row_json(r), 'discard_path', old_path);
end $$;

revoke all on function public.cloud_save_begin(uuid, int, int, text) from public, anon, authenticated;
revoke all on function public.cloud_save_commit(uuid, int, int, text, text, int, jsonb) from public, anon, authenticated;
revoke all on function public.cloud_save_list(uuid) from public, anon, authenticated;
revoke all on function public.cloud_save_delete(uuid, int) from public, anon, authenticated;
revoke all on function public.cloud_save_all_paths(uuid) from public, anon, authenticated;
revoke all on function public.cloud_save_import(uuid, int, text, text, int, jsonb, boolean) from public, anon, authenticated;
grant execute on function public.cloud_save_begin(uuid, int, int, text) to service_role;
grant execute on function public.cloud_save_commit(uuid, int, int, text, text, int, jsonb) to service_role;
grant execute on function public.cloud_save_list(uuid) to service_role;
grant execute on function public.cloud_save_delete(uuid, int) to service_role;
grant execute on function public.cloud_save_all_paths(uuid) to service_role;
grant execute on function public.cloud_save_import(uuid, int, text, text, int, jsonb, boolean) to service_role;

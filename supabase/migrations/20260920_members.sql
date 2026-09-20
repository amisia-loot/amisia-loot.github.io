-- Raider and Trial ranks: the owner links an account that signed in to a character of the roster.
-- A linked member may set that character's professions; they live here, not in the ledger JSON,
-- so a member's change never collides with an editor's unsaved ledger draft.
create table public.members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  raider text not null unique check (raider ~ '^[A-Za-z0-9_-]{1,40}$'),
  rank text not null check (rank in ('raider', 'trial')),
  profs text[] check (profs is null or coalesce(array_length(profs, 1), 0) <= 2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.members enable row level security;
create policy "members readable by everyone" on public.members for select using (true);
create policy "owner links members" on public.members for insert to authenticated with check (public.is_owner());
create policy "owner changes members" on public.members for update to authenticated using (public.is_owner()) with check (public.is_owner());
create policy "owner unlinks members" on public.members for delete to authenticated using (public.is_owner());
revoke all on public.members from anon, authenticated;
grant select on public.members to anon, authenticated;
grant insert, update, delete on public.members to authenticated;
alter publication supabase_realtime add table public.members;

-- Professions of a linked character: the member themself, or an editor.
create or replace function public.set_member_profs(p_raider text, p_profs text[])
returns void language plpgsql security definer set search_path = public as $$
declare clean text[];
begin
  select coalesce(array_agg(distinct x), '{}') into clean from unnest(coalesce(p_profs, '{}')) x where x ~ '^[A-Za-z][A-Za-z '']{1,29}$';
  if coalesce(array_length(clean, 1), 0) > 2 then raise exception 'at most two professions' using errcode = '22023'; end if;
  update public.members m set profs = clean, updated_at = now()
    where m.raider = p_raider and (m.user_id = auth.uid() or public.is_editor());
  if not found then raise exception 'not your character' using errcode = '42501'; end if;
end $$;
revoke all on function public.set_member_profs(text, text[]) from public, anon;
grant execute on function public.set_member_profs(text, text[]) to authenticated;

-- The owner's account list needs the account id to link it.
drop function public.list_accounts();
create function public.list_accounts()
returns table(id uuid, name text, email text, provider text, last_sign_in timestamp with time zone, created timestamp with time zone, role text)
language sql stable security definer set search_path = public, auth as $$
  with u as (
    select u.*, array_remove(array[
      lower(coalesce(u.email, '')),
      lower(coalesce(u.raw_user_meta_data ->> 'name', '')),
      lower(coalesce(u.raw_user_meta_data ->> 'full_name', '')),
      lower(coalesce(u.raw_user_meta_data ->> 'preferred_username', '')),
      lower(coalesce(u.raw_user_meta_data -> 'custom_claims' ->> 'global_name', '')),
      lower(coalesce(u.raw_user_meta_data ->> 'provider_id', ''))
    ], '') as idents
    from auth.users u)
  select u.id,
         coalesce(u.raw_user_meta_data ->> 'name', u.raw_user_meta_data ->> 'full_name', ''),
         coalesce(u.email, ''),
         coalesce(u.raw_app_meta_data ->> 'provider', ''),
         u.last_sign_in_at, u.created_at,
         case when exists (select 1 from public.app_config c where lower(c.owner_email) = any(u.idents)) then 'owner'
              when exists (select 1 from public.editors e where lower(e.email) = any(u.idents)) then 'editor'
              else '' end
  from u
  where public.is_owner()
  order by u.last_sign_in_at desc nulls last;
$$;
revoke all on function public.list_accounts() from public, anon;
grant execute on function public.list_accounts() to authenticated;

-- Only the owner sees e-mail addresses. Everyone else sees names; who saved the ledger is stored as a user id.

-- The name of a signed-in account, never its e-mail address.
create or replace function public.display_name(p_uid uuid default auth.uid())
returns text language sql stable security definer set search_path = public, auth as $$
  select coalesce((
    select coalesce(nullif(u.raw_user_meta_data ->> 'name', ''), nullif(u.raw_user_meta_data ->> 'full_name', ''),
                    nullif(u.raw_user_meta_data ->> 'preferred_username', ''))
    from auth.users u where u.id = p_uid), 'Member');
$$;
revoke all on function public.display_name(uuid) from public, anon;
grant execute on function public.display_name(uuid) to authenticated;

-- editor list, owner address and raw history: owner only
drop policy if exists "editors readable by editors" on public.editors;
create policy "editors readable by the owner" on public.editors for select to authenticated using (public.is_owner());
drop policy if exists "config readable by signed-in users" on public.app_config;
create policy "config readable by the owner" on public.app_config for select to authenticated using (public.is_owner());
drop policy if exists "history readable by editors" on public.ledger_history;
create policy "history readable by the owner" on public.ledger_history for select to authenticated using (public.is_owner());
revoke execute on function public.list_accounts() from anon;

-- who saved: a user id instead of the e-mail address (the ledger row is readable by everyone)
create or replace function public.save_ledger(p_id text, p_state jsonb, p_version bigint)
returns table(version bigint, updated_at timestamp with time zone)
language plpgsql security definer set search_path = public as $$
declare v bigint;
begin
  if not public.is_editor() then
    raise exception 'not an editor' using errcode = '42501';
  end if;
  insert into public.ledgers (id, state, version, updated_by)
    values (p_id, p_state, 1, auth.uid()::text)
    on conflict (id) do update
      set state = excluded.state, version = public.ledgers.version + 1, updated_at = now(), updated_by = auth.uid()::text
      where public.ledgers.version = p_version;
  select l.version into v from public.ledgers l where l.id = p_id;
  if v is null or (v <> p_version + 1 and not (p_version = 0 and v = 1)) then
    raise exception 'conflict' using errcode = '40001';
  end if;
  return query select l.version, l.updated_at from public.ledgers l where l.id = p_id;
end $$;

create or replace function public.restore_ledger(p_id text, p_version bigint)
returns table(version bigint)
language plpgsql security definer set search_path = public as $$
declare s jsonb; v bigint;
begin
  if not public.is_editor() then raise exception 'not an editor' using errcode = '42501'; end if;
  select h.state into s from public.ledger_history h where h.ledger_id = p_id and h.version = p_version;
  if s is null then raise exception 'no such version' using errcode = '22023'; end if;
  update public.ledgers l set state = s, version = l.version + 1, updated_at = now(), updated_by = auth.uid()::text
    where l.id = p_id returning l.version into v;
  return query select v;
end $$;

update public.ledgers l set updated_by = u.id::text from auth.users u where l.updated_by like '%@%' and lower(u.email) = lower(l.updated_by);
update public.ledgers set updated_by = '' where updated_by like '%@%';
update public.ledger_history h set saved_by = u.id::text from auth.users u where h.saved_by like '%@%' and lower(u.email) = lower(h.saved_by);
update public.ledger_history set saved_by = '' where saved_by like '%@%';

-- history list: names for editors, name and address for the owner
create or replace function public.list_ledger_history(p_id text default 'main')
returns table(version bigint, saved_at timestamp with time zone, saved_by text, raiders integer, awards integer, nights integer, crafters integer)
language sql stable security definer set search_path = public, auth as $$
  select h.version, h.saved_at,
    case when u.id is null then ''
         when public.is_owner() then public.display_name(u.id) || ' · ' || coalesce(u.email, '')
         else public.display_name(u.id) end,
    case when jsonb_typeof(h.state->'raiders')  = 'array' then jsonb_array_length(h.state->'raiders')  else 0 end,
    case when jsonb_typeof(h.state->'awards')   = 'array' then jsonb_array_length(h.state->'awards')   else 0 end,
    case when jsonb_typeof(h.state->'nights')   = 'array' then jsonb_array_length(h.state->'nights')   else 0 end,
    case when jsonb_typeof(h.state->'crafters') = 'array' then jsonb_array_length(h.state->'crafters') else 0 end
  from public.ledger_history h
  left join auth.users u on u.id::text = h.saved_by
  where h.ledger_id = p_id and public.is_editor()
  order by h.version desc limit 40;
$$;

-- online list: the name comes from the account, not from the page
create or replace function public.touch_presence(p_sid text, p_name text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  insert into public.presence (sid, uid, name, role, last_seen)
    values (p_sid, auth.uid(), left(public.display_name(), 80), case when public.is_owner() then 'owner' when public.is_editor() then 'editor' else 'viewer' end, now())
    on conflict (sid) do update set name = excluded.name, role = excluded.role, last_seen = now(), uid = excluded.uid;
  delete from public.presence where last_seen < now() - interval '1 day';
end $$;
update public.presence p set name = public.display_name(p.uid) where p.name like '%@%';

-- material requests and wishes: the names of who asked, ticked or wished come from the account
create or replace function public.stamp_names()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'mat_requests' then
    if tg_op = 'INSERT' then
      new.requested_name := public.display_name();
    elsif new.requested_name is distinct from old.requested_name then
      new.requested_name := old.requested_name;
    end if;
    if coalesce(new.received_by, '') <> '' and (tg_op = 'INSERT' or new.received_by is distinct from old.received_by) then
      new.received_by := public.display_name();
    end if;
  elsif tg_table_name = 'wishlist' then
    if tg_op = 'INSERT' then
      new.created_name := public.display_name();
    elsif new.created_name is distinct from old.created_name then
      new.created_name := old.created_name;
    end if;
  end if;
  return new;
end $$;
revoke all on function public.stamp_names() from public, anon, authenticated;
drop trigger if exists mat_requests_names on public.mat_requests;
create trigger mat_requests_names before insert or update on public.mat_requests for each row execute function public.stamp_names();
drop trigger if exists wishlist_names on public.wishlist;
create trigger wishlist_names before insert or update on public.wishlist for each row execute function public.stamp_names();

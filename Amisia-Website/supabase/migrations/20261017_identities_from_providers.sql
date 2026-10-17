-- Who a signed-in account is, only from what the account cannot change itself (security audit
-- 2026-10-17): the confirmed e-mail of auth.users and the Discord identity of auth.identities (its
-- username "full_name", unique on Discord; its "name" username#discriminator; its id). Before, the
-- owner and editor checks also read user_metadata, which every signed-in account can rewrite with
-- auth.updateUser({ data }): anyone could have named themselves an editor or the owner. Never the
-- Discord display name (custom_claims.global_name): it is not unique.

create or replace function public.identities_of(p_uid uuid)
returns text[]
language sql stable security definer set search_path = public, auth as $$
  select coalesce(array_agg(distinct v) filter (where v <> ''), '{}'::text[]) from (
    select lower(coalesce(u.email, '')) as v
      from auth.users u where u.id = p_uid and u.email_confirmed_at is not null
    union all
    select lower(coalesce(t.x, ''))
      from auth.identities i,
           lateral (values (i.identity_data ->> 'full_name'), (i.identity_data ->> 'name'), (i.provider_id)) as t(x)
      where i.user_id = p_uid and i.provider = 'discord'
  ) s;
$$;
revoke all on function public.identities_of(uuid) from public, anon, authenticated;

create or replace function public.my_identities()
returns text[]
language sql stable security definer set search_path = public as $$
  select case when auth.uid() is null then '{}'::text[] else public.identities_of(auth.uid()) end;
$$;
revoke all on function public.my_identities() from public, anon;
grant execute on function public.my_identities() to authenticated;

create or replace function public.current_email()
returns text
language sql stable security definer set search_path = public, auth as $$
  select lower(coalesce((select u.email from auth.users u where u.id = auth.uid() and u.email_confirmed_at is not null), ''));
$$;
revoke all on function public.current_email() from public, anon;
grant execute on function public.current_email() to authenticated;

-- The name shown in presence and history: the Discord display name or username, never user_metadata.
create or replace function public.display_name(p_uid uuid default auth.uid())
returns text
language sql stable security definer set search_path = public, auth as $$
  select coalesce((
    select coalesce(nullif(i.identity_data -> 'custom_claims' ->> 'global_name', ''), nullif(i.identity_data ->> 'full_name', ''))
      from auth.identities i where i.user_id = p_uid and i.provider = 'discord'
      order by i.last_sign_in_at desc nulls last limit 1), 'Member');
$$;

-- The owner's account list: the role by the same identities as is_owner() / is_editor().
drop function public.list_accounts();
create function public.list_accounts()
returns table(id uuid, name text, email text, provider text, last_sign_in timestamp with time zone, created timestamp with time zone, role text)
language sql stable security definer set search_path = public, auth as $$
  with u as (select u.*, public.identities_of(u.id) as idents from auth.users u)
  select u.id,
         public.display_name(u.id),
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

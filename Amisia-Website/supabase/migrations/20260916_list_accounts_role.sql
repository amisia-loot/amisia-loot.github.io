-- The account list says who is owner or editor with the same identity rules as is_owner() / is_editor().
drop function public.list_accounts();
create function public.list_accounts()
returns table(name text, email text, provider text, last_sign_in timestamp with time zone, created timestamp with time zone, role text)
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
  select coalesce(u.raw_user_meta_data ->> 'name', u.raw_user_meta_data ->> 'full_name', ''),
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

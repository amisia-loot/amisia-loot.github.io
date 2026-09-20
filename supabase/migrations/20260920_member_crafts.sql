-- Linked members list the recipes they can craft themselves.
alter table public.members add column crafts integer[] not null default '{}' check (coalesce(array_length(crafts, 1), 0) <= 600);
create or replace function public.set_member_craft(p_raider text, p_craft integer, p_on boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_craft is null or p_craft <= 0 then raise exception 'bad recipe' using errcode = '22023'; end if;
  update public.members m
    set crafts = case when p_on then (select array_agg(distinct x order by x) from unnest(m.crafts || p_craft) x) else array_remove(m.crafts, p_craft) end,
        updated_at = now()
    where m.raider = p_raider and (m.user_id = auth.uid() or public.is_editor());
  if not found then raise exception 'not your character' using errcode = '42501'; end if;
end $$;
revoke all on function public.set_member_craft(text, integer, boolean) from public, anon;
grant execute on function public.set_member_craft(text, integer, boolean) to authenticated;

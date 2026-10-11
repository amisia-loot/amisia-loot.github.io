-- Database linter clean-up: server functions only for signed-in users, fixed search paths, auth.uid() evaluated once per query.
revoke execute on function public.archive_ledger() from public, anon, authenticated;
revoke execute on function public.is_editor(), public.is_owner(), public.leave_presence(text), public.list_ledger_history(text), public.restore_ledger(text, bigint), public.save_ledger(text, jsonb, bigint), public.touch_presence(text, text) from public, anon;
grant execute on function public.is_editor(), public.is_owner(), public.leave_presence(text), public.list_ledger_history(text), public.restore_ledger(text, bigint), public.save_ledger(text, jsonb, bigint), public.touch_presence(text, text) to authenticated;
alter function public.current_email() set search_path = public;
alter function public.my_identities() set search_path = public;

drop policy "members add their own open requests, editors add anything" on public.mat_requests;
create policy "members add their own open requests, editors add anything" on public.mat_requests for insert to authenticated
  with check ((requested_by = (select auth.uid())) and (((kind = 'request') and (status = 'open')) or public.is_editor()));
drop policy "own open requests or editors delete" on public.mat_requests;
create policy "own open requests or editors delete" on public.mat_requests for delete to authenticated
  using (public.is_editor() or ((requested_by = (select auth.uid())) and (status = 'open')));
drop policy "signed-in members add wishes" on public.wishlist;
create policy "signed-in members add wishes" on public.wishlist for insert to authenticated with check (created_by = (select auth.uid()));
drop policy "own wishes or editors update" on public.wishlist;
create policy "own wishes or editors update" on public.wishlist for update to authenticated
  using ((created_by = (select auth.uid())) or public.is_editor()) with check ((created_by = (select auth.uid())) or public.is_editor());
drop policy "own wishes or editors delete" on public.wishlist;
create policy "own wishes or editors delete" on public.wishlist for delete to authenticated using ((created_by = (select auth.uid())) or public.is_editor());

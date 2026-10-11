-- Raider references are ledger ids (letters, digits, - and _), never markup.
alter table public.wishlist add constraint wishlist_raider_id check (raider ~ '^[A-Za-z0-9_-]{1,40}$');
alter table public.mat_requests add constraint mat_requests_raider_id check (raider is null or raider ~ '^[A-Za-z0-9_-]{1,40}$');

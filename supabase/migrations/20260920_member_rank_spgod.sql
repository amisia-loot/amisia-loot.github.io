-- The owner's special rank "SP God".
alter table public.members drop constraint members_rank_check;
alter table public.members add constraint members_rank_check check (rank in ('spgod', 'officer', 'raider', 'trial'));

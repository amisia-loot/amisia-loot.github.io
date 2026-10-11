-- Ranks for linked accounts: Officer, Raider, Trial (no Guild Master).
alter table public.members drop constraint members_rank_check;
alter table public.members add constraint members_rank_check check (rank in ('officer', 'raider', 'trial'));

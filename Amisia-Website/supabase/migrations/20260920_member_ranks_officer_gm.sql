-- Two more ranks for linked accounts: Guild Master and Officer.
alter table public.members drop constraint members_rank_check;
alter table public.members add constraint members_rank_check check (rank in ('gm', 'officer', 'raider', 'trial'));

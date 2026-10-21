-- Service records: every battle a signed-in player fights, as their game
-- reported it at the end. Only ever shown to that player.
create table if not exists public.battle_records (
	id uuid primary key default gen_random_uuid(),
	user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
	played_at timestamptz not null default now(),
	game_version text not null default '' check (char_length(game_version) <= 20),
	mode text not null check (mode in ('skirmish', 'coop', 'pvp', 'mission')),
	mission text not null default '' check (char_length(mission) <= 32),
	title text not null default '' check (char_length(title) <= 60),
	side smallint not null check (side in (0, 1)),
	result text not null check (result in ('victory', 'defeat')),
	duration_s integer not null default 0 check (duration_s >= 0),
	rating real not null default 0 check (rating between 0 and 100),
	score integer not null default 0,
	kills integer not null default 0,
	lost integer not null default 0,
	veh_kills integer not null default 0,
	veh_lost integer not null default 0,
	shots integer not null default 0,
	hits integer not null default 0,
	me jsonb not null default '{}'::jsonb,
	report jsonb not null default '{}'::jsonb check (pg_column_size(report) < 262144)
);

create index if not exists battle_records_user_played on public.battle_records (user_id, played_at desc);

alter table public.battle_records enable row level security;

drop policy if exists "Players read their own battles" on public.battle_records;
create policy "Players read their own battles" on public.battle_records
	for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "Players record their own battles" on public.battle_records;
create policy "Players record their own battles" on public.battle_records
	for insert to authenticated with check ((select auth.uid()) = user_id);

revoke all on public.battle_records from anon, authenticated;
grant select, insert on public.battle_records to authenticated;

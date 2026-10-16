-- Frontline accounts: Supabase Auth holds the users; this adds a callsign for
-- each. Run once in the Supabase SQL editor (or as a migration).
--
-- The matchmaker talks to Supabase with the public key only, acting as the
-- signed-in player, so row-level security is what keeps players to their own
-- profile.

create table if not exists public.profiles (
	id uuid primary key references auth.users (id) on delete cascade,
	callsign text not null check (callsign ~ '^[A-Za-z0-9 _.-]{3,20}$'),
	created_at timestamptz not null default now()
);

-- callsigns are unique regardless of case
create unique index if not exists profiles_callsign_key on public.profiles (lower(callsign));

alter table public.profiles enable row level security;

drop policy if exists "Players read their own profile" on public.profiles;
create policy "Players read their own profile" on public.profiles
	for select to authenticated using ((select auth.uid()) = id);

drop policy if exists "Players rename themselves" on public.profiles;
create policy "Players rename themselves" on public.profiles
	for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- the callsign is the only column a player may change
revoke insert, update, delete on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (callsign) on public.profiles to authenticated;

-- A profile for every new user, from the callsign given at sign-up. If the
-- callsign is malformed or taken, the sign-up fails as a whole.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
	insert into public.profiles (id, callsign)
	values (new.id, coalesce(nullif(trim(new.raw_user_meta_data ->> 'callsign'), ''), 'Commander-' || left(new.id::text, 6)));
	return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
	after insert on auth.users
	for each row execute function public.handle_new_user();

-- Lets the sign-up form say "taken" before creating the account. Callsigns
-- are public anyway (they're shown in the lobby list), so the linter's warning
-- about anon running a SECURITY DEFINER function is expected here: it answers
-- yes or no and nothing more. Only the not-yet-signed-in need it.
create or replace function public.callsign_taken(name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
	select exists (select 1 from public.profiles where lower(callsign) = lower(trim(name)));
$$;

revoke execute on function public.callsign_taken(text) from public;
revoke execute on function public.callsign_taken(text) from authenticated;
grant execute on function public.callsign_taken(text) to anon;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- Service records: every battle a signed-in player fights, as their game
-- reported it at the end (headline numbers for lists and career totals, and
-- the after-action report itself so it can be opened again). The figures are
-- the player's own word, so they're only ever shown to that player.
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

-- a battle, once on the record, stays as it was reported
revoke all on public.battle_records from anon, authenticated;
grant select, insert on public.battle_records to authenticated;

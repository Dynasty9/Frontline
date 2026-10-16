-- Frontline accounts: Supabase Auth holds the users; this adds a callsign for
-- each, and their rank and insignia. Run it in the Supabase SQL editor (or as a
-- migration). It's safe to run again, and running it again is how a database
-- set up before a change catches up.
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

-- Ranks (the ranks migration: run this file again on a database made before
-- it). Players earn XP from battles, climb from Recruit (rank 0) to rank 50,
-- and each rank unlocks an insignia they can wear. The same rules are in
-- matchmaker/src/ranks.js; keep the two in step.
--
-- There's no game server to referee a battle (players host them), so the game
-- reports its own result. What keeps XP honest is that players can't write it:
-- the grants above leave the callsign as the only column they may update, so
-- XP, the record and the battle clock change only through the functions below,
-- which run as the table's owner, act on the caller's own row and nothing
-- else, and time each battle on the database's clock. Calling Supabase's API
-- directly gets a player no further than the game does, and a modified game
-- can't claim more battle time than really passed.

-- The insignia worn (which ids exist, and who may wear them, is set_icon's
-- business), total XP, battles fought and won, and when the open battle began
-- (null with none open).
alter table public.profiles
	add column if not exists icon text not null default 's01' check (icon ~ '^[a-z][0-9]{2}$'),
	add column if not exists xp integer not null default 0 check (xp >= 0),
	add column if not exists battles integer not null default 0 check (battles >= 0),
	add column if not exists wins integer not null default 0 check (wins >= 0),
	add column if not exists battle_started_at timestamptz;

-- The rank for a total of XP: how many of the thresholds for ranks 1 to 50
-- (150r + 10r(r - 1): 150 for the first, 32,000 for the last) it has reached.
create or replace function public.frontline_rank(xp integer)
returns integer
language sql
immutable
set search_path = ''
as $$
	select count(*)::integer from generate_series(1, 50) r where 150 * r + 10 * r * (r - 1) <= xp;
$$;

-- The battle starts: the clock starts on our side. Starting again forfeits a
-- battle left open.
create or replace function public.begin_battle()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
	update public.profiles set battle_started_at = now() where id = (select auth.uid());
	if not found then
		raise exception 'Sign in first.' using errcode = 'PT401';
	end if;
end;
$$;

-- The battle ends ('win', 'loss' or 'left', and how many seconds of game time
-- it ran). The time it's worth is the shorter of that and how long our clock
-- had it open, at most 45 minutes, and under 2 it earns nothing. Then a point
-- per tenth of a minute, times 1.5 for a win, 1 for a loss and 0.5 for leaving.
-- A win or a loss counts towards the record. An end with no battle open is a
-- retry of one already counted (or a battle the clock never heard about), so
-- it earns and counts nothing. Either way the battle is closed.
create or replace function public.end_battle(result text, seconds double precision)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
	p public.profiles;
	counted boolean;
	tenths double precision;
	gained integer := 0;
	rank_before integer;
begin
	if result is null or result not in ('win', 'loss', 'left') then
		raise exception 'A battle ends in a "win", a "loss" or "left".' using errcode = 'PT400';
	end if;
	if seconds is null or seconds < 0 then
		raise exception 'Say how long the battle ran, in seconds.' using errcode = 'PT400';
	end if;
	select * into p from public.profiles where id = (select auth.uid()) for update;
	if not found then
		raise exception 'Sign in first.' using errcode = 'PT401';
	end if;
	rank_before := public.frontline_rank(p.xp);
	counted := p.battle_started_at is not null;
	if counted then
		tenths := floor(least(extract(epoch from now() - p.battle_started_at)::double precision, seconds, 2700) / 6);
		if tenths >= 20 then
			gained := floor(tenths * case result when 'win' then 1.5 when 'loss' then 1 else 0.5 end);
		end if;
	end if;
	update public.profiles set
		xp = xp + gained,
		battles = battles + case when counted and result <> 'left' then 1 else 0 end,
		wins = wins + case when counted and result = 'win' then 1 else 0 end,
		battle_started_at = null
	where id = p.id
	returning * into p;
	return json_build_object(
		'gained', gained, 'rank_before', rank_before, 'xp', p.xp, 'rank', public.frontline_rank(p.xp),
		'battles', p.battles, 'wins', p.wins, 'icon', p.icon, 'callsign', p.callsign);
end;
$$;

-- Wear an insignia: a starter (s01-s10), or the patch of a rank the player
-- has reached (r01-r50). Award and unit patches (m01-m50, u01-u50) can't be
-- earned yet. Unknown ids are refused with PT400 and locked ones with PT403,
-- which the API passes on as 400 and 403.
create or replace function public.set_icon(icon text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
	player_xp integer;
begin
	if icon is null or icon !~ '^(s(0[1-9]|10)|[rmu](0[1-9]|[1-4][0-9]|50))$' then
		raise exception 'No such insignia.' using errcode = 'PT400';
	end if;
	select p.xp into player_xp from public.profiles p where p.id = (select auth.uid());
	if not found then
		raise exception 'Sign in first.' using errcode = 'PT401';
	end if;
	if left(icon, 1) in ('m', 'u') or (left(icon, 1) = 'r' and public.frontline_rank(player_xp) < substr(icon, 2)::integer) then
		raise exception 'That insignia is locked.' using errcode = 'PT403';
	end if;
	update public.profiles set icon = set_icon.icon where id = (select auth.uid());
end;
$$;

-- Signed-in players only (Postgres lets everyone run a new function, and
-- Supabase grants anon too, unless told otherwise). The linter warns about
-- signed-in players running SECURITY DEFINER functions; that's the point of
-- these: each acts on the caller's own row, by the rules above.
revoke execute on function public.frontline_rank(integer) from public, anon;
revoke execute on function public.begin_battle() from public, anon;
revoke execute on function public.end_battle(text, double precision) from public, anon;
revoke execute on function public.set_icon(text) from public, anon;
grant execute on function public.frontline_rank(integer) to authenticated;
grant execute on function public.begin_battle() to authenticated;
grant execute on function public.end_battle(text, double precision) to authenticated;
grant execute on function public.set_icon(text) to authenticated;

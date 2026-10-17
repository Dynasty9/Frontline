-- Public profiles and leaderboards. Until now a player could read only their
-- own profile and battles. The website now shows everyone's: a profile page
-- per callsign (rank, record, the picture they've chosen and their battles,
-- after-action reports and all), and leaderboards of XP earned. A player can
-- hide their battles (hide_history); the rank, XP and record on their profile
-- stay public.
--
-- Nothing here opens a table to the world. Row-level security still keeps
-- every player to their own rows; what anyone may see goes through the
-- functions below, which run as the tables' owner and hand back the public
-- columns only (never an email address, which lives in auth.users anyway),
-- and never a hidden player (hidden: for moderation, set by hand).
--
-- XP is the trustworthy figure: only the database's own functions write it,
-- timed on its own clock (the ranks migration). The battle records are each
-- player's own game's word, so they're shown as theirs and never ranked.

-- --- what a player shows the world -----------------------------------------

-- avatar: their insignia (the default), or the picture on their GitHub
-- account. github_avatar is that picture's address, copied from what GitHub
-- told Supabase at sign-in; only GitHub's own image host is taken.
alter table public.profiles
	add column if not exists avatar text not null default 'insignia' check (avatar in ('insignia', 'github')),
	add column if not exists github_avatar text
		check (github_avatar is null or github_avatar ~ '^https://avatars\.githubusercontent\.com/[A-Za-z0-9/_.?=&%-]{1,200}$'),
	add column if not exists hide_history boolean not null default false,
	add column if not exists hidden boolean not null default false;

-- a player picks their picture and hides their battles themselves; the rest
-- (hidden above all) isn't theirs to change
grant update (avatar, hide_history) on public.profiles to authenticated;

-- GitHub's picture for a user, from what Supabase keeps of their GitHub
-- account, or null if it isn't one of GitHub's
create or replace function public.github_avatar_of(meta jsonb)
returns text
language sql
immutable
set search_path = ''
as $$
	select case
		when meta ->> 'avatar_url' ~ '^https://avatars\.githubusercontent\.com/[A-Za-z0-9/_.?=&%-]{1,200}$' then meta ->> 'avatar_url'
	end;
$$;

-- A new player's profile, as before (github_callsigns), with their GitHub
-- picture.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
	typed text := nullif(trim(new.raw_user_meta_data ->> 'callsign'), '');
	base text;
	pick text;
	n integer := 1;
begin
	if typed is not null then
		insert into public.profiles (id, callsign, github_avatar) values (new.id, typed, public.github_avatar_of(new.raw_user_meta_data));
		return new;
	end if;
	base := left(regexp_replace(coalesce(new.raw_user_meta_data ->> 'user_name', new.raw_user_meta_data ->> 'preferred_username', ''), '[^A-Za-z0-9_.-]', '', 'g'), 20);
	if length(base) < 3 then
		base := 'Commander-' || left(new.id::text, 6);
	end if;
	pick := base;
	while exists (select 1 from public.profiles where lower(callsign) = lower(pick)) loop
		n := n + 1;
		pick := left(base, 19 - length(n::text)) || '-' || n;
	end loop;
	insert into public.profiles (id, callsign, github_avatar) values (new.id, pick, public.github_avatar_of(new.raw_user_meta_data));
	return new;
end;
$$;

-- Supabase refreshes what it knows of a GitHub account at every sign-in: a
-- new picture on GitHub becomes the new picture here.
create or replace function public.handle_user_updated()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
	update public.profiles set github_avatar = public.github_avatar_of(new.raw_user_meta_data)
	where id = new.id and github_avatar is distinct from public.github_avatar_of(new.raw_user_meta_data);
	return new;
end;
$$;

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
	after update of raw_user_meta_data on auth.users
	for each row execute function public.handle_user_updated();

-- the players who signed up with GitHub before this
update public.profiles p set github_avatar = public.github_avatar_of(u.raw_user_meta_data)
from auth.users u
where u.id = p.id and p.github_avatar is null and public.github_avatar_of(u.raw_user_meta_data) is not null;

revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.handle_user_updated() from public, anon, authenticated;
revoke execute on function public.github_avatar_of(jsonb) from public, anon, authenticated;

-- --- XP, battle by battle --------------------------------------------------

-- Every battle that earned XP, and when, so a leaderboard can count this
-- week's or this month's. Written only by end_battle; read only through the
-- leaderboard.
create table if not exists public.xp_log (
	id bigint generated always as identity primary key,
	user_id uuid not null references public.profiles (id) on delete cascade,
	gained integer not null check (gained > 0),
	at timestamptz not null default now()
);

create index if not exists xp_log_at on public.xp_log (at);
create index if not exists xp_log_user_at on public.xp_log (user_id, at);

alter table public.xp_log enable row level security;
revoke all on public.xp_log from anon, authenticated;

-- The battle ends, as in the ranks migration, with two changes. Each battle
-- that earns XP is logged. And only a battle that earns XP (two minutes or
-- more on the database's clock) counts towards the battles and wins on the
-- record: before, a "win" reported a few seconds after starting counted as a
-- battle won, and with records public that's a figure worth inflating.
create or replace function public.end_battle(result text, seconds double precision)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
	p public.profiles;
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
	if p.battle_started_at is not null then
		tenths := floor(least(extract(epoch from now() - p.battle_started_at)::double precision, seconds, 2700) / 6);
		if tenths >= 20 then
			gained := floor(tenths * case result when 'win' then 1.5 when 'loss' then 1 else 0.5 end);
		end if;
	end if;
	update public.profiles set
		xp = xp + gained,
		battles = battles + case when gained > 0 and result <> 'left' then 1 else 0 end,
		wins = wins + case when gained > 0 and result = 'win' then 1 else 0 end,
		battle_started_at = null
	where id = p.id
	returning * into p;
	if gained > 0 then
		insert into public.xp_log (user_id, gained) values (p.id, gained);
	end if;
	return json_build_object(
		'gained', gained, 'rank_before', rank_before, 'xp', p.xp, 'rank', public.frontline_rank(p.xp),
		'battles', p.battles, 'wins', p.wins, 'icon', p.icon, 'callsign', p.callsign);
end;
$$;

revoke execute on function public.end_battle(text, double precision) from public, anon;
grant execute on function public.end_battle(text, double precision) to authenticated;

-- --- service records: the game's word, kept honest where it can be ----------

-- A record is stamped with when it arrived, never a time the player picks
-- (the matchmaker never sends one): every column but id and played_at.
revoke insert on public.battle_records from authenticated;
grant insert (
	user_id, game_version, mode, mission, title, side, result, duration_s, rating, score,
	kills, lost, veh_kills, veh_lost, shots, hits, me, report
) on public.battle_records to authenticated;

-- And a day holds only so many battles: 200 is several an hour round the
-- clock, and keeps anyone from flooding their public record.
create or replace function public.battle_records_daily_cap()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
	if (select count(*) from public.battle_records where user_id = new.user_id and played_at > now() - interval '1 day') >= 200 then
		raise exception 'That''s all the battles a day can hold: try again tomorrow.' using errcode = 'PT429';
	end if;
	return new;
end;
$$;

drop trigger if exists battle_records_daily_cap on public.battle_records;
create trigger battle_records_daily_cap
	before insert on public.battle_records
	for each row execute function public.battle_records_daily_cap();

revoke execute on function public.battle_records_daily_cap() from public, anon, authenticated;

-- --- what anyone may read ----------------------------------------------------

-- for finding a player as their callsign is typed
create index if not exists profiles_callsign_prefix on public.profiles (lower(callsign) text_pattern_ops);
-- the all-time leaderboard
create index if not exists profiles_xp on public.profiles (xp desc) where not hidden;

-- A player's public card: who they are, how far they've come, and where that
-- puts them on the all-time board. Null for no such player (or a hidden one).
create or replace function public.player_card(name text)
returns json
language sql
stable
security definer
set search_path = ''
as $$
	select json_build_object(
		'callsign', p.callsign,
		'icon', p.icon,
		'avatar', case when p.avatar = 'github' then p.github_avatar end,
		'xp', p.xp,
		'battles', p.battles,
		'wins', p.wins,
		'joined', p.created_at,
		'history', not p.hide_history,
		'position', case when p.xp > 0 then (select count(*) + 1 from public.profiles q where q.xp > p.xp and not q.hidden) end,
		'last_seen', (select max(l.at) from public.xp_log l where l.user_id = p.id))
	from public.profiles p
	where lower(p.callsign) = lower(trim(name)) and not p.hidden;
$$;

-- Players whose callsigns start with what's been typed, the highest ranked
-- first (at most 10).
create or replace function public.find_players(prefix text)
returns json
language sql
stable
security definer
set search_path = ''
as $$
	select coalesce(json_agg(f order by f.xp desc, f.callsign), '[]'::json)
	from (
		select p.callsign, p.icon, case when p.avatar = 'github' then p.github_avatar end as avatar, p.xp
		from public.profiles p
		where not p.hidden
			and lower(p.callsign) like replace(replace(replace(lower(trim(prefix)), '\', '\\'), '%', '\%'), '_', '\_') || '%'
		order by p.xp desc, p.callsign
		limit 10
	) f;
$$;

-- An XP leaderboard: 'all' time (total XP), this 'month' or this 'week'
-- (calendar ones, in UTC, Monday to Sunday: what was earned since they
-- began). {total, rows: [{position, callsign, icon, avatar, xp, score,
-- battles, wins}], me}, a page of `lim` rows from `off`, and `me`: the row of
-- the player named (or null), wherever they are on the board. Players level
-- on score share a position; the one who joined first is listed first.
create or replace function public.leaderboard_xp(period text, lim integer, off integer, me text default null)
returns json
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
	since timestamptz;
	board_json json;
begin
	if period is null or period not in ('all', 'month', 'week') then
		raise exception 'A leaderboard is for "all" time, this "month" or this "week".' using errcode = 'PT400';
	end if;
	lim := least(greatest(coalesce(lim, 50), 1), 100);
	off := least(greatest(coalesce(off, 0), 0), 10000);
	since := case period
		when 'week' then date_trunc('week', now() at time zone 'utc') at time zone 'utc'
		when 'month' then date_trunc('month', now() at time zone 'utc') at time zone 'utc'
	end;
	with scores as (
		select p.id, p.callsign, p.icon, case when p.avatar = 'github' then p.github_avatar end as avatar,
			p.xp, p.battles, p.wins, p.created_at,
			case when since is null then p.xp else coalesce(e.earned, 0) end as score
		from public.profiles p
		left join (
			select l.user_id, sum(l.gained)::integer as earned
			from public.xp_log l
			where since is not null and l.at >= since
			group by l.user_id
		) e on e.user_id = p.id
		where not p.hidden
	),
	board as (
		select s.*, rank() over (order by s.score desc) as position,
			row_number() over (order by s.score desc, s.created_at, s.callsign) as n
		from scores s
		where s.score > 0
	)
	select json_build_object(
		'total', (select count(*) from board),
		'rows', coalesce((
			select json_agg(json_build_object(
				'position', b.position, 'callsign', b.callsign, 'icon', b.icon, 'avatar', b.avatar,
				'xp', b.xp, 'score', b.score, 'battles', b.battles, 'wins', b.wins) order by b.n)
			from board b where b.n > off and b.n <= off + lim), '[]'::json),
		'me', (
			select json_build_object(
				'position', b.position, 'callsign', b.callsign, 'icon', b.icon, 'avatar', b.avatar,
				'xp', b.xp, 'score', b.score, 'battles', b.battles, 'wins', b.wins, 'n', b.n)
			from board b where me is not null and lower(b.callsign) = lower(trim(me))))
	into board_json;
	return board_json;
end;
$$;

-- A player's career, totalled from their battles, as the matchmaker's
-- careerOf() totals a player's own (records.js): null if they keep their
-- battles to themselves, or there's no such player.
create or replace function public.player_career(name text)
returns json
language sql
stable
security definer
set search_path = ''
as $$
	select (
		select json_build_object(
			'battles', count(*),
			'victories', count(*) filter (where r.result = 'victory'),
			'defeats', count(*) filter (where r.result <> 'victory'),
			'kills', coalesce(sum(r.kills), 0),
			'lost', coalesce(sum(r.lost), 0),
			'veh_kills', coalesce(sum(r.veh_kills), 0),
			'veh_lost', coalesce(sum(r.veh_lost), 0),
			'shots', coalesce(sum(r.shots), 0),
			'hits', coalesce(sum(r.hits), 0),
			'seconds', coalesce(sum(r.duration_s), 0),
			'score', coalesce(sum(r.score), 0),
			'rating', coalesce(round(avg(r.rating)::numeric, 1), 0),
			'best', (
				select json_build_object('id', b.id, 'rating', b.rating, 'title', b.title, 'played_at', b.played_at)
				from public.battle_records b where b.user_id = p.id order by b.rating desc, b.played_at limit 1),
			'sides', json_build_array(count(*) filter (where r.side = 0), count(*) filter (where r.side = 1)),
			'modes', (
				select coalesce(json_object_agg(m.mode, m.n), '{}'::json)
				from (select b.mode, count(*) as n from public.battle_records b where b.user_id = p.id group by b.mode) m),
			'first', min(r.played_at),
			'last', max(r.played_at))
		from public.battle_records r where r.user_id = p.id)
	from public.profiles p
	where lower(p.callsign) = lower(trim(name)) and not p.hidden and not p.hide_history;
$$;

-- A page of a player's battles, newest first, the headline numbers only:
-- `lim` of them from before `before` (null: the newest). Null if they keep
-- their battles to themselves, or there's no such player.
create or replace function public.player_battles(name text, lim integer, before timestamptz default null)
returns json
language sql
stable
security definer
set search_path = ''
as $$
	select (
		select coalesce(json_agg(b order by b.played_at desc), '[]'::json)
		from (
			select r.id, r.played_at, r.game_version, r.mode, r.mission, r.title, r.side, r.result, r.duration_s,
				r.rating, r.score, r.kills, r.lost, r.veh_kills, r.veh_lost, r.shots, r.hits
			from public.battle_records r
			where r.user_id = p.id and (before is null or r.played_at < before)
			order by r.played_at desc
			limit least(greatest(coalesce(lim, 20), 1), 51)
		) b)
	from public.profiles p
	where lower(p.callsign) = lower(trim(name)) and not p.hidden and not p.hide_history;
$$;

-- One of a player's battles, after-action report and all. Null if there's no
-- such battle of theirs, or they keep their battles to themselves.
create or replace function public.player_battle(name text, battle uuid)
returns json
language sql
stable
security definer
set search_path = ''
as $$
	select json_build_object(
		'id', r.id, 'played_at', r.played_at, 'game_version', r.game_version, 'mode', r.mode, 'mission', r.mission,
		'title', r.title, 'side', r.side, 'result', r.result, 'duration_s', r.duration_s, 'rating', r.rating,
		'score', r.score, 'kills', r.kills, 'lost', r.lost, 'veh_kills', r.veh_kills, 'veh_lost', r.veh_lost,
		'shots', r.shots, 'hits', r.hits, 'me', r.me, 'report', r.report)
	from public.profiles p
	join public.battle_records r on r.user_id = p.id
	where lower(p.callsign) = lower(trim(name)) and not p.hidden and not p.hide_history and r.id = battle;
$$;

-- Anyone may read these, signed in or not: they're the website's public
-- pages. (Supabase's linter flags SECURITY DEFINER functions open to anon;
-- these read only what's public, and write nothing.)
revoke execute on function public.player_card(text) from public;
revoke execute on function public.find_players(text) from public;
revoke execute on function public.leaderboard_xp(text, integer, integer, text) from public;
revoke execute on function public.player_career(text) from public;
revoke execute on function public.player_battles(text, integer, timestamptz) from public;
revoke execute on function public.player_battle(text, uuid) from public;
grant execute on function public.player_card(text) to anon, authenticated;
grant execute on function public.find_players(text) to anon, authenticated;
grant execute on function public.leaderboard_xp(text, integer, integer, text) to anon, authenticated;
grant execute on function public.player_career(text) to anon, authenticated;
grant execute on function public.player_battles(text, integer, timestamptz) to anon, authenticated;
grant execute on function public.player_battle(text, uuid) to anon, authenticated;

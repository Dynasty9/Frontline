-- Frontline accounts: Supabase Auth holds the users; this adds a callsign for
-- each. The matchmaker talks to Supabase with the public key only, acting as
-- the signed-in player, so row-level security is what keeps players to their
-- own profile.

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
-- are public anyway (they're shown in the lobby list).
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
grant execute on function public.callsign_taken(text) to anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

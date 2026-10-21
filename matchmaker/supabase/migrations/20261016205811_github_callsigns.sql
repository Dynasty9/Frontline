-- Players sign in with GitHub, and a new player's profile takes its callsign
-- from their GitHub username (Supabase puts it in the user's metadata as
-- user_name). A username is made to fit a callsign (3 to 20 letters, digits,
-- _ . or -) and numbered if someone has it already, so signing in with GitHub
-- never fails for want of a callsign; with nothing usable it's
-- Commander-<id>, as before. A callsign typed at sign-up (email, for testing)
-- is taken as it is: malformed or taken, the sign-up fails, as before.

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
		insert into public.profiles (id, callsign) values (new.id, typed);
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
	insert into public.profiles (id, callsign) values (new.id, pick);
	return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

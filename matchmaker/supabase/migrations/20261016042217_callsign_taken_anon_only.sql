-- only the sign-up form (not signed in yet) needs to ask
revoke execute on function public.callsign_taken(text) from authenticated;

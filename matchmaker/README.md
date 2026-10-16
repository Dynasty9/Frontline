# Frontline matchmaker

A small Node service that keeps the list of battles players are hosting, finds a battle for anyone who presses
**Find Match**, and introduces host and joiner so they can connect through their home routers. Accounts are
optional: with Supabase configured, players can sign in so their callsign is theirs alone, and the battles they play
earn XP towards 50 ranks, each of which unlocks an insignia they can wear.

It never carries game traffic. Players still connect straight to the host over ENet (UDP), peer to peer, exactly
as with **Join Game** by address. The live instance runs on Railway at
`https://matchmaker-production-a53e.up.railway.app`, which is the game's default (`Online.DEFAULT_URL` in
`scripts/autoload/online.gd`).

No dependencies beyond Node 20 or newer (the lint and formatting tools are development-only).

## How players get through routers

Most players are behind a home router that drops packets nobody asked for, so a host can't simply be dialled.
The matchmaker does what voice and game clients do, **UDP hole punching**:

1. Before the host's ENet server binds its port, the game asks two public STUN servers (Cloudflare and Google)
   which address and port its router shows the internet for that port, and lists the battle with that endpoint.
2. A player who wants in does the same from a fresh local port, and sends their endpoint with the join request.
3. The matchmaker hands the joiner the host's endpoint, and passes the joiner's to the host, which is waiting on
   a long poll and hears about it at once.
4. Both send packets at each other. Each router sees an outgoing packet and lets the other side's packets in as
   replies, and ENet connects directly.

Two players behind the same router get the host's LAN address instead (most routers can't loop a connection back
in through their own public address).

**Where this fails.** A router that hands out a new public port for every destination ("symmetric NAT", common
on mobile networks, some campus networks and carrier-grade NAT) can't be punched through. The game spots this
(the two STUN servers report different ports), shows it in the lobby, and the matchmaker tries such hosts last.
A host behind one needs to forward UDP port 7777. The only fix beyond that is a relay, which would put game
traffic through a server.

Railway has no public UDP, which is why the STUN step uses public STUN servers rather than this service.

## API

JSON in, JSON out. Errors are `{"error": "..."}` with a 4xx/5xx status.

| Call | What it does |
|---|---|
| `GET /health` | `{ok, accounts: "off" \| "supabase" \| "memory", release, lobbies, players}` |
| `GET /release` | The latest release of the game: `{version, tag, name, published, url, assets: {windows, linux}}`, each asset with its `url`, `size` and `sha256`. The release workflow writes it into `release.json` and commits it, which redeploys this service; the game's updater reads it. |
| `GET /lobbies?version=N` | The battles being hosted, fullest first. No addresses. A signed-in host's `icon` and `rank` (as they were when the battle was listed), `null` for a host who isn't. |
| `POST /match` `{version, exclude: [ids]}` | Quick match: `{lobby}`, or `{lobby: null}` (then host one). Holds a seat for 20 s. |
| `POST /lobbies` `{port, host, version, players, max_players, in_game, drop_in, nat, lan, punch: {ip, port}}` | List a battle. Returns `{id, token}`. With a signed-in `Authorization: Bearer`, it's listed under the account's callsign, and replaces that account's earlier listing. |
| `POST /lobbies/:id/heartbeat` | The host's state (players, in_game...). Needs `X-Lobby-Token`. |
| `POST /lobbies/:id/poll?wait=20` | The host's long poll: `{joins: [{ip, port}]}`, the players to punch towards. If the host drops this connection the listing comes down at once. |
| `POST /lobbies/:id/join` `{ip, port}` | Ask to join, with your STUN endpoint. Returns `{connect: {address, port, via: "lan" \| "punch" \| "direct"}}`. |
| `DELETE /lobbies/:id` | Unlist (`X-Lobby-Token`). |
| `POST /auth/signup` `{email, password, callsign}` | `{session}`, or `{confirm: true}` when Supabase wants the email confirmed first. |
| `POST /auth/login` `{email, password}` | `{session: {access_token, refresh_token, expires_in, user}}` |
| `POST /auth/refresh` `{refresh_token}` | A new session. |
| `POST /auth/logout`, `GET /me` | Sign out; who am I (`{user}`). Need the bearer token, as do the calls below. |
| `PATCH /me` `{callsign?, icon?}` | Rename, wear an insignia, or both: `{user}`. An unknown insignia is 400, one not unlocked yet 403 (and then nothing changes). |
| `POST /me/battle` | A battle starts: `{ok: true}`. Starts this player's battle clock; calling it again starts over, and the battle left open earns nothing. |
| `POST /me/battle/end` `{result: "win" \| "loss" \| "left", seconds}` | The battle ends: `{gained, rank_before, user}`. `seconds` is how long the game says it ran (game time, so pauses don't count). |

A user, wherever one is returned (the session's `user`, `/me`, a battle's end), is
`{id, email, callsign, icon, xp, rank, rank_xp, next_xp, battles, wins}`: the insignia worn (`s01` to begin with),
total XP, the rank (0, Recruit, to 50), the XP where that rank began and where the next begins (`null` at 50), and
the battles fought to the end and won.

**Ranks.** Reaching rank *r* takes `150r + 10r(r-1)` XP: 150 for rank 1, 32,000 for rank 50. A battle is worth a
point per tenth of a minute, times 1.5 for a win, 1 for a loss and 0.5 for leaving early. The minutes counted are
the shorter of the game's `seconds` and how long the battle was open on the server's clock, at most 45; under 2
earn nothing. Wins and losses count towards `battles` (and `wins`); an end with no battle open (a retry, say)
earns and counts nothing. There's no game server to referee a battle (players host), so the game reports its own
result; timing it on our clock means a modified game can't claim hours of play in seconds, and XP stays bounded by
real time played. The rules live in [`src/ranks.js`](src/ranks.js), and again in SQL for Supabase.

**Insignia.** `s01`-`s10` are the starters every account has; `r01`-`r50` are the rank patches, `rNN` unlocked at
rank NN; `m01`-`m50` (awards) and `u01`-`u50` (unit patches) exist but can't be worn by anyone yet.

The battle calls are limited to 20 a minute per address, sign-in and renaming to 10, insignia changes to 30.

A lobby whose host stops checking in for 45 s is dropped, and an unknown lobby id on any host call returns 404,
which the game answers by listing again (so a restart of this service costs nothing but a few seconds).
Everything is in memory, so the service must run as a single instance.

## Running it locally

```bash
npm test
```

```bash
npm start
```

That serves on port 8080 (`PORT` to change it) with accounts off. `AUTH_BACKEND=memory npm start` adds throwaway
in-memory accounts for testing. Point the game at it with `--matchmaker=http://127.0.0.1:8080` (or the
`FL_MATCHMAKER` environment variable); `docs/DEVELOPMENT.md` has the headless host / Find Match test.

The tests and the service need nothing installed. The lint and formatting tools do (`npm install` first):

```bash
npm run lint           # oxlint
npm run format:check   # Prettier; npm run format fixes it
```

CI (`.github/workflows/matchmaker.yml`) runs both, and the tests on Node 20, 22 and 24 without installing anything,
on every push and pull request that touches `matchmaker/`.

## Deploying on Railway

The service lives in the `frontline` project, service `matchmaker`. From this directory:

```bash
railway up --service matchmaker --ci
```

Railway builds it with its Node defaults (`npm start`) and sets `PORT`. Behind Railway's proxy the player's
address comes from `X-Forwarded-For`; that is switched on automatically when `RAILWAY_ENVIRONMENT_NAME` is set (or
force it with `TRUST_PROXY=1` / `0`).

## Accounts (Supabase)

The live service uses the Supabase project `frontline` (ref `ufmgcpjgtlykcqgtcvxe`, us-west-1, next to Railway's
us-west2), with email confirmation switched off. To set up another one:

1. Create a Supabase project.
2. In its SQL editor, run [`supabase/schema.sql`](supabase/schema.sql). It adds a `profiles` table (one callsign
   per user, unique regardless of case, plus the insignia, XP and record), the row-level security that keeps
   players to their own profile, a trigger that creates the profile at sign-up, `callsign_taken()` for the sign-up
   form, and the rank functions below.
3. Give the matchmaker the project URL and its public key (the publishable key, or the legacy anon key). No secret
   key is needed: the service acts as the signed-in player, and row-level security does the rest.

   ```bash
   railway variable set --service matchmaker SUPABASE_URL=https://YOUR-PROJECT.supabase.co SUPABASE_KEY=sb_publishable_...
   ```

4. On the Auth Providers page, open **Email** and switch off **Confirm email**. Supabase's built-in mailer only
   delivers to members of your own Supabase team (and two emails an hour), so with confirmation on, every
   player's sign-up fails. To confirm emails, give Supabase your own SMTP server first; the game already tells
   players to click the link when Supabase asks for one.

`GET /health` then reports `"accounts": "supabase"`, and `GET https://YOUR-PROJECT.supabase.co/auth/v1/settings`
(with the key as `apikey`) shows `"mailer_autoconfirm": true` once confirmation is off.

### The ranks migration

A database set up before ranks needs `schema.sql` run again (it's safe to run any number of times: it only adds
what's missing and replaces the functions). Do it **before** the matchmaker that uses it is deployed, since Railway
redeploys on every merge that touches `matchmaker/`. It adds to `profiles` the insignia worn (`icon`, `s01` for
everyone to begin with), `xp`, `battles`, `wins` and `battle_started_at` (when the open battle began), and four
functions, which only signed-in players may run:

| Function | What it does |
|---|---|
| `frontline_rank(xp)` | The rank for a total of XP (the same curve as `src/ranks.js`). |
| `begin_battle()` | Starts the caller's battle clock: `battle_started_at = now()`. |
| `end_battle(result, seconds)` | Closes the battle, works out the XP from the time on the database's clock and the game's `seconds`, adds it and the record, and returns `{gained, rank_before, xp, rank, battles, wins, icon, callsign}`. |
| `set_icon(icon)` | Wears an insignia: unknown ids raise `PT400`, locked ones `PT403` (the matchmaker answers 400 and 403). |

XP is written only through these. The matchmaker holds no secret key, so a player could call Supabase's API
directly with their own token, and anything they could write that way they could set to whatever they like. So the
callsign stays the only column a player may update; the functions run as the table's owner (`SECURITY DEFINER`),
touch nothing but the caller's own row (`auth.uid()`), and apply the same rules as the matchmaker, with the
battle timed on the database's clock. Going round the matchmaker gets a player nothing the game wouldn't. The
linter's warning that signed-in users can run `SECURITY DEFINER` functions is expected for the last three.

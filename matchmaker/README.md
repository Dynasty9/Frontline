# Frontline matchmaker

A small Node service that keeps the list of battles players are hosting, finds a battle for anyone who presses
**Find Match**, and introduces host and joiner so they can connect through their home routers. Accounts are
optional: with Supabase configured, players can sign in so their callsign is theirs alone.

It never carries game traffic. Players still connect straight to the host over ENet (UDP), peer to peer, exactly
as with **Join Game** by address. The live instance runs on Railway at
`https://matchmaker-production-a53e.up.railway.app`, which is the game's default (`Online.DEFAULT_URL` in
`scripts/autoload/online.gd`).

No dependencies beyond Node 20 or newer.

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
| `GET /health` | `{ok, accounts: "off" \| "supabase" \| "memory", lobbies, players}` |
| `GET /lobbies?version=N` | The battles being hosted, fullest first. No addresses. |
| `POST /match` `{version, exclude: [ids]}` | Quick match: `{lobby}`, or `{lobby: null}` (then host one). Holds a seat for 20 s. |
| `POST /lobbies` `{port, host, version, players, max_players, in_game, drop_in, nat, lan, punch: {ip, port}}` | List a battle. Returns `{id, token}`. With a signed-in `Authorization: Bearer`, it's listed under the account's callsign, and replaces that account's earlier listing. |
| `POST /lobbies/:id/heartbeat` | The host's state (players, in_game...). Needs `X-Lobby-Token`. |
| `POST /lobbies/:id/poll?wait=20` | The host's long poll: `{joins: [{ip, port}]}`, the players to punch towards. If the host drops this connection the listing comes down at once. |
| `POST /lobbies/:id/join` `{ip, port}` | Ask to join, with your STUN endpoint. Returns `{connect: {address, port, via: "lan" \| "punch" \| "direct"}}`. |
| `DELETE /lobbies/:id` | Unlist (`X-Lobby-Token`). |
| `POST /auth/signup` `{email, password, callsign}` | `{session}`, or `{confirm: true}` when Supabase wants the email confirmed first. |
| `POST /auth/login` `{email, password}` | `{session: {access_token, refresh_token, expires_in, user}}` |
| `POST /auth/refresh` `{refresh_token}` | A new session. |
| `POST /auth/logout`, `GET /me`, `PATCH /me` `{callsign}` | Sign out, who am I, rename. Need the bearer token. |
| `POST /me/battles` `{mode, mission, title, side, result, duration, game_version, me, report}` | Put a battle on your service record (up to ~100 KB with its report). `{id, played_at}`. |
| `GET /me/battles?limit=20&before=TIME` | Your battles, newest first, headline numbers only: `{battles, more}`. `before` is the last one's `played_at`. |
| `GET /me/battles/:id` | One battle, with your figures (`me`) and its after-action report (`report`). |
| `GET /me/career` | The totals of every battle on your record: battles, victories, kills, losses, average and best rating, time. |

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
   per user, unique regardless of case), the row-level security that keeps players to their own profile, a trigger
   that creates the profile at sign-up, `callsign_taken()` for the sign-up form, and `battle_records` (each
   player's service record: they can add battles and read their own, nothing else).
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

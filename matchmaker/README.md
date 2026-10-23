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
| `GET /release` | The latest release of the game: `{version, tag, name, published, url, assets: {windows, linux}}`, each asset with its `url`, `size` and `sha256`. The release workflow writes it into `release.json` on the release's pull request, and merging that redeploys this service; the game's updater reads it. |
| `GET /lobbies?version=N` | The battles being hosted, fullest first. No addresses. Each says what it is: `mode` (`coop`, `versus` or `mission`), `mission`, `side`, `teams` (players per side), `spectators` and `locked` (wants a password). A signed-in host's `icon` and `rank` (as they were when the battle was listed), `null` for a host who isn't. |
| `POST /match` `{version, exclude: [ids]}` | Quick match: `{lobby}`, or `{lobby: null}` (then host one). Holds a seat for 20 s. Never offers a battle with a password. |
| `POST /lobbies` `{port, host, version, players, max_players, in_game, drop_in, nat, lan, punch: {ip, port}}` | List a battle. Returns `{id, token}`. With a signed-in `Authorization: Bearer`, it's listed under the account's callsign, and replaces that account's earlier listing. |
| `POST /lobbies/:id/heartbeat` | The host's state (`name`, `players`, `max_players`, `in_game`, `drop_in`, `mode`, `mission`, `side`, `teams`, `spectators`, `locked`). Needs `X-Lobby-Token`. |
| `POST /lobbies/:id/poll?wait=20` | The host's long poll: `{joins: [{ip, port}]}`, the players to punch towards. If the host drops this connection the listing comes down at once. |
| `POST /lobbies/:id/join` `{ip, port}` | Ask to join, with your STUN endpoint. Returns `{connect: {address, port, via: "lan" \| "punch" \| "direct"}}`. |
| `DELETE /lobbies/:id` | Unlist (`X-Lobby-Token`). |
| `POST /auth/oauth` `{provider: "github", redirect_to, code_challenge}` | Sign in with GitHub: `{url}`, where to send the player. They come back to `redirect_to` with `?code=`. `code_challenge` is the PKCE challenge (base64url SHA-256 of a verifier the page keeps). |
| `POST /auth/exchange` `{code, code_verifier}` | That code and the page's verifier: `{session}`. A player new to Frontline gets a profile named after their GitHub username. |
| `POST /auth/signup` `{email, password, callsign}` | For testing (players sign in with GitHub): `{session}`, or `{confirm: true}` when Supabase wants the email confirmed first. |
| `POST /auth/login` `{email, password}` | For testing: `{session: {access_token, refresh_token, expires_in, user}}` |
| `POST /auth/refresh` `{refresh_token}` | A new session. |
| `POST /auth/logout` `{scope?: "global"}`, `GET /me` | Sign out (that session only: the game and the website hold one each; `global` ends every session the account has, the website's "Sign out everywhere"); who am I (`{user}`). Need the bearer token, as do the calls below. |
| `PATCH /me` `{callsign?, icon?, avatar?, hide_history?}` | Rename, wear an insignia, pick your picture (`insignia`, or `github`: only for an account with a GitHub picture), keep your battles off your public page: any of them, `{user}`. An unknown insignia is 400, one not unlocked yet 403 (and then nothing changes). |
| `POST /me/battle` | A battle starts: `{ok: true}`. Starts this player's battle clock; calling it again starts over, and the battle left open earns nothing. |
| `POST /me/battle/end` `{result: "win" \| "loss" \| "left", seconds}` | The battle ends: `{gained, rank_before, user}`. `seconds` is how long the game says it ran (game time, so pauses don't count). |
| `POST /me/battles` `{mode, mission, title, side, result, duration, game_version, me, report}` | Put a battle on your service record (up to ~100 KB with its report). `{id, played_at}`. |
| `GET /me/battles?limit=20&before=TIME` | Your battles, newest first, headline numbers only: `{battles, more}`. `before` is the last one's `played_at`. |
| `GET /me/battles/:id` | One battle, with your figures (`me`) and its after-action report (`report`). |
| `GET /me/career` | The totals of every battle on your record: battles, victories, kills, losses, average and best rating, time. |
| `GET /leaderboards/xp?period=all\|month\|week&page=N&me=CALLSIGN` | A leaderboard of XP: all of it, or what was earned this month or this week (calendar ones, UTC). `{board, period, page, pages, per_page, total, rows, me}`, 50 rows a page, each `{position, callsign, icon, avatar, rank, xp, score, battles, wins}` (`score` is what the board ranks by); players level on it share a position. `me` is the named player's row, wherever they are on the board. Anyone may ask, as for the five below. |
| `GET /players?q=TEXT` | Players whose callsigns start with `q` (two letters or more), the highest ranked first: `{players: [{callsign, icon, avatar, rank}]}`, at most 10. |
| `GET /players/:callsign` | A player's public card: `{player: {callsign, icon, avatar, xp, rank, rank_xp, next_xp, battles, wins, joined, history, position, last_seen}}`. `avatar` is their GitHub picture if they've chosen it, else `null` (their insignia); `history` false means they keep their battles to themselves; `position` is their place on the all-time board. Never an email. 404 for no such player. |
| `GET /players/:callsign/career` | Their career, as `/me/career` totals one: `{career}`, `null` if they keep their battles to themselves. |
| `GET /players/:callsign/battles?limit=20&before=TIME` | Their battles, as `/me/battles`: `{battles, more}`, or `{battles: [], more: false, hidden: true}`. |
| `GET /players/:callsign/battles/:id` | One of their battles, with their figures and its after-action report: `{battle}`. 404 if it isn't theirs or they keep their battles to themselves. |
| `POST /errors` `{game_version, os, gpu, driver, session, reports: [{kind, message, condition, where, context, backtrace, log, count}]}` | Error reports from a player's game (`kind`: `error`, `script`, `shader` or `crash`; up to 24 at once). `{ok, accepted}`. |
| `GET /errors` | The error tally since the service started, most common first: each error once, with its count, sessions, and the versions, systems, GPUs and drivers it was seen on. Needs `Authorization: Bearer <ERRORS_TOKEN>`; without `ERRORS_TOKEN` set it doesn't exist. |

A user, wherever one is returned (the session's `user`, `/me`, a battle's end), is
`{id, email, callsign, icon, avatar, github_avatar, hide_history, joined, xp, rank, rank_xp, next_xp, battles, wins}`:
the insignia worn (`s01` to begin with), the picture shown on the website (`insignia` or `github`) and their GitHub
picture (`null` for an account that isn't a GitHub one), whether their battles are kept off their public page, when
they joined, total XP, the rank (0, Recruit, to 50), the XP where that rank began and where the next begins (`null`
at 50), and the battles fought to the end and won.

**Ranks.** Reaching rank *r* takes `150r + 10r(r-1)` XP: 150 for rank 1, 32,000 for rank 50. A battle is worth a
point per tenth of a minute, times 1.5 for a win, 1 for a loss and 0.5 for leaving early. The minutes counted are
the shorter of the game's `seconds` and how long the battle was open on the server's clock, at most 45; under 2
earn nothing. Wins and losses that earn XP count towards `battles` (and `wins`): a battle under 2 minutes counts
for nothing, so a "win" reported a moment after starting isn't a battle won. An end with no battle open (a retry,
say) earns and counts nothing. There's no game server to referee a battle (players host), so the game reports its own
result; timing it on our clock means a modified game can't claim hours of play in seconds, and XP stays bounded by
real time played. The rules live in [`src/ranks.js`](src/ranks.js), and again in SQL for Supabase.

**Insignia.** `s01`-`s10` are the starters every account has; `r01`-`r50` are the rank patches, `rNN` unlocked at
rank NN; `m01`-`m50` (awards) and `u01`-`u50` (unit patches) exist but can't be worn by anyone yet.

The battle calls are limited to 20 a minute per address, sign-in and renaming to 10, insignia (and picture) changes
to 30, and the public pages (`/leaderboards`, `/players`) to 120.

**Public pages.** The leaderboards and players' pages are for anyone to read, so their answers are kept for half a
minute, here (in memory) and in the browser (`Cache-Control: public, max-age=30`): a board a crowd is looking at is
worked out once, and a change shows within the half minute. Everything else is `no-store`. Only XP is ranked: the
database writes it, timed on its own clock. A player's battles are their own game's word, shown as theirs and never
ranked.

A lobby whose host stops checking in for 45 s is dropped, and an unknown lobby id on any host call returns 404,
which the game answers by listing again (so a restart of this service costs nothing but a few seconds).
Everything is in memory, so the service must run as a single instance.

## Error reports

Release builds of the game send their errors here (`scripts/autoload/errors.gd`): engine errors with the GDScript
call stack that led to them, shader errors, and crashes (sent by the next launch, from the engine's log). The
service keeps a tally in memory, one entry per distinct error (the same place, the same call, the same message with
its numbers taken out), and writes each new one to the log in full, then a line each time its count passes another
power of ten; the log is what outlives a redeploy. Reports carry no account and the game strips paths, addresses and
emails before sending; the service doesn't record where one came from. To read the tally, give the service a secret
and ask with it:

```bash
railway variable set --service matchmaker ERRORS_TOKEN=$(openssl rand -hex 24)
curl -H "Authorization: Bearer $ERRORS_TOKEN" https://matchmaker-production-a53e.up.railway.app/errors
```

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
us-west2), with GitHub sign-in switched on and email confirmation off. To set up another one:

1. Create a Supabase project.
2. Apply the migrations (see [The database](#the-database)): from this directory,
   `supabase db push --db-url "postgresql://postgres.REF:PASSWORD@aws-0-REGION.pooler.supabase.com:5432/postgres"`
   with the project's session-pooler connection string. Or paste each file in `supabase/migrations/` into its SQL
   editor, in order.
3. Give the matchmaker the project URL and its public key (the publishable key, or the legacy anon key). These authorize database requests as the signed-in player; row-level security does the rest.
   Automatic game sign-in also needs the server-only key described in [Reusing a website login](#reusing-a-website-login-in-the-game).

   ```bash
   railway variable set --service matchmaker SUPABASE_URL=https://YOUR-PROJECT.supabase.co SUPABASE_KEY=sb_publishable_...
   ```

4. Switch on **GitHub**, the way players sign in: make a GitHub OAuth app (GitHub > Settings > Developer settings >
   OAuth Apps) with the callback `https://YOUR-PROJECT.supabase.co/auth/v1/callback`, and give its client ID and
   secret to Supabase (Authentication > Sign In / Providers > GitHub). Then, under Authentication > URL
   Configuration, set the **Site URL** to the website and add it to the **Redirect URLs**
   (`https://YOUR-SITE/**`, and `http://localhost:5173/**` for the dev server): Supabase sends players back only
   to those. Anywhere else it sends them to the Site URL, which starts out as `http://localhost:3000`: a sign-in
   that lands on `localhost:3000/?code=...` means the site's address is missing from the Redirect URLs.
5. On the Auth Providers page, open **Email** (kept for testing) and switch off **Confirm email**. Supabase's built-in mailer only
   delivers to members of your own Supabase team (and two emails an hour), so with confirmation on, every
   player's sign-up fails. To confirm emails, give Supabase your own SMTP server first; the game already tells
   players to click the link when Supabase asks for one.

`GET /health` then reports `"accounts": "supabase"`, and `GET https://YOUR-PROJECT.supabase.co/auth/v1/settings`
(with the key as `apikey`) shows `"mailer_autoconfirm": true` once confirmation is off.

## The database

Its schema is the migrations in [`supabase/migrations/`](supabase/migrations/), one file per change, in the
Supabase CLI's layout (`<UTC timestamp>_<name>.sql`, applied in that order, each once). The database records which
it has applied in `supabase_migrations.schema_migrations`, so `supabase db push` applies only the new ones. Together
they add:

- `profiles`: one per player, made by a trigger at sign-up: the callsign they typed (email, for testing), or their
  GitHub username made to fit (numbered if it's taken), and their GitHub picture (`github_avatar`, kept up to date
  at each sign-in; only GitHub's image host is taken). The callsign (unique regardless of case), the picture shown
  (`avatar`: `insignia` or `github`) and `hide_history` are the columns a player may change; the insignia worn
  (`icon`), `xp`, `battles`, `wins` and `battle_started_at` (when the open battle began) change only through the
  functions below, and `hidden` (see [Moderation](#moderation)) only by hand.
- `battle_records`: each player's service record. They can add battles and read their own, nothing else; a record
  is stamped with when it arrived (`played_at` isn't theirs to set), and a day holds 200.
- `xp_log`: every battle that earned XP, and when, for this week's and this month's leaderboards. Only
  `end_battle` writes it, and no player can read it directly.
- `callsign_taken(name)` for the sign-up form (signed-out callers only), and the rank functions, which only
  signed-in players may run:

| Function | What it does |
|---|---|
| `frontline_rank(xp)` | The rank for a total of XP (the same curve as `src/ranks.js`). |
| `begin_battle()` | Starts the caller's battle clock: `battle_started_at = now()`. |
| `end_battle(result, seconds)` | Closes the battle, works out the XP from the time on the database's clock and the game's `seconds`, adds it (and logs it) and, if it earned any, the record, and returns `{gained, rank_before, xp, rank, battles, wins, icon, callsign}`. |
| `set_icon(icon)` | Wears an insignia: unknown ids raise `PT400`, locked ones `PT403` (the matchmaker answers 400 and 403). |

XP is written only through these. Database requests use the public key and player token, so a player could call Supabase's API
directly with their own token, and anything they could write that way they could set to whatever they like. So the
columns a player may update are only the harmless ones; the functions run as the table's owner (`SECURITY
DEFINER`), touch nothing but the caller's own row (`auth.uid()`), and apply the same rules as the matchmaker, with
the battle timed on the database's clock. Going round the matchmaker gets a player nothing the game wouldn't. The
linter's warning that signed-in users can run `SECURITY DEFINER` functions is expected for the last three.

What anyone may read, signed in or not, goes through the public functions, which hand back public columns only
(never an email, never a hidden player), and only what a player hasn't kept back: `leaderboard_xp(period, lim, off,
me)`, `player_card(name)`, `find_players(prefix)`, `player_career(name)`, `player_battles(name, lim, before)` and
`player_battle(name, battle)`. The linter warns that anyone may run these `SECURITY DEFINER` functions: that's what
they're for, and they read only what's public.

### Moderation

A callsign that shouldn't be on the leaderboards (offensive, impersonating someone) comes off them, and the
player's page goes, with one update in the Supabase dashboard's SQL editor:

```sql
update public.profiles set hidden = true where lower(callsign) = lower('TheCallsign');
```

They can still play and sign in; nobody else sees them. `hidden = false` brings them back. To rename them instead,
set `callsign` (it must be 3-20 letters, digits, spaces, _ . or -, and not taken).

### Changing it

Every change to the schema is a new migration. From this directory, with the
[Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started):

```bash
supabase migration new add_something
```

That makes `supabase/migrations/<now>_add_something.sql` for the SQL. Then:

- **Never edit or remove a migration that's on `main`.** The live database has run it; changing the file changes
  nothing there, and only makes a fresh database differ from the live one. Fix a mistake with another migration.
- **Keep it compatible with the matchmaker that's running.** Railway deploys the matchmaker and the release
  migrates the database independently, so for a minute either can be ahead of the other. Add tables, columns
  (with defaults) and functions freely; to take something away, stop the code using it first, release that, and
  remove it in a later migration. The matchmaker reads a profile's every column (`select=*`) rather than a list, so
  one it knows that isn't there yet reads as its default, and a missing function answers 503 ("try again in a
  minute"), which the game treats as a battle that didn't count.
- **Test it:** `npm ci && npm test` runs every migration in order on PGlite (`test/migrations.test.js`: Postgres in
  WebAssembly, with what Supabase provides around it faked) and checks the rules they enforce: add to it for
  anything new. `supabase db start` (with Docker) applies them all on Supabase's own Postgres.
- If another pull request's migration lands on `main` first with a later timestamp than yours, give yours a new one
  (rename the file with a timestamp from now): `supabase db push` won't apply a migration older than the newest it
  has.

CI (`.github/workflows/matchmaker.yml`, "Database migrations") checks all of that on every pull request that touches
the matchmaker: nothing on the base branch changed or removed, new migrations after the newest there, the PGlite
tests, and every migration applied from scratch on Supabase's image.

### How a migration reaches the live database

The Database workflow (`.github/workflows/database.yml`) does it: it lists the live database's migrations, shows
what's to apply (`supabase db push --dry-run`), then applies them (`supabase db push`). It runs

- when a merge to `main` adds migrations, since Railway deploys the merged matchmaker at the same time;
- at the start of every release: the Release workflow calls it before building, so a release never ships ahead of
  the schema it needs, and a failed migration stops the release;
- by hand, Actions > Database > Run workflow, to apply any still pending.

It runs in the GitHub environment `production`, whose secret `SUPABASE_DB_URL` is the project's **session pooler**
connection string (Supabase Dashboard > Connect > Session pooler, port 5432, with the database password filled in):
GitHub's runners have no IPv6, which the direct connection needs. To set it up once:

```bash
gh secret set SUPABASE_DB_URL --env production --repo Dynasty9/Frontline
```

(it asks for the value). In the repository's Settings > Environments > production, limit deployments to `main`, so
only merged code ever reaches the database with it.

To apply them by hand instead, or check what the live database has:

```bash
supabase migration list --db-url "$SUPABASE_DB_URL"
supabase db push --db-url "$SUPABASE_DB_URL"
```


### Reusing a website login in the game

`POST /auth/game` accepts the website's bearer token and returns `{token}`, a separate game refresh token.
The website calls it automatically for a game sign-in request, then opens the existing state-bound
`frontline://sign-in/` callback. The browser keeps its own session; the two never share a rotating refresh token.

For Supabase, set `SUPABASE_SECRET_KEY` (or legacy `SUPABASE_SERVICE_ROLE_KEY`) **only on the matchmaker**.
This key is used only for Auth's `admin/generate_link`: the server verifies the caller directly with Auth,
takes the verified account's confirmed email, generates and consumes a magic link on the server without sending
email, and checks the returned user ID. The public key and player bearer still authorize all database calls.
Never put this secret in the website's Vite variables or game. Without it, automatic handoff reports a
configuration error and the existing GitHub sign-in remains available.

## Battle recordings

Mount a persistent volume and set `REPLAY_DIR` to enable delayed public broadcasts and seven-day replay storage. Without it, the service reports recording disabled. The recording HTTP API is independent of accounts; uploads require a public active lobby owner. See [REPLAYS.md](../docs/REPLAYS.md) for endpoints, capacity limits and deployment.

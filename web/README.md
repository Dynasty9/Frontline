# Frontline website

The game's website. Its pages (`src/pages/`, routed by React Router in `src/router.tsx`):

| Page                           | What's on it                                                                                                                                                   |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/`                            | Home: the game tour, for everyone; signed in, your progress and the way back into a battle sit just under the footage                                          |
| `/manual`                      | the Field Manual: how the game fights, chapter by chapter, with figures from its tables, and the way into each catalogue                                       |
| `/manual/:section/:entry`      | `infantry`, `vehicles`, `buildings`, `support`, `research`: every entry with its figures and the game's 3D model, at its own address (`/manual/vehicles/tank`) |
| `/play`                        | download first on a new device; launch first after a successful game handoff; Find Match and platform downloads                                                |
| `/battles`                     | every battle being hosted, each with a **Join** link (`frontline://join/<id>`), and a friend's invite                                                          |
| `/leaderboards`                | the commanders with the most XP: all time, this month, this week (`?period=`, `?page=`); find a player                                                         |
| `/player/:callsign`            | anyone's public page: rank, XP, record, place on the board; their career and battles, unless kept back                                                         |
| `/player/:callsign/battle/:id` | one of their battles: its after-action report (their part, every commander, the two sides)                                                                     |
| `/ranks`                       | the public rank guide: XP thresholds and unlocks; insignia selection lives in `/profile`                                                                       |
| `/profile`                     | signed in, your rank and record, your callsign (rename it), your picture, whether your battles are public, the insignia you wear, and signing out everywhere   |
| `/changelog`                   | every release, with its changes and screenshots                                                                                                                |

The header keeps five destinations: **Home**, **Manual**, **Battles**, **Commanders** and **Updates**, plus **Play** and the account menu. Commanders groups the leaderboards and rank guide under a shared secondary navigation, and the Manual its overview and catalogues. GitHub and project links live in the footer. Personal settings and insignia selection live in the profile; the account menu also links the public record.

Everything public (players, boards, battles) comes from the
matchmaker's public routes (`src/lib/players.ts`; `matchmaker/src/players.js`), fetched with TanStack Query, so going
back to a page is instant; the matchmaker and the browser keep each answer for half a minute. A battle's report is
read the way the game reads it: `src/lib/report.ts` has the game's rating and score formulas (keep them in step with
`scripts/game/battle_stats.gd`). Signed out, its **Sign in** opens the sign-in dialog over whatever page you're on; so does the ranks page's.
Signing in keeps the current page and invitation. GitHub still returns to the allow-listed root callback; this tab saves a local return path alongside the PKCE verifier, validates it, and restores it without changing the game sign-in flow. The
`frontline://` scheme is registered by the game on its first launch; a link it doesn't know (like `open`) still
starts it, or brings a running copy to the front. The browser says nothing when no program takes a link, so Launch
watches for the page losing focus (the browser's "Open Frontline?" prompt, or the game's window) and, if that doesn't
happen, says how to get the game going the first time (`src/lib/launch.ts`).

Every page at a fixed address is a file of its own: after `vite build`, `scripts/prerender.mjs` writes each page
listed in `src/lib/pages.ts` (the front page, Play, Battles, the boards, Updates, the Field Manual and every one of its
entries) with its own title, description, link card and canonical address, so search engines and chat apps, which
don't run the site's code, show that page and not the front page. It also writes `sitemap.xml`, `robots.txt` and
`404.html`. nginx serves those files; a player's page and a battle's (`/player/...`, `/watch/...`) get the site, which
fetches them; any other address gets the site's "no such page" with a real 404. Keep `src/lib/pages.ts` in step with
the router and each page's title (its unit test checks every path is a route). `SITE_URL` sets the address the cards
and the sitemap use (the production one by default). The dev server and `vite preview` still answer every address
with the site. Pages other than the front page are fetched when first visited, and so is Home's What's new (it
reads the whole changelog). The game opens a few of the front page's addresses, and older copies
will go on opening them, so they keep working: `/?sign-in=` (the game's sign-in, handled on any page by
`src/pages/layout.tsx`), `/?join=<id>` (sent on to `/battles`), `/#download` (sent on to `/play#download`) and
`/changelog/#vX.Y.Z`. `/account`, the profile's old address, goes to `/profile`, `/vehicles` (the old roster) to
`/manual/vehicles`, `/manual/<section>?entry=<key>` to the entry's own address, and the front page's old sections
(`/#insignia`, `/#battles`) to their pages.

A visitor on a phone or tablet (`guessDevice`), where the game doesn't run, is offered **Send to my computer** (the
share sheet, or the link copied) instead of a download, on Home and on Play.

Every page sits on the game's menu backdrop, its living topographic map (`src/components/topo-backdrop.tsx`, with the
shader ported line for line from `scripts/ui/topo_backdrop.gd` in `src/lib/topo-shader.ts`: port it again when the
game's changes). It's a WebGL 2 canvas fixed behind the page, quieter behind the content column, drawn thirty times a
second at no more than about 2.6 million pixels, still for reduced motion, resting in a hidden tab, and not drawn at
all without WebGL 2 or with only a software renderer (the page keeps its plain ground). The body has no background of
its own so the map shows through: give a section a background only when it needs one.

The **Ranks** page explains ranks and shows the whole collection of insignia (the patches a player wears as their
icon). Signed in with a game account (through the matchmaker: `src/lib/account.ts`), it and the profile show the
player's rank, XP and record, and the collection with the unlocked insignia ready to pick. Players sign in with
GitHub (OAuth with PKCE, through the matchmaker). GitHub always comes back to the front page with `?code=`, where the
sign-in dialog opens and says it's signing them in (or why it couldn't); Supabase sends it there only if the site's
address is in its Redirect URLs (see the matchmaker's README). Email and password are for testing, offered only on
the dev server or a site built against another matchmaker (`EMAIL_SIGN_IN` in `src/lib/config.ts`). The game signs in here
too: its Sign in opens the site with `?sign-in=<state>`, and once the player has signed in, the site hands the game
a session of its own in a `frontline://sign-in/...` link (`src/lib/game-sign-in.ts`, `game-sign-in.tsx`). The catalog
(`src/lib/insignia.json`) and the art (`public/insignia/<id>.svg`) are generated by the game with
`--insignia-dump=web`, so the site and the game always agree; don't edit them by hand, change the game and dump again.

React 19, Vite, TypeScript, Tailwind 4 and [shadcn/ui](https://ui.shadcn.com) (the Lyra style, recoloured with the
game's palette from `scripts/ui/ui_kit.gd`). Needs Node 22.12 or newer.

```bash
npm install
npm run dev
```

It reads the live matchmaker by default. To use a local one, put `VITE_MATCHMAKER_URL=http://127.0.0.1:8787` in
`.env.development.local`. The latest release (`src/release.json`) and the changelog (`src/changelog.json`) are built in:
the release workflow rewrites both on the release's pull request, and merging that redeploys the site. Don't edit them
by hand; the changelog comes from `changelog/` at the top of the repo.

## Storybook

```bash
npm run storybook
```

opens [Storybook](https://storybook.js.org) on port 6006: every component and section of the page on its own, in
each state it can be in (loading, the matchmaker down, nobody hosting, a full or closed battle...), and every page of
the site (`Pages/...`) through its real router, against a stand-in matchmaker. Nothing in it talks to the live
matchmaker, and frontline:// links only report the click instead of opening the game.

Stories sit next to their components (`battles.stories.tsx` by `battles.tsx`), and the made-up lobbies, player and
release they show are in `src/test/fixtures.ts`. A new component should come with stories for its states. Many have
a `play` function that clicks through the story and checks the result. A page's story renders the whole site at an
address (`SiteAt` in `src/test/router.tsx`, with `parameters.router: false`); every other story gets a router of its
own, for its links. `mockMatchmaker` (`src/test/network.ts`) answers the page's requests, and `signedIn(player)` signs
the page in, and `awayAtGitHub()` lets a page come back from GitHub (`/?code=`) to be signed in. Neither saves
the session: stories run side by side in frames that share `localStorage`.

## Checks

| Command                   | What it does                                                                            |
| ------------------------- | --------------------------------------------------------------------------------------- |
| `npm run lint`            | [oxlint](https://oxc.rs), including Storybook's rules for the stories                   |
| `npm run format:check`    | [Prettier](https://prettier.io) (`npm run format` fixes it), Tailwind classes in order  |
| `npm run typecheck`       | TypeScript                                                                              |
| `npm run test:unit`       | the data code in `src/lib` (`*.test.ts`), in Node                                       |
| `npm run test:stories`    | every story in headless Chromium: its `play` function, and an accessibility check (axe) |
| `npm test`                | both kinds of test                                                                      |
| `npm run build`           | type-checks and builds the site to `dist/`                                              |
| `npm run build-storybook` | builds the Storybook to `storybook-static/`                                             |

The story tests need Playwright's Chromium once: `npx playwright install chromium`.

CI (`.github/workflows/web.yml`) runs all of these on every push and pull request that touches `web/`, and keeps the
built Storybook as a workflow artifact (`storybook`) you can download and open. When a story test fails there, the
screenshots of the failing stories are kept too (`story-failures`).

The files under `src/components/ui/` come from shadcn (`npx shadcn add ...`) and are formatted the way it writes them
(80 columns); the rest of the code is 120.

## Footage

Every clip in `public/media/` was recorded in the game itself with Godot's movie writer, off-screen, then cut
and encoded as H.264 MP4 (with each clip's first frame as its `.jpg` poster). The hero loop and the feature
clips are silent; `reel.mp4`, behind "Watch the footage", keeps the game's own sound, with captions describing it.
The page only loads a clip when it scrolls into view, and shows the still instead to people who prefer reduced
motion or have Data Saver on. The hero's loop waits until the page has loaded (the still is the first paint), and
on a phone or tablet the hero and the closing section show the still only: 3.4 MB of background video isn't worth a
phone's data, and Watch the footage is a tap away.

The Updates page's lists and galleries show small copies of the changelog's pictures, which the image's build makes
(`.github/scripts/changelog_thumbs.py` into `public/changelog-thumbs/`, not committed); without them (the dev server)
they fall back to the pictures themselves.

The text the page quotes (the counts, the missions, the radio traffic, the vehicle names) lives in
`src/lib/intel.ts`, taken from the game's own tables.

When the game changes, the `website-footage` skill (`.agents/skills/website-footage/`) brings both up to date:
`check_intel.py` checks the copy against the game (and `--fix` updates the counts), `record.py` re-records the
takes listed in its `shots.json`, and `build.py` cuts and encodes them into `public/media`. Its `SKILL.md` walks
through it, with the flags that make good footage.

## Deploying

The `web` service in Railway's `frontline` project builds **from the repository root**,
using the Dockerfile builder with `/Dockerfile.web`. Do not set the root to `/web`:
the roster imports game tables outside that directory, and the image exports the
Godot browser viewer before building the site. Railway's old static build omits both.

Keep these service settings together:

- Root directory: `/`; Dockerfile path: `/Dockerfile.web`.
- Watch paths: `/**` (the embedded viewer uses the game source).
- Wait for CI: enabled; the Website workflow builds and checks the same image.
- Healthcheck path: `/game/viewer.json`; no custom build or start command.

Pushes to `main` deploy automatically. For a manual upload, run
`railway up --service web --ci` **from the repository root**.

nginx keeps the hashed bundles in `/assets/` for good and answers a missing one with a 404, never the page, and
`index.html` is always revalidated. A tab opened before a deploy still asks for the old build's bundles when it
first visits a page: the router reloads it once onto the new build (`src/lib/stale-build.ts`) instead of failing
with a MIME-type error. The smoke check asserts the 404.

The **Production website** workflow reports Railway's failed/error web status as a
failed Actions run, even while the previous website remains online. It also checks
the production HTML, viewer manifest, and WASM after a successful deploy and hourly.
Skipped deployments do not count as successful updates. In GitHub notification
settings, enable Actions notifications for failed workflows; delivery follows each
user's notification preferences. Railway workspace deployment-failure notifications
provide another independent alert. An HTTP 200 from the homepage alone does not
prove the latest deployment succeeded.

## Battle viewer

`/battles` lists live broadcasts and recordings; `/watch/:id` embeds the actual Godot observer. Build `Dockerfile.web` with repository-root context to include the browser export at `/game/`. A local Vite build needs the complete source checkout and reports the viewer unavailable until the browser export is installed. See [recording deployment](../docs/REPLAYS.md).

The **Field Manual** (`/manual`) reads the literal game tables in `scripts/autoload/defs.gd` and
`scripts/game/vehicle_roster.gd` at build time (`src/lib/manual.ts`): soldiers, squads, the weapons something carries,
vehicles (built, called in as air support, automatic supply, and the Field Manual's reference garage), buildings,
fire support and upgrades, with the figures and labels the in-game manual works out (`scripts/ui/field_manual.gd`).
Keep the source checkout available when building the site; Docker copies these two inputs explicitly. Its unit test
checks every table entry is represented and spot-checks the figures. Changes to the tables' format need a matching
update to `src/lib/manual.ts`. The overview's prose (`src/pages/manual.tsx`) describes how the game plays: keep it
true when that changes.

Each catalogue embeds one model at a time. Search, filters, figures and camera buttons are React/CSS; the iframe
renders only the Field Manual's model stage, using its existing models, lighting and camera, and opens any entry by
its key (vehicles, soldiers, squads, weapons, buildings and fire support; upgrades have none). The browser build
accepts `?manual=<entry key>` and skips the menu and battlefield. `/game/viewer.json` advertises `manual: 3`; older
or missing exports keep the text catalogue usable. Build the Web export and run `.github/scripts/viewer_manifest.py
web/public/game` from the repository root to enable it locally. Camera messages are accepted only from the
same-origin parent, and readiness messages only from the selected iframe. Embedded models remain still until dragged
or rotated with the buttons. The viewer is the whole game (about 250 MB compressed on a first visit, which
`viewer.json`'s `bytes` gives), so it waits behind **Load 3D models**, with its size, until the visitor has loaded it
once on that device (remembered in `localStorage`).

The model viewer stays mounted across selection, empty search results and moving between catalogues. Once ready, it receives the latest selection through the same-origin message bridge and acknowledges the rendered vehicle key. The export packaging script precompresses WASM, PCK and JavaScript; nginx serves these gzip files when supported, retaining cache revalidation across deployments.

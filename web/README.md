# Frontline website

The game's website. Its pages (`src/pages/`, routed by React Router in `src/router.tsx`):

| Page                           | What's on it                                                                                                                                                 |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `/`                            | signed out: the game tour; signed in: play shortcuts, progress and updates (the tour remains at `/#intel`)                                                   |
| `/play`                        | download first on a new device; launch first after a successful game handoff; Find Match and platform downloads                                              |
| `/battles`                     | every battle being hosted, each with a **Join** link (`frontline://join/<id>`), and a friend's invite                                                        |
| `/leaderboards`                | the commanders with the most XP: all time, this month, this week (`?period=`, `?page=`); find a player                                                       |
| `/player/:callsign`            | anyone's public page: rank, XP, record, place on the board; their career and battles, unless kept back                                                       |
| `/player/:callsign/battle/:id` | one of their battles: its after-action report (their part, every commander, the two sides)                                                                   |
| `/ranks`                       | the public rank guide: XP thresholds and unlocks; insignia selection lives in `/profile`                                                                     |
| `/profile`                     | signed in, your rank and record, your callsign (rename it), your picture, whether your battles are public, the insignia you wear, and signing out everywhere |
| `/changelog`                   | every release, with its changes and screenshots                                                                                                              |

The header keeps four destinations: **The game**, **Battles**, **Commanders** and **Updates**, plus **Play** and the account menu. Commanders groups the leaderboards and rank guide under a shared secondary navigation. GitHub and project links live in the footer. Personal settings and insignia selection live in the profile; the account menu also links the public record.

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

Railway serves `index.html` for any address that isn't a file, and the router takes it from there. Pages other than
the front page are fetched when first visited. The game opens a few of the front page's addresses, and older copies
will go on opening them, so they keep working: `/?sign-in=` (the game's sign-in, handled on any page by
`src/pages/layout.tsx`), `/?join=<id>` (sent on to `/battles`), `/#download` (sent on to `/play#download`) and
`/changelog/#vX.Y.Z`. `/account`, the profile's old address, goes to `/profile`, and the front page's old sections
(`/#insignia`, `/#battles`) to their pages.

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
motion or have Data Saver on.

The text the page quotes (the counts, the missions, the radio traffic, the vehicle names) lives in
`src/lib/intel.ts`, taken from the game's own tables.

When the game changes, the `website-footage` skill (`.claude/skills/website-footage/`) brings both up to date:
`check_intel.py` checks the copy against the game (and `--fix` updates the counts), `record.py` re-records the
takes listed in its `shots.json`, and `build.py` cuts and encodes them into `public/media`. Its `SKILL.md` walks
through it, with the flags that make good footage.

## Deploying

It's the `web` service in the Railway project `frontline`, next to the matchmaker. From this directory:

```bash
railway up --service web --ci
```

Railway builds it with `npm run build` and serves `dist/` as a static site.

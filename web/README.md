# Frontline website

The game's front page: the battles being hosted right now (from the matchmaker), a **Join** button on each that
opens the game and connects you (`frontline://join/<id>`, registered by the game on its first launch), and the
latest downloads, and a Changelog page (`/changelog/`) with every release.

React 19, Vite, TypeScript, Tailwind 4 and [shadcn/ui](https://ui.shadcn.com) (the Lyra style, recoloured with the
game's palette from `scripts/ui/ui_kit.gd`). Needs Node 22.12 or newer.

```bash
npm install
npm run dev
```

It reads the live matchmaker by default. To use a local one, put `VITE_MATCHMAKER_URL=http://127.0.0.1:8787` in
`.env.development.local`. The latest release (`src/release.json`) and the changelog (`src/changelog.json`) are built
in: the release workflow rewrites both and commits them, and Railway redeploys the site. Don't edit them by hand;
the changelog comes from `changelog/` at the top of the repo.

`npm run build` type-checks and builds to `dist/`; CI runs it with `npm run lint` on every push.

## Deploying

It's the `web` service in the Railway project `frontline`, next to the matchmaker. From this directory:

```bash
railway up --service web --ci
```

Railway builds it with `npm run build` and serves `dist/` as a static site.

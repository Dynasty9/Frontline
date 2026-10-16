# Frontline website

The game's front page: footage recorded in the game, its missions, the battles being hosted right now (from the
matchmaker), a **Join** button on each that opens the game and connects you (`frontline://join/<id>`, registered by
the game on its first launch), the latest downloads, and a Changelog page (`/changelog/`) with every release.

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

## Footage

Every clip in `public/media/` was recorded in the game itself with Godot's movie writer, off-screen, then cut
and encoded as H.264 MP4 (with each clip's first frame as its `.jpg` poster). The hero loop and the feature
clips are silent; `reel.mp4`, behind "Watch the footage", keeps the game's own sound. For example:

```bash
godot --path . --write-movie bridge.avi --fixed-fps 30 -- --mission=bridgehead --nohud --perf=0 --preset=ultra --pitch=-30
godot --path . --write-movie a10.avi --fixed-fps 30 -- --mission=bridgehead --nohud --perf=0 --preset=ultra --focus=-150,176 --zoom=42 --pitch=-22 --cam-yaw=0.5 --pan=0.8,0.3 --demo-support=a10 --demo-at=3
```

Without `--focus` the observer's director camera finds the fighting by itself; `--pitch` gives it a lower, more
cinematic angle. Keep clips short and small (the feature clips are about 1 MB each at 960×540): the page only
loads a clip when it scrolls into view, and shows the still instead to people who prefer reduced motion or have
Data Saver on. The text the page quotes (radio traffic, vehicle names, mission briefs, the numbers) lives in
`src/lib/intel.ts`, taken from the game's own tables.

## Deploying

It's the `web` service in the Railway project `frontline`, next to the matchmaker. From this directory:

```bash
railway up --service web --ci
```

Railway builds it with `npm run build` and serves `dist/` as a static site.

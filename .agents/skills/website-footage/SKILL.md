---
name: website-footage
description: Regenerate the Frontline website's gameplay footage and its game-derived copy after the game changes. Records takes of the game off-screen with Godot's movie writer, cuts them into the hero loop, the feature clips, the reel with sound and the mission-card stills (web/public/media), and checks the site's numbers, missions, radio lines and vehicle names (web/src/lib/intel.ts) against the game. Use this whenever the game's look, units, vehicles, fire support, missions or radio traffic change and the website should catch up, or when asked to refresh, re-record, recut or add website footage, the hero video, trailer, reel, GIFs, clips, posters or mission images, or to check that the site still tells the truth about the game.
---

# Website footage

The front page (web/) shows the game with footage recorded in the game itself, and quotes the game: its vehicle and fire-support counts, its missions, its radio traffic, its vehicle names. Both drift as the game changes. This skill brings them back in line.

`shots.json` (in this folder) drives it: the **takes** (runs of the game to record, with their flags, what they show and where the action is), the **outputs** (clips cut from the takes) and the **stills**. The scripts in `scripts/` do the work; run them from the repository root.

| Made | Where the site uses it | From |
| --- | --- | --- |
| `media/hero.mp4` + `.jpg` | full-screen hero loop; also the closing section | `outputs.hero` |
| `media/{infantry,squads,armour,fires,sea}.mp4` + `.jpg` | the five feature rows (`clip:` in `web/src/components/features.tsx`) | `outputs.<name>` |
| `media/reel.mp4` + `.vtt` + `.jpg` | "Watch the footage" dialog, with sound and sound captions | `outputs.reel`, `stills.reel` |
| `media/m-<mission>.jpg` | mission cards | `stills.m-<mission>` |
| `COUNTS`, `MISSIONS`, `RADIO`, `HARDWARE`, `TICKER` | stats, tickers, feature copy, mission cards, radio log | `web/src/lib/intel.ts` |

## What you need

- **Godot 4.7** that can open a window (recording draws frames, so not `--headless`; on Windows either the plain or the `_console` exe): pass `--godot PATH` or set `GODOT`. Your notes on this machine may say where it is.
- **Python 3** with Pillow and numpy; **Node 22.12+** for the website's checks.
- **An encoder**: ffmpeg on the PATH, or Windows (Media Foundation via `scripts/encode_mf.ps1`; nothing to install).
- **The takes folder**: `--work DIR`, else `FRONTLINE_FOOTAGE_DIR`, else `<system temp>/frontline-footage`. Takes live in `WORK/takes/` (100-500 MB each, about 3 GB in all) and are kept between sessions on purpose: an output can only be rebuilt from the takes it was cut from, and each take's `NAME.json` records when and at which commit it was recorded. Don't put them in a session scratchpad, and don't delete them because they look stale. If they're gone, rebuilding any output means re-recording its takes and choosing all its cuts again.

## 0. Bring the checkout up to date

`record.py` records the game exactly as this checkout has it. Merge the base branch first (in a Codex worktree, its sync tool), or you'll film last week's game.

## 1. Find out what changed

```bash
python .Codex/skills/website-footage/scripts/check_intel.py
python .Codex/skills/website-footage/scripts/record.py --list
git log --oneline <commit from --list>..HEAD -- scripts assets project.godot
```

**check_intel.py** compares the site's copy with the game and prints `STALE` for anything wrong (exit 1). `--fix` rewrites `COUNTS`, which the stats, the ticker and the feature copy all read. Fix anything else stale by hand in `intel.ts`, using the game's own words: a renamed mission's title and blurb from `scripts/game/missions.gd`, a radio line from the mission that says it. A `note` (a mission's force line written shorter on the site) is fine while it's still true.

The script can't judge what's *worth saying*. Read the log of what changed: a new vehicle may deserve a place in the `HARDWARE` ticker, a new system a `TICKER` line or a word in a feature row's text and tags (`features.tsx`).

**record.py --list** shows each take's flags, what it **shows** (sea, night, tanks, ...), what it **feeds** (the outputs and stills cut from it), and when and at which commit it was recorded. Match the git log against it:

- A change you'd see in every shot (gunfire, explosions, smoke, lighting, soldier or vehicle models, the ground) means re-recording **every take**.
- A change to one kind of scene (the sea, helicopters, the town at night) means re-recording the takes that show it, and only them.
- Only copy changed? Skip to step 5.

Re-recording a take fans out: every output and still it feeds has to be re-cut (step 3), because the director camera and the AI never do the same thing twice, so the old cut times point at different moments.

## 2. Record

```bash
python .Codex/skills/website-footage/scripts/record.py beachhead-low airstrike-shore     # or --all
```

It copies the game into `WORK/project`, imports it, and records each take off-screen at a fixed 30 fps. Its window starts minimized and is moved off-screen, so nothing opens on the desktop. Each job draws about 5-6 frames a second, so all eleven takes take 20-30 minutes with the default `--jobs 3`: run it in the background. It finds free ports from 8700 up and reports a take that lost its port anyway (the game would have run as an observer). Each take gets a log beside it (`WORK/takes/NAME.log`); read it if a take looks wrong.

## 3. Choose the cuts

Make contact sheets (keep them in the work folder, not the repo) and look at them:

```bash
python .Codex/skills/website-footage/scripts/avi.py sheet WORK/takes/beachhead-low.avi WORK/sheets/beach.jpg --every 2
python .Codex/skills/website-footage/scripts/avi.py sheet WORK/takes/beachhead-low.avi WORK/sheets/beach-fight.jpg --from 28 --to 46 --every 0.5
```

Find the action, then update the `from`/`to` times of every cut from that take in `shots.json` (and the take's `about` notes, for next time). What makes a cut work:

- **Something happens in it**: an explosion, a muzzle flash, a vehicle moving, men running. Empty fields are the commonest failure: the director drifts over quiet ground between fights.
- **The camera is steady.** The director glides from one target to the next, quickly in a recording, because it paces itself by the wall clock while the movie runs slower than real time. Cut around the glides; the frames just before and after one are often the best.
- **Length**: about 2.5-3.5 s per cut in the hero (trailer pace), 3.5-4.5 s in a feature clip, up to about 5 s in the reel to let the sound land. A feature clip is one or two cuts of the same subject.
- **Variety in the hero**: day, golden hour and night; ground, air and sea.
- **Reel captions** describe what you'd hear; keep them true to what's on screen.

## 4. Build, look, install

```bash
python .Codex/skills/website-footage/scripts/build.py hero sea reel m-beachhead      # outputs and/or stills by name
```

Build what you re-cut, by name (`--all` only after re-recording everything; `--stills` builds every still). Each lands in `WORK/build/` with `NAME.preview.jpg`, a contact sheet of the result. **Look at every preview**: it's the only way to catch a cut that starts on a glide or lands on empty ground. Adjust and rebuild until they're right, then build again with `--install` to copy them into `web/public/media`. It reports each clip against its `max_kb` budget (hero 4 MB, a feature clip 1.3 MB, the reel 7.5 MB; today they're about 3.5, 1 and 6.7). The budgets keep the page fast and the repository small: if a clip runs over, shorten it or lower its `kbps`; don't raise the budget. An output rebuilt from unchanged takes and cuts on the same machine comes out byte-identical, so git only shows what you really changed.

## 5. Check the site and ship it

```bash
python .Codex/skills/website-footage/scripts/check_intel.py
cd web && npm ci && npm run lint && npm run format:check && npm run typecheck && npm run test:unit && npm run test:stories && npm run build
```

`check_intel.py` also confirms every clip and still the page uses is in `web/public/media`. The story tests need Playwright's Chromium once (`npx playwright install chromium`). Then look at the page (`npm run dev`) at desktop and phone widths: the hero playing, the feature clips playing as they scroll in, the reel with its sound. A website-only change needs no changelog entry. Commit `shots.json` with the media, so the next run starts from these cuts.

## Shooting something new

Add a take to `shots.json`: `frames` = seconds × 30 plus a few seconds' spare, `shows`, and `about`. Record it, find the action, and add or change an output or still. To put a new output on the page, wire it in: a `clip:` name in `features.tsx`, an `m-<key>.jpg` still for a new mission, and so on.

The game's command-line flags are listed under "Automated test modes" in `docs/DEVELOPMENT.md` (the current list: check it for new ones). The ones that make good footage:

- `--mission=bridgehead|beachhead|skyhook|ambush|kingpin`: the missions play themselves on real maps, with towns, rivers and the sea. Prefer them to the `--scenario=...` test setups, whose ground shows holes at a low camera.
- `--pitch=-22..-34` lowers the camera for a cinematic angle (negative degrees; a positive pitch puts it under the ground). Without `--focus` the director camera finds the fighting itself.
- `--focus=X,Z --zoom=40..60 --cam-yaw=RAD --pan=VX,VZ` holds the camera on a spot with a slow drift (the director then stays off).
- `--demo-support=a10|ac130|airstrike|artillery|barrage|mortars|...` with `--demo-at=SECONDS` calls fire support onto the focus, flying across the screen: an A-10 hits about 6 s after the call, a jet's bombs about 5 s, a rocket barrage about 8 s.
- `--mood=golden|dawn|dusk|night|overcast|...` sets the light (missions bring their own).

To find where and when things happen in a mission, run it headless first. It prints the map's features and every radio message as it happens:

```bash
FL_DEBUG_MISSION=1 godot --headless --path . -- --mission=beachhead --verbose --quit-on-win --timescale=4 --stats=10 --port=8690
```

Things that bite:

- `--perf-at` quits about 10 s after it fast-forwards, so it can't skip a quiet opening. Record from the start and cut later (the ambush take is 135 s for 8 s of fire).
- `--resolution` is ignored off-screen: takes come out 1600x900 and outputs are scaled down from that.
- The user's own `settings.cfg` loads, and its master volume may be 0; `record.py` turns it up to 0.8 for the reel's sound.

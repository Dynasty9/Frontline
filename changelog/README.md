# The changelog

Every change to the game comes with an entry here, written for players. Merging it releases nothing: entries wait in
`changelog/unreleased/` until someone presses the release button and merges the pull request it opens, and that
release ships all of them. The release workflow files them under its version (`changelog/v0.1.6/`), names the release, and shows it on
[the website's Changelog page](https://web-production-5a4c1.up.railway.app/changelog/), in the GitHub release's
notes and in [CHANGELOG.md](../CHANGELOG.md). A pull request never touches a version number.

## Adding an entry

A pull request that changes the game (anything under `scripts/` or `assets/`, `project.godot`, `main.tscn`, the
export presets or the icon) adds a file to `changelog/unreleased/`. CI fails without one. If players needn't hear
about the change, label the pull request `no changelog` instead.

`changelog/unreleased/fire-and-smoke.md`:

```markdown
+++
title = "Fire that spreads"
summary = "Woods, hedges, timber roofs and wrecks catch fire now, and spread it downwind until they burn out."
kind = "new"
headline = true

[[screenshots]]
file = "grass-fire.jpg"
caption = "A grass fire creeping out from a shell hole"
+++

- **What burns:** trees, hedges, crates, watchtowers, tents, plank huts, timber roofs and parked cars.
- **What sets it alight:** shells and bombs (grenades rarely), shot-up cars, wrecked vehicles, and heavy rounds
  landing in long grass.
- A fire takes hold, roars, then dies down. At full blaze it spreads, far more readily downwind.
```

- **The file name** is the entry's id: lower-case words joined by hyphens.
- **`title`**: what changed, in a few words (at most 80 characters).
- **`summary`**: one or two sentences a player reads first (at most 320 characters).
- **`kind`**: `new`, `improved` or `fixed`.
- **`headline`** (optional): this entry names the release when several changes ship together. Otherwise the first
  new feature does. **`release_name`** (optional) names the release something else.
- **Details**, below the `+++`: markdown, usually a short list. Say what a player will notice, in plain words. Leave
  out file names and implementation.
- **Screenshots** go in a folder named like the entry, `changelog/unreleased/fire-and-smoke/`, listed under
  `[[screenshots]]` in the order to show them. Render them off-screen (see "Off-screen screenshots" in
  `docs/DEVELOPMENT.md`) and save them as JPEG at about quality 80, 1600×900, under 1.5 MB.

Check your entry with `python .github/scripts/changelog.py check`.

## Gameplay clips

Use **MP4 (H.264, yuv420p)** or **WebM (VP9)** for gameplay clips: both have pause, seek and fullscreen
controls. **GIF** also works in a `[[videos]]` block, with a button to switch between animation and its still
poster (restarting the GIF when played again). Clips loop muted while on screen and pause when scrolled away.
Reduced-motion and Data Saver preferences disable autoplay; players can still start clips with the controls.
Keep them short
(about 5–15 seconds), silent, at 720p or 900p, under 15 MB, and enable fast start for MP4.
Prefer video for detailed gameplay; reserve GIF for small, short loops.
Describe the visible change in the caption and entry text so the clip is not the only explanation.

Put the clip and a JPEG poster beside the entry's screenshots, and add this inside its `+++` block:

```toml
[[videos]]
file = "grass-fire.mp4"
poster = "grass-fire.jpg"
caption = "Fire spreads from the shell hole into the surrounding grass."
```

The poster follows the screenshot format and size limits above. Both names must refer to files directly in
the entry's folder. Multiple `[[videos]]` blocks appear in order below the screenshots. The website plays
them inline; GitHub release notes and `CHANGELOG.md` link to the release on the website.

## What happens at release

Releasing is **Actions > Release > Run workflow** on `main` (pick `patch`, `minor` or `major`, and optionally a
name). `python .github/scripts/changelog.py pending` lists what it would ship. The workflow runs `changelog.py
release`, which moves every waiting entry into `changelog/vX.Y.Z/`, writes `release.toml` there (the version's name,
date and the pull requests its entries came from), and regenerates `web/src/changelog.json` (what the website shows)
and `CHANGELOG.md`. That lands on a `release/vX.Y.Z` branch with a pull request that shows the release notes as
they'll be published, with the build waiting in a draft release. Nothing is public until that pull request merges:
merging it publishes the release on GitHub and puts it on the website. To change the name or the step, run Release
again: it rebuilds the release and updates the pull request. It won't release with no entries waiting.

A release gathers many entries, so several may set `headline` or `release_name`. The first of them (new before
improved before fixed, then by file name) names the release, unless the person releasing gives it a name.

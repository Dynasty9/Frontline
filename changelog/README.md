# The changelog

Every change to the game comes with an entry here, written for players. When it ships, the release workflow files the
entry under its version (`changelog/v0.1.6/`), names the release, and shows it on
[the website's Changelog page](https://web-production-5a4c1.up.railway.app/changelog/), in the GitHub release's
notes and in [CHANGELOG.md](../CHANGELOG.md).

## Adding an entry

A pull request that changes the game (anything under `scripts/` or `assets/`, `project.godot`, `main.tscn`, the
export presets or the icon) adds a file to `changelog/unreleased/`. CI fails without one. If players shouldn't get a
new version for the change, label the pull request `skip release` instead.

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

## What happens at release

The release workflow (`.github/workflows/release.yml`) runs `changelog.py release`. It moves the entries the version
was built with into `changelog/vX.Y.Z/`, writes `release.toml` there (the version's name and date), and regenerates
`web/src/changelog.json` (what the website shows) and `CHANGELOG.md`. A release that somehow has no entry gets one
written from its pull request's title and description.

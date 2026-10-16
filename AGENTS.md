# AGENTS.md

Notes for AI coding agents (Claude Code, Codex, Copilot and the like) working on Frontline. Humans may find it useful too. For the player-facing overview see the [README](README.md); for how each system works see [docs/FEATURES.md](docs/FEATURES.md).

## The project in one paragraph

Frontline is a squad-level military RTS written entirely in **GDScript for Godot 4.7** (standard build, not .NET). There is no build step and no asset pipeline: every model, effect, texture and sound is generated in code at runtime. Multiplayer is server-authoritative. The host simulates everything, including the AI, and clients only draw what they're sent.

## Where things are

```
project.godot, main.tscn       entry point (main.gd: menu <-> world, command-line test modes)
scripts/autoload/              singletons: defs.gd (all data tables), net.gd (ENet lobby), sfx.gd (synthesised sound), settings
scripts/game/world.gd          entity registry, replication, commands (execute_cmd), spatial queries
scripts/game/soldier*.gd       the soldier: simulation, behaviour tree (soldier_brain.gd), procedural model
scripts/game/squad*.gd         squads, battle drills and morale (squad_brain.gd), movement tactics (tactics.gd)
scripts/game/vehicle*.gd       vehicles: driving, crews (vehicle_brain.gd), models (vehicle_models.gd + vehicles/vm_*.gd)
scripts/game/commander_ai.gd   the AI commander; naval_ai.gd its navy; attack_plan.gd / ambush_plan.gd its plans
scripts/game/mapgen.gd         map generation and the --scenario test setups; towngen.gd the town; water.gd the water
scripts/game/missions.gd       the missions (content); mission_director.gd runs them (objectives, events, the end)
scripts/game/terrain.gd, nav.gd, hnav.gd   ground kinds, cover map, pathfinding grids (HPA*)
scripts/ui/                    HUD, minimap, Field Manual, menus
scripts/autoload/online.gd     the matchmaker client: battle list, Find Match, hole punching, optional account
scripts/autoload/links.gd      frontline:// links from the website: registering the scheme, handing a link to a running copy
scripts/autoload/updater.gd    the game's version, and updating itself from the latest GitHub release
matchmaker/                    the matchmaking service (Node, no dependencies; deployed on Railway, accounts via Supabase)
web/                           the website (React + Vite + shadcn, on Railway): live battles with Join links, downloads
export_presets.cfg, .github/workflows/release.yml   Windows and Linux builds: every merge that changes the game is released
docs/                          FEATURES.md (design), DEVELOPMENT.md (code layout, test flags)
design/                        logo and artwork used outside the game (not imported by Godot)
```

Data lives in tables: units, weapons, squads, buildings and upgrades in `scripts/autoload/defs.gd`, and most vehicles in `scripts/game/vehicle_roster.gd`. Behaviour lives in the class that behaves.

## Checking your work

Run every command from the repository root. `godot` means your Godot 4.7.x executable; on Windows use the `_console.exe` build so output reaches the terminal.

1. **Everything compiles.** This prints nothing when all is well:
   ```
   godot --headless --path . --import 2>&1 | grep -E "SCRIPT ERROR|Parse Error"
   ```
2. **The game runs.** Run the scenarios near your change and look for `SCRIPT ERROR` in the output. Every run needs its own `--port`:
   ```
   godot --headless --path . -- --scenario=attack --stats=60 --quit-after=60 --port=7901
   godot --headless --path . -- --aivai --seed=3 --timescale=5 --stats=300 --quit-after=1200 --port=7902
   ```
   Scenarios include `attack`, `breach`, `trenches`, `tank`, `tactics`, `naval`, `sling`, `roster` and `gdrill`; [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) has the full list. Missions play themselves headless: `--mission=bridgehead --verbose --quit-on-win --timescale=4` prints the radio traffic and objectives as they happen, and ends with `Mission accomplished` or `Mission failed`. `--stats=N` prints a state summary every N seconds and, at the end, the behaviour counters (`world.stat("key")`). Those counters are the cheapest way to confirm a behaviour actually fired: add one, run, grep for it.
3. **Multiplayer**, if you touched anything replicated: run a host and a client (see "Host / client" in DEVELOPMENT.md). The client prints `CLIENT entities=...` when it quits. If you touched matchmaking, run `npm test` in `matchmaker/` and the Find Match pair under "Matchmaker" in DEVELOPMENT.md. Bump `Net.NET_VERSION` when host and client stop understanding each other, so the matchmaker won't pair old and new builds.
4. **Visuals**: render off-screen and look at the image rather than guessing. Use `--screenshot=out.png --shot-at=SECONDS`, frame the shot with `--focus=X,Z --zoom=M --pitch=DEG --cam-yaw=RAD`, and add `--nohud` to hide the interface. `--manual=category,key,side` opens a Field Manual page.

CI (`.github/workflows/check.yml`) runs steps 1 and 2, the matchmaker's tests and the website's build and lint, on every push and pull request. `.github/workflows/release.yml` publishes a new version on every merge to `main` that changes the game (a `minor` or `major` label on the pull request bumps further, `skip release` skips it), and test-exports pull requests that change the export setup.

## How the code is written

- **Tabs**, and explicit types wherever the type isn't obvious from the right-hand side. GDScript can't infer through untyped values (`var x := some_dict.get(k)` and `var y := untyped_call()` are parse errors), so write `var x: float = ...`.
- **Comments explain why, in plain language**: what a real soldier, crew or commander does, and how the code models it. Match the voice and density of the code around you. Don't leave debug prints behind; gate optional diagnostics behind an environment variable (`if OS.has_environment("FL_DEBUG_X"):`).
- **The server is authoritative.** Gameplay runs only on the host (`world.srv`). Anything clients must see has to be replicated: per-tick state through each entity's `write_state` / `read_state`, one-off property changes through `world.push_props`, effects through `world.fx_event`, and static map data (roads, water) through RPCs from `world._client_ready`.
- **Determinism.** Use `world.rng` for gameplay randomness, so a seed reproduces a map and a fight. Map data is either replicated as entities or sent as a few shapes that every peer rasterizes identically (see `water.gd`).
- **Map size comes from `MapDims`** (`scripts/game/map_dims.gd`). Never hard-code the map's dimensions.
- **Performance matters.** Soldiers and vehicles are ticked in GDScript: avoid per-frame allocations in hot paths, use the spatial queries (`world.units_near`, `soldiers_near`, `structures_near`) rather than scanning every entity, and throttle expensive decisions with timers.

## Gotchas

- **A new `class_name`** isn't visible to other scripts until the project is re-imported (`godot --headless --path . --import`). Other scripts referencing it will show bogus errors until then.
- **Packed arrays are value types.** A `PackedFloat32Array` passed into a function is copied, so mutate member arrays in place instead.
- **Entities get freed.** Soldiers and vehicles can be despawned at any time. Check `is_instance_valid()` before touching a stored reference. `world.despawn` removes a soldier from his squad.
- **Ground and water shader colours are linear**, not sRGB. A colour that looks right in a picker comes out far too bright on the ground.
- **The terrain is flat** (y = 0, plus a deformation height field for craters, trenches and riverbeds). Buildings, trenches and line of sight all assume it, so adding hills is a large change, not a tweak.
- **Water** has two ground kinds: `TerrainMap.WATER` (deep: impassable on foot) and `SHALLOW` (wadable). Boats path on their own grid (`Nav.find_boat_path`), and separate bodies of water are labelled (`Nav.water_body`).
- **Shader instance uniforms** come from a fixed buffer (`rendering/limits/global_shader_variables/buffer_size` in `project.godot`). If a bigger map spawns many more objects, raise it.
- **The host is busy for several seconds** generating the map, so ENet peers are given long timeouts (`net.gd`). Don't shorten them.
- **Headless test runs** each need a distinct `--port`. A running game holds the default port.
- **Test runs use the live matchmaker** unless given `--matchmaker=URL`, and only the menu's Host Multiplayer and Find Match (or `--host --list`) list a battle there. Single-player and scenario games never do.
- **The matchmaker keeps everything in memory**, so it runs as a single instance; the game re-lists its battle if the service restarts.

## Commits and pull requests

- Keep each change coherent and tested (see above). Commit messages: a short summary line, then what changed and why.
- If you add a unit, behaviour or system, update the matching section of [docs/FEATURES.md](docs/FEATURES.md), and the README if players would notice it.
- For visual changes, include before and after screenshots, rendered off-screen.

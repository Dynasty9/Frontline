# AGENTS.md

Notes for AI coding agents (Claude Code, Codex, Copilot and the like) working on Frontline. Humans may find it useful too. For the player-facing overview see the [README](README.md); for how each system works see [docs/FEATURES.md](docs/FEATURES.md).

## The project in one paragraph

Frontline is a squad-level military RTS written entirely in **GDScript for Godot 4.7** (standard build, not .NET). There is no build step and no asset pipeline: every model, effect, texture and sound is generated in code at runtime. Multiplayer is server-authoritative. The host simulates everything, including the AI, and clients only draw what they're sent.

## Where things are

```
project.godot, main.tscn       entry point (main.gd: menu <-> world, command-line test modes)
scripts/autoload/              singletons: defs.gd (all data tables), net.gd (ENet lobby), sfx.gd (synthesised sound), settings,
                               keys.gd (every key binding: ask it, never test a keycode in gameplay or UI code)
scripts/game/world.gd          entity registry, replication, commands (execute_cmd), spatial queries
scripts/game/soldier*.gd       the soldier: simulation, behaviour tree (soldier_brain.gd), procedural model
scripts/game/squad*.gd         squads, battle drills and morale (squad_brain.gd), movement tactics (tactics.gd)
scripts/game/vehicle*.gd       vehicles: driving, crews (vehicle_brain.gd), models (vehicle_models.gd + vehicles/vm_*.gd)
scripts/game/commander_ai.gd   the AI commander; naval_ai.gd its navy; attack_plan.gd / ambush_plan.gd its plans
scripts/game/mapgen.gd         map generation and the --scenario test setups; towngen.gd the town; water.gd the water (water_view.gd how it looks)
scripts/game/missions.gd       the missions (content); mission_director.gd runs them (objectives, events, the end)
scripts/game/co_command.gd     co-commanders: each player's view, cursor and plans, pings, sketches (relayed to their side only)
scripts/game/terrain.gd, nav.gd, hnav.gd   ground kinds, cover map, pathfinding grids (HPA*)
scripts/ui/                    HUD, minimap, Field Manual, menus
scripts/test/                  test runs: their exit code (test_run.gd), the test port (test_port.gd), the camera and key tests
tests/                         tests that drive the game through its test port (Node, no dependencies; lib/game.mjs the client)
scripts/autoload/online.gd     the matchmaker client: battle list, Find Match, hole punching, LAN beacons, optional account
scripts/autoload/links.gd      frontline:// links from the website: registering the scheme, handing a link to a running copy
scripts/autoload/updater.gd    the game's version, and updating itself to the latest release
scripts/autoload/errors.gd     error reports from release builds (and crashes, at the next launch) to the matchmaker
changelog/                     one entry per change, filed under its version at release; CHANGELOG.md is generated
matchmaker/                    the matchmaking service (Node, no runtime dependencies; deployed on Railway, accounts via Supabase)
matchmaker/supabase/migrations/   the accounts database's schema, one migration per change; database.yml applies new ones as they merge
web/                           the website (React + Vite + shadcn + React Router, on Railway): src/pages/ its pages (Play,
                               live battles with Join links, your account, the changelog); Storybook for its components
                               and pages (*.stories.tsx next to each)
export_presets.cfg, .github/workflows/release.yml   Windows, macOS, Linux and browser builds: a release is a button (Actions > Release)
                               that opens a release pull request, and merging that publishes it (publish.yml); no other merge releases
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
2. **The game runs.** Run the scenarios near your change. A test run exits with code 1 if a script error happened anywhere in it (it prints `TESTRUN failed` and the errors are in the output as `SCRIPT ERROR`), 0 if it ran clean. `--fixed-fps 30` (an engine switch, before the `--`) steps the game exactly as it plays, one 1/30 s tick a frame, as fast as the computer goes; `--seed` makes the run repeat itself exactly. Runs on their own take no port, so any number can run at once:
   ```
   godot --headless --fixed-fps 30 --path . -- --scenario=attack --seed=3 --stats=60 --quit-after=60
   godot --headless --fixed-fps 30 --path . -- --aivai --seed=3 --stats=300 --quit-after=600
   ```
   A small scenario runs several times faster than real time; a full AI-vs-AI battle about at real time. `--timescale=N` gets through a battle faster, but coarser: every tick covers N/30 s instead of 1/30, so it isn't the game as played (fine for a look at the late game, not for judging behaviour). Scenarios include `attack`, `breach`, `trenches`, `tank`, `tactics`, `naval`, `sling`, `roster`, `gdrill` and `fire`; [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) has the full list. Missions play themselves headless: `--mission=bridgehead --verbose --quit-on-win --timescale=4` prints the radio traffic and objectives as they happen, and ends with `Mission accomplished` or `Mission failed`. `--stats=N` prints a state summary every N seconds and, at the end, the behaviour counters (`world.stat("key")`). Those counters are the cheapest way to confirm a behaviour actually fired: add one, run, grep for it.
3. **Tests.** `tests/` drives the game through its test port (`--test-port`): load a scenario, mission or battle with a seed, give orders as a commander would, step time, ask what happened. Run them with `npm test` in `tests/` (set `GODOT` to your Godot executable). When you add or fix a behaviour, add a test that shows it: [tests/attack.test.mjs](tests/attack.test.mjs) is the pattern (one game per file, loaded afresh for each test: starting a game costs several seconds, a load a few more), and "The test port" in DEVELOPMENT.md lists the commands. `tests/determinism.test.mjs` catches gameplay that has escaped the seed. Every scenario has an expectation, a row in `tests/scenarios-*.test.mjs`: add one when you add a scenario, and update it when you change what one shows ("Scenario expectations" in DEVELOPMENT.md). `FL_TEST_LONG=1` also plays every mission to the end and expects it won (`tests/missions.test.mjs`, a few minutes; CI leaves it out).
4. **Multiplayer**, if you touched anything replicated: run a host and a client (see "Host / client" in DEVELOPMENT.md). The client prints `CLIENT entities=...` when it quits. If you touched matchmaking, run `npm test` in `matchmaker/` and the Find Match pair under "Matchmaker" in DEVELOPMENT.md. Bump `Net.NET_VERSION` when host and client stop understanding each other, so the matchmaker won't pair old and new builds.
5. **Visuals**: render off-screen and look at the image rather than guessing. Use `--screenshot=out.png --shot-at=SECONDS`, frame the shot with `--focus=X,Z --zoom=M --pitch=DEG --cam-yaw=RAD`, and add `--nohud` to hide the interface. `--manual=category,key,side` opens a Field Manual page.

CI (`.github/workflows/check.yml`) runs steps 1 to 3 on every push and pull request. `web.yml` and `matchmaker.yml` check the website and the matchmaker when they change: lint (oxlint), formatting (Prettier), tests, and for the website types, the build and the Storybook stories. Before pushing a change there, run `npm run lint`, `npm run format:check` and `npm test` in that directory (`npm run format` fixes the formatting). Merging a change never releases it. Releasing is one press and one merge: `.github/workflows/release.yml` (Actions > Release > Run workflow) builds everything merged since the last release, drafts it and opens its pull request, and merging that pull request publishes it (`publish.yml`). The Release workflow also test-exports pull requests that change the export setup.

## How the code is written

- **Tabs**, and explicit types wherever the type isn't obvious from the right-hand side. GDScript can't infer through untyped values (`var x := some_dict.get(k)` and `var y := untyped_call()` are parse errors), so write `var x: float = ...`.
- **Comments explain why, in plain language**: what a real soldier, crew or commander does, and how the code models it. Match the voice and density of the code around you. Don't leave debug prints behind; gate optional diagnostics behind an environment variable (`if OS.has_environment("FL_DEBUG_X"):`).
- **The server is authoritative.** Gameplay runs only on the host (`world.srv`). Anything clients must see has to be replicated: per-tick state through each entity's `write_state` / `read_state`, one-off property changes through `world.push_props`, effects through `world.fx_event`, and static map data (roads, water) through RPCs from `world._client_ready`.
- **Determinism.** Use `world.rng` (or a generator seeded from it) for gameplay randomness, so a seed reproduces a map and a fight. `randf()`, `Array.shuffle()` and `pick_random()` draw on Godot's global generator, which no seed reaches, and gameplay must never hang on the wall clock (`Time.*`) or the frame rate. Map data is either replicated as entities or sent as a few shapes that every peer rasterizes identically (see `water.gd`).
- **Map size comes from `MapDims`** (`scripts/game/map_dims.gd`). Never hard-code the map's dimensions.
- **Performance matters.** Soldiers and vehicles are ticked in GDScript: avoid per-frame allocations in hot paths, use the spatial queries (`world.units_near`, `soldiers_near`, `structures_near`) rather than scanning every entity, and throttle expensive decisions with timers.

## Gotchas

- **The database changes only by new migrations** (`supabase migration new <name>` in `matchmaker/`, see its README's "The database"). Never edit or remove one that's on `main`: the live database has already run it. Keep each one compatible with the matchmaker that's running (add, don't take away), since Railway's deploy and the release's migration can land in either order. `npm test` in `matchmaker/` runs them all on PGlite; add a test for any new rule.
- **A new `class_name`** isn't visible to other scripts until the project is re-imported (`godot --headless --path . --import`). Other scripts referencing it will show bogus errors until then.
- **Packed arrays are value types.** A `PackedFloat32Array` passed into a function is copied, so mutate member arrays in place instead.
- **Entities get freed.** Soldiers and vehicles can be despawned at any time. Check `is_instance_valid()` before touching a stored reference. `world.despawn` removes a soldier from his squad.
- **Release builds swallow GDScript's own runtime errors.** In an exported build a null dereference or an out-of-range index prints nothing: the call just returns null and play goes on. Only engine errors and `push_error` reach the players' error reports (`autoload/errors.gd`), so script bugs have to be caught in dev runs and CI.
- **Worker threads** (`WorkerThreadPool`) pay off when each task works on objects of its own: many threads calling into one shared object (all reading the same `AStarGrid2D`, say) ran slower than a single thread. Never resize an Array or add to a Dictionary from a worker (filling pre-sized slots is fine), and give each worker its own `RandomNumberGenerator`, since the global `randf()` isn't thread-safe. Put anything gameplay depends on back together in a fixed order, so a seed still gives the same result (see `HNav.build_all`). Code that two threads can run at the same time must keep to typed values and must not divide whole numbers with `/` or `%`. An operator on an untyped value or an object (`x == null`), and in exported builds every `int / int` and `int % int`, rewrites its own bytecode the first time it runs, and a second thread reaching that line at that moment can crash the game (godotengine/godot#124010; debug builds and CI only ever hit the first kind). Look values up or shift instead (`HNav._corner`, `>> 1`).
- **Ground and water shader colours are linear**, not sRGB. A colour that looks right in a picker comes out far too bright on the ground.
- **The terrain is flat** (y = 0, plus a deformation height field for craters, trenches and riverbeds). Buildings, trenches and line of sight all assume it, so adding hills is a large change, not a tweak.
- **The browser build draws with the Compatibility renderer** (WebGL 2), not Forward+. Per-object shader values go
  through `Mats.set_inst`, never `set_instance_shader_parameter`; a particle emitter goes into the scene through
  `Vfx.part` (it becomes CPU particles there) and is handled with `Vfx`'s helpers, not as a `GPUParticles3D`; and
  depth reads and blending have rules of their own: see "The browser build" in DEVELOPMENT.md. Check a visual change with `--rendering-method
  gl_compatibility` too. In a browser there are no threads, sockets or UDP (`OS.has_feature("web")`).
- **Water** has two ground kinds: `TerrainMap.WATER` (deep: impassable on foot) and `SHALLOW` (wadable). Boats path on their own grid (`Nav.find_boat_path`), and separate bodies of water are labelled (`Nav.water_body`).
- **Shader instance uniforms** come from a fixed buffer (`rendering/limits/global_shader_variables/buffer_size` in `project.godot`). If a bigger map spawns many more objects, raise it.
- **The host is busy for several seconds** generating the map, so ENet peers are given long timeouts (`net.gd`). Don't shorten them.
- **Ports**: scenarios, `--aivai` and missions run offline and take none (`--listen` opens `--port` as before). Each `--host` and `--join` pair needs its own `--port`; a running game holds the default one.
- **Test runs use the live matchmaker** unless given `--matchmaker=URL`, and only the menu's Host a Battle (unless Unlisted) and Find Match (or `--host --list`) list a battle there. Single-player and scenario games never do.
- **The matchmaker keeps everything in memory**, so it runs as a single instance; the game re-lists its battle if the service restarts.

## Commits and pull requests

- Keep each change coherent and tested (see above). Commit messages: a short summary line, then what changed and why.
- **Every change to the game adds a changelog entry** for players: `changelog/unreleased/<what-changed>.md`, with its screenshots in `changelog/unreleased/<what-changed>/` ([changelog/README.md](changelog/README.md) shows the format). It waits there until the next release, which files it under that version's changelog on the website and GitHub. Never edit a version number, `CHANGELOG.md`, `web/src/changelog.json` or a `release.json`: the release writes those. CI fails a pull request that changes the game without an entry; label it `no changelog` if players needn't hear about it. Check it with `python .github/scripts/changelog.py check`.
- If you add a unit, behaviour or system, update the matching section of [docs/FEATURES.md](docs/FEATURES.md), and the README if players would notice it.
- For visual changes, include before and after screenshots, rendered off-screen. Put the ones players should see in the changelog entry's folder; the pull request can show them from the branch (`https://github.com/Dynasty9/Frontline/blob/<branch>/changelog/unreleased/<entry>/<file>.jpg?raw=true`), so there's no need for a separate assets branch.

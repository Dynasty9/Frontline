# Developing Frontline

How the code is laid out, and the command-line modes used to test it. See also [CONTRIBUTING](../CONTRIBUTING.md).

## Settings and the performance overlay

**Esc > Settings** (or Settings in the main menu): quality presets (Low / Medium / High / Ultra) and every
option on its own, laid out like a PC game's options screen:
- **Graphics:** shadow quality, texture filtering (anisotropic), view distance / detail (LOD), vegetation,
  effects quality, scorch marks and craters, ambient occlusion and its quality, screen-space indirect light,
  SDFGI global illumination, screen-space reflections (wet ground), volumetric fog and smoke,
  anti-aliasing (FXAA / SMAA / MSAA / MSAA + SMAA / TAA; High and Ultra use MSAA + SMAA, which keeps the
  procedural surfaces sharp and steady while the camera moves - TAA smears them in motion), upscaler
  (bilinear / AMD FSR 1 / AMD FSR 2), render scale, sharpening.
- **Lighting & Look:** time of day and weather (midday, golden hour, dawn, dusk, overcast, hazy, night with
  flares, rain and thunder; applies live), colour grading (natural, cinematic, vivid, warm film, cold steel,
  bleached war film, black & white), tonemapper (AgX / ACES / Filmic / Reinhard), brightness, contrast, bloom,
  film grain, tilt-shift depth of field.
- **Display:** window mode (windowed / borderless / exclusive fullscreen), window size (applied at launch; a
  size too big for the screen maximises the window instead; test runs keep the project's window or the size
  `--resolution` asks for), VSync, frame-rate cap, field of view, performance overlay.
- **Interface:** interface scale (relative to the window: `Settings.ui_factor()` is what the window's 2D is
  drawn at), unit activity labels, speech bubbles, cover preview, edge scrolling, camera speed, camera shake.
- **Audio:** master, music, effects, ambience and interface volumes (each its own mixer bus, set up in
  `sfx.gd`), music in battle on or off, mute while the window is in the background.

Settings are saved to `user://settings.cfg`.

**F3** cycles the performance overlay: off, FPS, compact (CPU / GPU / draw calls) and a full breakdown:
- a frame bar split into game logic, view scripts, render CPU and engine/idle time, with GPU time on a second bar
  and a CPU-bound / GPU-bound verdict
- min / max / 1% low FPS and a 240-frame frame-time graph
- the host simulation cost per tick by system (soldiers, structures, rules and fog, AI commanders...)
- this PC's per-frame script cost by system (soldier animation, effects, HUD, grass...)
- draw calls, objects, triangles, video memory, node count, entity counts, active effects, network traffic.

## Architecture

```
main.gd                 menu <-> World, command-line test modes
autoload/defs.gd        all data tables (units, weapons, squads, vehicles, buildings, upgrades)
autoload/net.gd         ENet host/join, lobby, teams, start
autoload/online.gd      the matchmaker client: listing, Find Match, STUN + hole punching, optional account
autoload/sfx.gd         procedurally synthesised sounds, the mixer's buses
autoload/music.gd       the soundtrack: synthesised instruments, a sequencer, the scores (menu, battle, stings)
game/world.gd           entity registry, replication (spawn / snapshot / props / fx RPCs), commands, queries
game/entity.gd          base class: props on spawn, packed state in snapshots
game/soldier*.gd        brain + procedural articulated model (body_mesh.gd: the lofted body shapes)
game/soldier_brain.gd   the soldier's behaviour tree: reflexes (grenades, shells, drones, melee), clearing houses, the fight
game/bt.gd              a small behaviour tree (selector, sequence, condition, action, cooldown)
game/squad.gd           shared knowledge, rescues, smoke, surrender, auto-engineering
game/squad_brain.gd     the squad's behaviour tree: battle drills, morale, fire discipline, ammo sharing
game/water.gd           rivers, ponds, the sea: laid out as shapes, rasterized into ground kinds and heights
game/naval_ai.gd        the AI's navy: docks, gunboat patrols, amphibious raids
game/tactics.gd         moving tactically (bounding overwatch, recon by fire), clearing houses, near ambush, stragglers, crews
game/ambush_plan.gd     a deliberate road ambush: rally point, the L, the killing zone, spring, withdraw
game/vehicle_brain.gd   the vehicle crew's behaviour tree: smoke and back out, front armour on, wait for infantry, repairs
game/map_dims.gd        the map's size, which everything sized to the map derives from
game/combat.gd          LOS, bullets (penetrating soft cover), suppression, explosions, choosing cover
game/fires.gd           what burns, catching alight, spreading downwind, burning down (server; drawn by vfx.gd)
game/cover.gd           fighting positions on everything solid, what each material stops, stances by height
game/rules.gd           supply network, trucks, cap, placement, capture, prisoners/intel, fog, victory
game/vision.gd          every eye a side has (men, vehicles, towers, drones, aircraft) as circles of sight
game/fog_view.gd        the fog of war drawn on the battlefield and the minimap (a sight map + a full-screen pass)
game/nav.gd             two AStarGrid2D layers (infantry: vaultable/slow cells; vehicles: smashable cells)
game/hnav.gd            hierarchical A* (clusters, entrances, danger-weighted abstract graphs)
game/terrain.gd         ground types, cover map, craters, speed / hit / concealment modifiers
game/trench_net.gd      the dug trench network (mask, walls, spoil, duckboards)
game/mapgen.gd          procedural battlefield + test scenarios
game/mission_director.gd   a mission on the server: objectives, scripted events, the end, co-op ownership
game/missions.gd        the missions' content: the catalogue, placing each by the map's features, its objectives and events
ui/hud_objectives.gd    a mission's objectives panel, clock and banners
game/towngen.gd         the town's street plan and lots, hamlet, farms, fields, power lines
game/physics_fx.gd      client physics: ground with the trenches cut in, ragdolls, chunks, tossed props
game/ragdoll.gd         the jointed ragdoll
game/decor.gd           street furniture built on each client (merged per chunk, wires, street lights)
game/weapon_models.gd   crew-served machine guns and their tripods (M240B, M2HB, PKM, DShKM)
ui/field_manual.gd      the field manual: catalog of everything with stats and 3D previews
ui/curtain.gd           the intro and loading screens
game/bevel_mesh.gd      chamfered boxes (every Res.box thicker than a sheet)
assets/                 splash.png and backdrop.png (made by a script from the emblem and a topographic map)
game/fx.gd              tracers, impacts, who is saying what, debris; drives vfx.gd
game/vfx.gd             GPU particle explosions, smoke, flames, char, grass fires, decals, shockwaves (+ their shaders)
game/atmosphere.gd      sky, sun, fog, ground shader, post effects, moods
game/grass.gd           instanced grass, bushes and stones
game/mats.gd            procedural surface uber-shader, foliage, camouflage netting
game/vehicle_models.gd  lofted procedural vehicle models (also used for wrecks and the menu); dispatches to
game/vehicles/          the Arma 3 models by family: vm_nato, vm_csat, vm_indep (AAF), vm_civ (FIA, Syndikat,
                        civilian), vm_heli, vm_plane, vm_boat; the support aircraft in vm_gunship (AC-130U,
                        V-44X Blackfish), vm_attack (A-10C, A-164 Wipeout) and vm_fighter (F/A-181, F-16C)
game/vehicle_roster.gd  the Arma 3 roster (stats, behaviour, tiers, patterns) and the Field Manual's garage
game/director.gd        observer camera and time controls
game/co_command.gd      co-commanders: each player's presence (view, cursor, selection, what's being lined up),
                        pings, sketches and committed actions, relayed by the host to that side only
ui/hud_coop.gd          co-commanders drawn over the battlefield; ui/hud_coop_roster.gd the Command Net
ui/hud.gd, menu.gd      interface; ui/settings_panel.gd, ui/perf_overlay.gd, ui/ui_kit.gd (shared style),
ui/hud_overlay.gd       everything drawn over the battlefield (labels, speech, symbols, orders, plans, intel)
ui/hud_orbat.gd, hud_layers.gd, hud_sel_info.gd, hud_minimap.gd, hud_top_info.gd, hud_toasts.gd   HUD widgets
ui/map_symbols.gd       NATO symbols and status icons
game/attack_plan.gd     the deliberate attack (plan, support by fire, flank, assault, consolidate)
ui/menu_scene.gd        live 3D menu backdrop
```

Networking is server-authoritative. Clients send command dictionaries (`World.send_cmd`). The host simulates at 30 Hz and
sends compact per-entity snapshots at 15 Hz (length-prefixed records chunked into roughly 1.1 KB unreliable packets), reliable
spawn/despawn/property events, and batched effect events. Clients interpolate. Team-only messages are only sent
to that team.

## Automated test modes

Pass these after `--` on the command line:

```
--aivai --timescale=8 --quit-after=900 --stats=60     AI vs AI, prints a state summary + behaviour counters
--scenario=cover|lean|grenade|tank|drone|tunnel|heli|defense|air|support|showroom|trenches|poses|attack|solo
                                                      (attack: two squads and a gun team attack a walled yard;
                                                      solo: one squad against a stronger position)
--play --select-first --tactical --nohud              command a scenario's Coalition side / select a squad /
                                                      open the tactical map / hide the HUD (perf tests)
--focus-struct=kind[,n] [--select-struct]            camera on a structure of a kind (and select it: its info panel)
                                                      (trenches: a Rebel trench system vs tanks + IFVs;
                                                      poses: every stance frozen for inspection; add --static
                                                      to leave the attackers out)
--demo-support=a10|ac130|airstrike|artillery|barrage|mortars|smoke   launch support at the camera focus
--model-test=a10,ac130,ifv                            show vehicle models next to the camera focus
                                                      small hand-built setups (add --debug-cover for cover traces)
--bot-defense                                         lay a trench line, build + crew a mortar pit, call a fire mission
--host --players=2 / --join=127.0.0.1 --team=0        two-process multiplayer test (--bot-cmds issues real commands,
                                                      --ai-allies adds AI commanders to both sides)
--quit-on-win                                         stop and print the winner when the game ends
--perf-at=480 [--perf-shot=path.png]                  fast-forward, then measure real FPS and server tick cost
--screenshot=out.png --shot-at=30 --focus=X,Z --zoom=40 [--shots=N --shot-every=0.5]
--mood=golden --perf=3 --preset=ultra                 lighting, overlay level and graphics preset for screenshots
--fx-demo=1.4 --fx-every=3                            set off explosions near the camera (visual test, no damage)
--cursor=0.5,0.4 --order-mode=defend --select-all     fake the mouse position / order mode (cover preview shots)
  --place=trench [--place-from=X,Z]                   with --cursor: show the placement ghost (or a dragged line)
--scenario=... --play                                 command the Coalition side of a scenario instead of watching
--focus-fob=0|1                                       keep the camera on that side's first FOB
--focus-town[=dx,dz] / --focus-decor=kind[,n]         camera on the town, or on a piece of street furniture
--blast-at=X,Z,SIZE,TIME                              a real explosion at that spot and time (physics tests);
                                                      X,Z of "f,DX" is DX metres beside the camera's focus
--pitch=-14 --cam-yaw=-0.84                           fixed camera pitch (degrees) and heading (model close-ups)
--cam-test                                            drive the camera through its controls (zoom to cursor, grab-pan,
                                                      turn and tilt, reset, saved views, follow, turning minimap) and
                                                      print CAMTEST ok / FAIL for each; needs a window, not --headless
                                                      (e.g. --mission=bridgehead --play --cam-test --offscreen)
--follow=TEAM[,N]                                     keep the camera on that side's Nth squad (tactics review)
--trace=path.csv                                      log every man twice a second (position, posture, phase) for plotting
--manual=CATEGORY[,ENTRY[,SIDE]]                      open the field manual on a page (in a battle)
--hud-panel=settings|help|menu|log [--settings-tab=T] open one of the battle's panels (layout checks; add
                                                      --set=ui_scale:3 for the largest scale the window allows)
--pan=VX,VZ / --set=key:value,...                     drift the camera (shimmer tests) / override single settings
--scenario=guns                                       every machine-gun emplacement and trench bay, crewed, with targets
--scenario=roster                                     every vehicle both sides can field, facing off across the map
--scenario=sling                                      a Mohawk carries a Humvee and a Taru a BTR on their slings
--scenario=naval                                      boats on the sea: an RHIB lands a squad under a patrol ship's guns, Rebel boats come out to fight
--scenario=tactics                                    a rifle squad and an MG team sent 120 m up to hold a hamlet with the
                                                      enemy about: they bound there by teams and clear the houses
--scenario=breach                                     a fighter cell holed up in a house; two rifle squads and a gun team clear it
--scenario=gdrill                                     grenade drill: frags with all sorts of fuses land among a squad round its wounded
--scenario=town                                       a rifle squad takes a village's supply dump, its lorry runs the stock to
                                                      FOB Alpha, then a Rebel cell comes to take it back (town_captured,
                                                      town_truck_delivered in the counters; --debug-trucks lists each town)
--scenario=fire                                       a wood, a hedgerow, crates, cars, a watchtower and a house, some of it alight
                                                      from the start, a fighter cell dug in among it (fire spread, burns, fleeing)
FL_DEBUG_FIRE=1 (env)                                 print who the fires burn, and (on a client) what it hears catching or going out
--scenario=recon                                      a manned watchtower, a recon pass over Rebel cells, a Rebel spotter plane and drone over the Coalition
FL_DEBUG_VISION=1 (env)                               every 2 s, what each side has eyes on (eyes, aircraft, recon photos, manned towers, enemies seen, intel)
--mission=bridgehead|beachhead|skyhook|ambush|kingpin  play a mission; on its own it plays itself (the autopilot in missions.gd)
--mission=KEY --play [--autoplay]                     command the mission's force yourself (--autoplay: the autopilot still gives orders)
--mission=KEY --seed=N                                the mission on another map (checks it still places itself sensibly)
--host --mission=KEY --players=2                      a co-op mission lobby that starts when the second player joins
--coop-demo[=N]                                       N made-up co-commanders on your side (host only: each gets a real
                                                      squad), looking about near you, lining up trenches, fire missions and
                                                      assaults, pinging and sketching (co-commander interface shots)
  --coop-watch[=I]                                    watch the Ith one's view live
--bot-presence                                        (a client, headless) this game's presence is made up the same way and
                                                      really sent, with its pings and sketches; COOP {...} at --quit-after
                                                      shows what each game sent and took in
--cursor=X,Y --ping-wheel                             hold the ping wheel open by the faked cursor (screenshots)
FL_DEBUG_COOP=1 (env)                                 the co-commander layer's cost by part, in the performance overlay
FL_DEBUG_MISSION=1 (env)                              print the map's features (bridges, villages, harbour) and the mission's setup
--model-sheet=KEYS|FAMILY --sheet-dir=DIR [--side=1] [--sheet-yaw=R]   turntable shots of models (nato, csat, indep, civ, heli, plane, boat, all)
--soldier-sheet=PATH [--sheet-team=0|1] [--sheet-view=front|back|rts] [--sheet-pose=idle|shoot|run|mix]
                                                      every kind of soldier lined up in daylight, saved as PATH
  [--sheet-unit=TYPE --sheet-seed=N | --sheet-seeds=N] [--sheet-stats]   one man turned four ways (or N men of
                                                      a type) close up; triangles, instances and build time per man
--manual=model,KEY,SIDE                               a bare model in the Field Manual
--curtain                                             show the intro / loading screens in an automated run
--menu-op=0|1|-1                                      open the New Operation panel on that side
--menu-missions[=KEY]                                 open the Missions panel (on that mission)
--startup-trace                                       print the first frames' timings
--test-fire                                           every armed man, gunner and vehicle fires ahead (muzzle tests)
--seed=N                                              (with --aivai) the same map every run
--dump-structs                                        list every built structure when --quit-after fires
FL_DEBUG_TOWNS=1 (env)                                print each town and village: name, dump and the ground that takes it
FL_DEBUG_HPA=1 (env)                                  benchmark hierarchical vs flat paths at start-up
FL_DEBUG_DECOR=1 (env)                                print the street-furniture chunk and mesh counts
--menu-shot=menu.png --shot-at=6                      screenshot of the main menu
--sound-dump=DIR                                      every synthesised sound and music sample as a WAV in DIR, then quit
                                                      (works --headless)
FL_DEBUG_MUSIC=1 (env)                                print the music's cue, battle heat and layer levels every 5 s
```

To hear (or measure) the mix as a player does, record it: Godot's movie writer saves the game's audio with
the video, e.g. `godot --path . --write-movie out.avi --resolution 320x180 --quit-after 3600 -- --mission=bridgehead`
(an MJPEG AVI with PCM sound; it runs at a fixed 60 fps, and the music keeps time with it).

Example:
`godot --headless --path . -- --aivai --timescale=8 --quit-after=600 --stats=120`

### Host / client

Two processes on one machine. Start the host, then the client a few seconds later (the host spends several seconds laying out the 1 km map):

```
godot --headless --path . -- --host --team=0 --players=2 --ai-allies --stats=100 --quit-after=200 --port=7935
godot --headless --path . -- --join=127.0.0.1 --team=1 --quit-after=200 --port=7935
```

The client prints a `CLIENT entities=...` summary when it quits. Check both outputs for `SCRIPT ERROR`.

Co-commanders: bot clients make up their presence, pings and sketches and really send them. Start the one on
the other side first, so its team request lands before the game starts:

```
godot --headless --path . -- --host --team=0 --players=4 --quit-after=60 --port=7975
godot --headless --path . -- --join=127.0.0.1 --team=1 --bot-presence --quit-after=55 --port=7975
godot --headless --path . -- --join=127.0.0.1 --team=0 --bot-presence --quit-after=55 --port=7975
godot --headless --path . -- --join=127.0.0.1 --team=0 --bot-presence --quit-after=55 --port=7975
```

Each client prints `COOP {"sent": ..., "taken": ..., "pings_in": ...}` when it quits: the two on team 0 take
each other's presence and pings, the one on team 1 takes nothing of theirs. To see it drawn, make one of the
team 0 clients a normal (windowed) game, or run `--coop-demo` on its own.

### Matchmaker

The matchmaker (`matchmaker/`, see its README) is a small Node service with its own tests:

```
cd matchmaker && npm test
```

To try the game against it, run one locally (`AUTH_BACKEND=memory` adds throwaway accounts) and point both games at
it with `--matchmaker=URL`. The host lists its battle with `--list`; the second game presses Find Match:

```
cd matchmaker && AUTH_BACKEND=memory PORT=8787 npm start
godot --headless --path . -- --host --list --players=2 --quit-after=60 --port=7941 --matchmaker=http://127.0.0.1:8787
godot --headless --path . -- --find-match --team=1 --quit-after=60 --port=7942 --matchmaker=http://127.0.0.1:8787
```

Set `FL_DEBUG_ONLINE=1` to print what STUN saw, who the host punches towards, and how the joiner connects (`via lan`,
`punch` or `direct`). On one machine both games share a public address, so the joiner takes the LAN path; to
exercise the hole-punching path, give the joiner the matchmaker's LAN address instead of `127.0.0.1` (it then only
connects if your router loops traffic back in, "hairpinning", which many don't). `--no-stun` skips STUN for offline
runs, `--login=EMAIL:PASSWORD` (plus `--signup=CALLSIGN` to create the account) signs in first, `--account=PATH`
keeps that sign-in out of your real one, and `--menu-panel=browse|account|settings` opens those panels for screenshots.
Without `--matchmaker` the game uses the live service on Railway.

### Join links

A `frontline://` link can be passed after `--`, as a browser would: `godot --path . -- frontline://join/LOBBY_ID`
(or `frontline://find-match`). Test runs (anything with a `--switch`) don't listen for links handed on by a second
copy unless given `--links`, so to test the hand-off: start a listed host, then an idle game with `--links`, then a
third copy with only the link. The third prints `LINKS handed ...` (with `FL_DEBUG_ONLINE=1`) and quits; the idle
one joins. Only exported builds register the scheme with the OS (`Links._register`).

### Website

`web/` is the website (React, Vite, Tailwind, shadcn/ui; see its README): `npm install && npm run dev`, with
`VITE_MATCHMAKER_URL` pointing at a local matchmaker if you like. CI builds and lints it.

### Builds, releases and updates

`export_presets.cfg` has a Windows and a Linux preset (one executable each, the game packed inside).
`.github/workflows/release.yml` releases automatically: every merge to `main` that changes the game (`scripts/`,
`assets/`, `project.godot`, `main.tscn`, the export presets or the icon) publishes the next version, `v0.1.4` after
`v0.1.3`, with `Frontline-windows.zip`, `Frontline-linux.zip` and notes listing the merged pull requests. Label a
pull request `minor` or `major` for a bigger bump, or `skip release` to leave it out. Merges that only touch docs,
the website or the matchmaker don't release (Railway redeploys those itself, watching `web/` and `matchmaker/`).
Actions > Release > Run workflow releases by hand. The next number comes from the newest `vX.Y.Z` tag
(`.github/scripts/next-version.sh`), and the build stamps it into `project.godot` (`application/config/version`);
from source the game reads `0.0.0-dev`.

A release build updates itself (`scripts/autoload/updater.gd`): at start it asks GitHub for the latest release,
downloads the zip for its platform, checks it against the SHA-256 GitHub publishes, renames the running executable
aside and puts the new one in its place, then offers a restart (the old file is deleted on the next launch). Where it
can't (a folder it can't write to), the menu links to the website instead. To try an update from source without
touching Godot itself: `--game-version=0.0.1` pretends to be an old release, `--update-target=PATH` swaps a stand-in
file instead of the running executable, and `--update-api=URL` reads the release from elsewhere (a local JSON file
with a higher `tag_name`). `--menu-update=0.1.2,ready` shows the notice for screenshots (`available`, `downloading`,
`ready` or `failed`).

### Off-screen screenshots

`--screenshot=FILE.png --shot-at=SECONDS` (with `--shots=N --shot-every=S` for a series) saves frames and quits. Frame the shot with `--focus=X,Z --zoom=M --pitch=DEG --cam-yaw=RAD`, and hide the interface with `--nohud`. `--manual=category,key,side` opens a Field Manual page.


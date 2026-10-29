# Developing Frontline

How the code is laid out, and the command-line modes used to test it. See also [CONTRIBUTING](../CONTRIBUTING.md).

## Scaling and the optional native extension

Gameplay remains GDScript. A Rust GDExtension accelerates nearest-enemy candidate
selection using numeric snapshots and contracts degree-two navigation search states.
Individual visibility and combat stay in Godot. Native graph assembly runs on the
main thread; local-grid costing still uses workers.
Install Rust 1.94.0 (`rustup toolchain install 1.94.0 --profile minimal`), then run
`python tools/build_native.py` from the root. Re-import Godot afterward. A checkout
without the generated extension uses GDScript perception and Godot AStar3D routes. Release CI builds
and includes native Windows/Linux libraries. Do not commit generated binaries.

`--local-server` launches a private headless child using the current executable.
Desktop solo menu actions do this automatically; `--host` retains the public host
path. Local sessions bind loopback, require a random session token and protocol
version, and stop when the owner exits. Logs are under `user://local_servers/`.

Run a measured 500-unit case with:

```powershell
python tools/benchmark_scaling.py --godot "C:/path/to/Godot_console.exe" --rendered --local-server --map-size 3072 --duration 90 --output build/my-benchmark
```

Use `--exported` with an exported executable. Use a fresh output folder. The runner
saves frame/tick percentiles, process RSS samples, logs and a screenshot. `--mode`
selects `idle`, `march` or `combat`; `--zoom` changes the camera distance. Each
standalone case obtains a separate UDP port. A headless result is not an FPS result.
Use `--generated --commanders` to retain a full procedural landscape and strategic
AI, and `--units=480 --vehicles=20` for a mixed force. `--width=1920 --height=1080`
sets the render resolution; `--preset=high` is the runner's non-persistent default.
For direct runs use `--scenario=stress --units=500 --map-size=2048 --seed=3`,
`--perf-at=15 --perf-duration=10 --perf-json=ABSOLUTE_PATH`, and a unique `--port`.

Regression scenes: `tests/structure_index_test.tscn`,
`tests/perception_index_test.tscn`, `tests/navigation_budget_test.tscn`, and
`tests/local_server_test.tscn`. The last launches a child and checks commands,
pause/resume, ownership after reconnect, and process cleanup.
`tests/client_loading_test.tscn` covers updates arriving before entity construction;
`tests/map_placement_test.tscn` compares indexed placement with exhaustive overlap checks.
`tests/snapshot_index_test.tscn` verifies bounded scenery refresh and initial-state privacy.
`tests/terrain_cover_test.tscn` compares bounded cover changes with exhaustive recomputation.
`tests/soldier_batch_test.tscn` checks spatial batching and generated mesh LOD; run it rendered as well to verify GPU transform buffers.
`tests/terrain_updates_test.tscn` checks texture/collision seams and mesh boundaries;
`tests/squad_assessment_test.tscn` checks shared assessment expiry and immediate
new-contact handling. `tests/update_sidecars_test.tscn` checks executable/native
library update staging. Run the full local suite with `python tools/check_scaling.py
--godot C:/path/to/Godot_console.exe`.

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
- **Controls:** every key, by category, rebindable (`keys.gd` holds the actions and their defaults; the
  game asks it `Keys.action_for(event, ids)` for presses and `Keys.held(id)` for held keys, never a keycode).

Settings are saved to `user://settings.cfg`, key bindings to `user://keybinds.cfg` (test runs save neither).

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
game_scripts.gd         the game's classes compile on a worker while the title plays: the launch never names them
test/test_run.gd        how a test run ends: exit code 1 on a script error or a failed check
test/test_port.gd       the test port: a test drives the game over a local socket (see "The test port")
test/cam_test.gd, keys_test.gd   the camera and key bindings driven end to end (--cam-test, --keys-test)
test/platform_test.gd   updates and links as each system does them (--platform-test)
                        (exported builds leave these four out, and ui/soldier_sheet.gd: run them from source)
autoload/defs.gd        all data tables (units, weapons, squads, vehicles, buildings, upgrades)
autoload/net.gd         ENet host/join, lobby, teams, start
autoload/online.gd      the matchmaker client: listing, Find Match, STUN + hole punching, optional account
autoload/sfx.gd         procedurally synthesised sounds, the mixer's buses
autoload/music.gd       the soundtrack: synthesised instruments, a sequencer, the scores (menu, battle, stings)
game/world.gd           entity registry, replication (spawn / snapshot / props / fx RPCs), commands, queries
game/entity.gd          base class: props on spawn, packed state in snapshots
game/soldier*.gd        brain + procedural articulated model (body_mesh.gd: the lofted body shapes)
game/soldier_brain.gd   the soldier's priority decisions: reflexes (grenades, shells, drones, melee), clearing houses, the fight
game/bt.gd              a small behaviour tree (selector, sequence, condition, action, cooldown)
game/squad.gd           shared knowledge, rescues, smoke, surrender, auto-engineering
game/squad_brain.gd     the squad's behaviour tree: battle drills, morale, fire discipline, ammo sharing
game/water.gd           rivers, ponds, the sea: laid out as shapes, rasterized into ground kinds and heights
game/water_view.gd      (view) the water surface: swell, surf, reflections, wakes, foam and oil on the water
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
game/nav.gd             two compact NavRaster layers (infantry: vaultable/slow cells; vehicles: smashable cells)
game/hnav.gd            hierarchical A* (clusters, entrances, danger-weighted abstract graphs)
game/terrain.gd         ground types, cover map, craters, speed / hit / concealment modifiers
game/trench_net.gd      the dug trench network (mask, walls, spoil, duckboards)
game/mapgen.gd          procedural battlefield + test scenarios
game/mission_director.gd   a mission on the server: objectives, scripted events, the end, co-op ownership
game/missions.gd        the missions' content: placing each by the map's features, its objectives and events
game/mission_list.gd    the missions' catalogue (names, sides, briefings), apart so the menu needn't compile the game
ui/hud_objectives.gd    a mission's objectives panel, clock and banners
game/towngen.gd         the town's street plan and lots, hamlet, farms, fields, power lines
game/physics_fx.gd      client physics: ground with the trenches cut in, ragdolls, chunks, tossed props
game/ragdoll.gd         the jointed ragdoll
game/decor.gd           street furniture built on each client (merged per chunk, wires, street lights)
game/weapon_models.gd   crew-served machine guns and their tripods (M240B, M2HB, PKM, DShKM)
ui/field_manual.gd      the field manual: catalog of everything with stats and 3D previews
ui/curtain.gd           the title and loading screens
game/bevel_mesh.gd      chamfered boxes (every Res.box thicker than a sheet)
assets/                 splash.png: the boot splash, which is the title's first frame (see "Off-screen screenshots")
game/fx.gd              plays the server's effect events: shots, explosions, who is saying what, debris; drives vfx.gd, gunfx.gd
game/vfx.gd             GPU particle explosions, smoke, flames, char, grass fires, decals, shockwaves (+ their shaders)
game/gunfx.gd           gunfire on the GPU: tracers, muzzle flashes, impacts, sparks, grit, brass (MultiMesh rings flown by their shaders)
game/atmosphere.gd      sky, sun, fog, ground shader, post effects, moods
game/grass.gd           instanced grass, bushes and stones
game/mats.gd            procedural surface uber-shader, foliage, camouflage netting
game/vehicle_models.gd  lofted procedural vehicle models (also used for wrecks and the menu); dispatches to
game/vehicles/          the Arma 3 models by family: vm_nato, vm_csat, vm_indep (AAF), vm_civ (FIA, Syndikat,
                        civilian), vm_heli, vm_plane, vm_boat; the support aircraft in vm_gunship (AC-130U,
                        V-44X Blackfish), vm_attack (A-10C, A-164 Wipeout) and vm_fighter (F/A-181, F-16C)
game/vehicle_roster.gd  the Arma 3 roster (stats, behaviour, tiers, patterns) and the Field Manual's garage
game/director.gd        observer camera and time controls
game/battle_stats.gd    the after-action record: kills, losses, supply and production credited to each commander
ui/stats_panel.gd       the battle statistics / after-action report (Summary, Commanders, Units, Timeline tabs)
game/co_command.gd      co-commanders: each player's presence (view, cursor, selection, what's being lined up),
                        pings, sketches and committed actions, relayed by the host to that side only
ui/hud_coop.gd          co-commanders drawn over the battlefield; ui/hud_coop_roster.gd the Command Net
ui/console.gd           the console (` or ~): typing, history, Tab; ui/console_cmds.gd its commands (why, bench, top,
                        hitches, render, sys, set, report...); ui/perf_graph.gd the frame graph
ui/perf_probe.gd        measures every frame for the overlay and the console (and logs the stutters)
ui/hud.gd, menu.gd      interface; ui/settings_panel.gd, ui/perf_overlay.gd, ui/ui_kit.gd (shared style and the
                        interface themes: read UiKit.ACCENT and friends when drawing, so a new theme shows at once),
ui/ui_frame.gd          the panels' tactical frame (a StyleBox: glass fill, hairline, accent corner brackets, glow),
ui/hud_overlay.gd       everything drawn over the battlefield (labels, speech, symbols, orders, plans, intel)
ui/hud_orbat.gd, hud_layers.gd, hud_sel_info.gd, hud_minimap.gd, hud_top_info.gd, hud_toasts.gd   HUD widgets
ui/map_symbols.gd       NATO symbols and status icons
game/attack_plan.gd     the deliberate attack (plan, support by fire, flank, assault, consolidate)
ui/topo_backdrop.gd     the living topographic map behind the title, the menu and the loading screen (one
                        shader; every copy shares one clock and cursor, so screens hand over without a seam)
ui/topo_survey.gd       the same map's ground worked out on the CPU, to letter its contours and summits
```

Networking is server-authoritative. Clients send command dictionaries (`World.send_cmd`). The host simulates at 30 Hz and
sends compact per-entity snapshots at 15 Hz (length-prefixed records chunked into roughly 1.1 KB unreliable packets), reliable
spawn/despawn/property events, and batched effect events. Clients interpolate. Team-only messages are only sent
to that team. Human command authority is team-based, not recruitment ownership: the host resolves the sender
from the RPC and filters every requested squad, vehicle and individual soldier against that sender's team.
Strategic AI commanders keep their allocation; an explicit human order hands an AI unit into the shared human
force through the existing replicated owner properties. `tests/allied-commands.test.mjs` checks selection,
AI handoff and rejected enemy/observer commands both locally and through an ENet host/client pair.

Models are built in script from parts (boxes, cylinders, lofted hulls) and merged (`Mats.merge_static`) into a mesh
per material, each part's tint carried as vertex colour. A model merged whole puts its parts straight into the
merged meshes (`Mats.Bake`: trees, house and garden walls, floors, rubble, crates, the street furniture, and every
vehicle, whose builders' `_add` only notes a part down for its moving piece) without making them as nodes first; a
part a model goes on to use (a flag that changes colour, a door that swings) stays a node, out of the merge. A mesh
built in script keeps the arrays it was made from (`Mats.keep_arrays`), so merging never reads one back from the
graphics card, which waits on it each time. Merged-away parts let go of their meshes at once (a part deleted with
its mesh had the renderer bring it up to date first: tens of thousands at once froze the first frame of a battle
for ten seconds and more).

## Automated test modes

`--perf-at=N` measures ten wall-clock seconds at normal speed after reaching N simulation
seconds (use `--timescale=5` to fast-forward). It also works without fast-forwarding. The
report includes per-tick median, p95 and maximum, mean system costs, and land-path query
counts, total time, maximum time and full-grid search count. Path time is nested inside
the calling system's time; do not add it to the total. Headless FPS is zero because no
frames are rendered. The overlay's game-logic bar is time per rendered frame, which can
contain several simulation ticks; its system table is time per tick.

Run `godot --headless --path . res://tests/structure_index_test.tscn` for building-index
lifecycle checks and a same-process FOB lookup comparison with 1,000 scenery objects.
See [simulation scaling](SIMULATION_SCALING.md) for the performance investigation and
the proposed route to larger maps and a separate simulation process.

Pass these after `--` on the command line. Every run given switches is a test run: it exits with code 1 if a
script error happened anywhere in it (or one of its own checks failed: `--cam-test`, `--keys-test`,
`--platform-test`) and prints
`TESTRUN failed`, 0 if it ran clean (`scripts/test/test_run.gd`).

Pass the engine switch `--fixed-fps 30` before the `--` to step the game exactly as it plays: every frame is then
one 1/30 s tick, however long it really takes, so a run goes as fast as the computer can and, with `--seed`,
replays the same battle every time. `--timescale=N` is coarser: each tick covers N/30 s.

Scenarios, AI-vs-AI battles and missions run offline: they take no port, so any number can run at once.

```
--aivai --seed=3 --quit-after=900 --stats=60          AI vs AI, prints a state summary + behaviour counters
--seed=N                                              the same map and the same fight every run (scenarios, --aivai,
                                                      missions; a scenario without one gets a random seed)
--listen [--port=N]                                   (scenarios, --aivai, missions) open the port as a host, for a
                                                      client to join
--test-port=N                                         (with --fixed-fps 30) take orders over a local socket: see
                                                      "The test port"; 0 takes any free port
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
                                                      (with --stats, or at --quit-after: a REPORT line per commander
                                                      and side from the after-action record, battle_stats.gd)
--end-at=SECONDS                                      call the battle at that time, for the side ahead, and drop back
                                                      to normal speed so the end sequence plays in real time (report tests)
--stats-tab=summary|commanders|units|timeline|all     open the battle statistics a second before --shot-at (after the
                                                      end: that tab of the after-action report); "all" moves to the
                                                      next tab after each of --shots
--report-at=SECONDS                                   (client) ask the host for the statistics then; a headless client
                                                      prints a CLIENT report line for each it gets
--perf-at=480 [--perf-shot=path.png]                  fast-forward, then measure real FPS and server tick cost
--screenshot=out.png --shot-at=30 --focus=X,Z --zoom=40 [--shots=N --shot-every=0.5]
--mood=golden --perf=3 --preset=ultra                 lighting, overlay level and graphics preset for screenshots
--fx-demo=1.4 --fx-every=3                            set off explosions near the camera (visual test, no damage)
--shot-demo[=rifle|mg|hmg|...] [--shot-demo-every=1.5] [--shot-demo-cannon]
                                                      rounds fired at earth, stone, sandbags, wood, leaves, steel and a man
                                                      in a row across the camera's focus (visual test, no damage); a slow
                                                      --shot-demo-every fires one volley at all of them; -cannon adds a tank
                                                      gun and a rocket launch
--cursor=0.5,0.4 --order-mode=defend --select-all     fake the mouse position / order mode (cover preview shots)
  --place=trench [--place-from=X,Z]                   with --cursor: show the placement ghost (or a dragged line)
--scenario=... --play                                 command the Coalition side of a scenario instead of watching
--focus-fob=0|1                                       keep the camera on that side's first FOB
--focus-town[=dx,dz] / --focus-decor=kind[,n]         camera on the town, or on a piece of street furniture
--focus-vehicle=kind                                  camera on the first vehicle of a kind (--blast-at=f,0,SIZE,T blows it up)
--blast-at=X,Z,SIZE,TIME                              a real explosion at that spot and time (physics tests);
                                                      X,Z of "f,DX" is DX metres beside the camera's focus (or "v:KIND,DX"
                                                      beside the first vehicle of that kind)
--pitch=-14 --cam-yaw=-0.84                           fixed camera pitch (degrees) and heading (model close-ups)
--keys-test                                           the key bindings end to end: names and matching, clashes, rebound
                                                      keys reaching the game, a held key panning the camera, the console
                                                      keeping the keys typed into it, the Controls
                                                      page (rebind, move a key off another action, Undo, a modifier alone,
                                                      search, reset); prints KEYTEST ok / FAIL; needs a window
                                                      (e.g. --host --team=0 --keys-test --offscreen)
--bind=ACTION:KEY[,ACTION:KEY]                        rebind keys for this run only (ids in keys.gd, e.g. --bind=attack_move:K)
--console="why;graph" [--console-at=SECONDS]          open the console and type those lines (; between them) once the
                                                      battle has run that long (5 s unless set); screenshots of it
--hud-panel=settings --settings-tab=controls          the Controls page open (layout shots)
--cam-test                                            drive the camera through its controls (zoom to cursor, grab-pan,
                                                      turn and tilt, a Mac's trackpad, reset, saved views, follow,
                                                      turning minimap) and print CAMTEST ok / FAIL for each; needs a
                                                      window, not --headless
                                                      (e.g. --mission=bridgehead --play --cam-test --offscreen)
--platform-test                                       offline, on any system: finding this system's download in a
                                                      release, installing an update (one executable, and a Mac's app,
                                                      swapped whole), reading frontline:// links as each system hands
                                                      them over; prints PLATFORMTEST ok / FAIL; works --headless
--follow=TEAM[,N]                                     keep the camera on that side's Nth squad (tactics review)
--trace=path.csv                                      log every man twice a second (position, posture, phase) for plotting
--manual=CATEGORY[,ENTRY[,SIDE]]                      open the field manual on a page (in a battle)
--hud-panel=settings|help|menu|log|over [--settings-tab=T]   open one of the battle's panels (over: the end of
                                                      the battle, won; layout checks; add
                                                      --set=ui_scale:3 for the largest scale the window allows)
--pan=VX,VZ / --set=key:value,...                     drift the camera (shimmer tests) / override single settings
                                                      (--set=ui_theme:night for a theme: brass, night, thermal, arctic, dusk)
--scenario=guns                                       every machine-gun emplacement and trench bay, crewed, with targets
--scenario=works --static                             every defensive work both sides can build, finished, in two rows (model checks;
                                                      frame them with --focus/--zoom/--pitch, see the layout in mapgen.gd)
--scenario=cache                                      an ammo cache filling an empty-handed squad, then blown up (cache_draw,
                                                      cache_cook_off); a Rebel cell half under a camouflage net, half in the open
FL_DEBUG_WORKS=1 (env)                                with --scenario=cache: who's under the net and seen, who's filled up
--scenario=roster                                     every vehicle both sides can field, facing off across the map
--scenario=sling                                      a Mohawk carries a Humvee and a Taru a BTR on their slings
--scenario=naval                                      boats on the sea: an RHIB lands a squad under a patrol ship's guns, Rebel boats come out to fight
FL_DEBUG_BOAT=1 (env)                                 every 2 s, each boat under way: where, heading, speed, how far down its route; and each grounding
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
--curtain                                             show the title / loading screens in an automated run
--intro-at=SECONDS                                    (with --curtain) hold the title at that moment of its animation
--menu-clock=SECONDS                                  start the menu's map that far into its drift and colours
--menu-cursor=X,Y                                     hold the cursor there, the map leaning after it (fractions of the screen)
--menu-op=0|1|-1                                      open the New Operation panel on that side
--menu-missions[=KEY]                                 open the Missions panel (on that mission)
--startup-trace                                       print the first frames' timings
--test-fire[=ground]                                  every armed man, gunner and vehicle fires ahead (muzzle tests);
                                                      =ground puts the men's rounds into the ground 25 m out (impacts);
                                                      --test-fire-every=0.3 fires that often (default 0.09 s)
--dump-structs                                        list every built structure when --quit-after fires
FL_DEBUG_TOWNS=1 (env)                                print each town and village: name, dump and the ground that takes it
FL_DEBUG_HPA=1 (env)                                  benchmark hierarchical vs flat paths at start-up
FL_DEBUG_DECOR=1 (env)                                print the street-furniture chunk and mesh counts
FL_DEBUG_WILDLIFE=1 (env)                             every 5 s: the wildlife's cost, how many of each are drawn, what took
                                                      fright at what, and where one of each is (the first time, the water too)
FL_WILDLIFE_FOLLOW=KIND (env)                         the camera keeps on one animal (birds, ducks, soarer, bat, rat, hare, fish,
                                                      dolphins, dead), for a close look with --zoom / --pitch (windowed only)
--menu-shot=menu.png --shot-at=6                      screenshot of the main menu (with --curtain --intro-at=0 at
                                                      1920x1080 it is the boot splash: save it as assets/splash.png
                                                      whenever the title or the map changes)
--sound-dump=DIR                                      every synthesised sound and music sample as a WAV in DIR, then quit
                                                      (works --headless)
--insignia-dump=web                                   every insignia as web/public/insignia/<id>.svg, and the catalog the
                                                      website reads as web/src/lib/insignia.json, then quit (--headless)
--insignia-sheet=PATH [--px=96] [--only=r01,u07]      the whole collection of insignia (or those) on one image, then quit
FL_DEBUG_MUSIC=1 (env)                                print the music's cue, battle heat and layer levels every 5 s
```

To hear (or measure) the mix as a player does, record it: Godot's movie writer saves the game's audio with
the video, e.g. `godot --path . --write-movie out.avi --resolution 320x180 --quit-after 3600 -- --mission=bridgehead`
(an MJPEG AVI with PCM sound; it runs at a fixed 60 fps, and the music keeps time with it).

Example:
`godot --headless --fixed-fps 30 --path . -- --aivai --seed=3 --quit-after=600 --stats=120`

### The test port

`--test-port=N` lets a test drive the game from outside: it listens on 127.0.0.1 (only, and only when asked;
exported builds leave it out), one JSON object per line each way. Game time moves only when the test steps it,
so the game must run with `--fixed-fps 30`; between commands it holds still. `--test-port=0` takes any free port
and prints `TESTPORT listening 127.0.0.1:PORT`. The game quits when the test hangs up. A test-port game has no
main menu (nothing a test drives needs it, and leaving it out saves a second or so of every start).

The tests live in `tests/` (Node, no dependencies): `tests/lib/game.mjs` starts a headless game, connects and
wraps the commands, and each `*.test.mjs` is a `node:test` file. Run them with `npm test` in `tests/`, with
`GODOT` set to your Godot executable (`FL_TEST_VERBOSE=1` echoes the games' output). A test looks like this:

```js
const game = await Game.start();
await game.load({ scenario: "attack", seed: 3, static: true });
const { squads } = await game.query("squads", { team: 0 });
await game.order(0, "assault", { squads: squads.map((s) => s.id), pos: v3(-2, -42) });
await game.step(60);
assert.ok((await game.stats()).counters.plan_assault >= 1);
assert.equal(await game.close(), 0);
```

A check that fails throws before the `close()` at the end, and a game left running would keep `node --test` waiting
for ever (in CI, until the job times out). So `game.mjs` adds an `after` hook to each test file that closes whatever
games its tests left running. A test that starts a game of its own can close it sooner, failed or not, with
`t.after(() => game.close())` (boats.test.mjs).

What a test pays for before it plays a second: starting a game takes several seconds (the engine compiles every
script first), and every `load` builds a battle from nothing, on the full-size map even for a scenario: a few
seconds, most of it the hierarchical nav (`HNav.build_all`), and 10-20 s for a whole battle or mission map. So a
test file starts one game and loads it afresh for each of its tests: `Game.start()` in `before`, `close()` (and its
exit code) in `after`, as [tests/attack.test.mjs](../tests/attack.test.mjs) does. A seed replays the same in any
game, so the tests still don't depend on each other. A test that needs games of its own (one that ends in a
script error, two that must agree) gets them from `Game.startMany(n)`, which starts them together so their
start-ups overlap. `node --test` runs the files side by side, and tests inside a `describe(..., { concurrency: true })`
run side by side too (determinism.test.mjs: the full-map battle, the longest test, runs alongside everything else).

| command | fields | answers |
| --- | --- | --- |
| `hello` | | `version`, `net` (NET_VERSION), `tps`, `headless` |
| `load` | one of `scenario`, `mission`, `battle: true` (AI vs AI); `seed`, `play`, `autoplay`, `static`, `verbose` | `t` (0), `seed`, and how many `soldiers`, `vehicles`, `structures`, `squads`; a fresh battle each time |
| `step` | `seconds`, or `ticks` | `t`, `ticks` run, `winner` (-1 while it goes on) |
| `order` | `team` (0 or 1: that side's AI, which owns a scenario's squads too) or `peer` (1: you, loaded with `play`); `t` and the order's fields as `World.execute_cmd` takes them, positions as `{"v3": [x, z]}` | `squads`, `vehicles`: how many of those listed the order reached |
| `query` | `what`: `world`, `squads`, `soldiers`, `vehicles`, `structures`; `team`, `kind`, `ids` | the list (positions as `[x, z]`; a vehicle's `yaw`, `speed` along its heading and `vel` over the ground too); structures leave out trees and floors unless asked for by `kind` |
| `stats` | | `counters` (every `world.stat`), `report` (the after-action summary) |
| `hash` | | `hash`: a fingerprint of the whole simulation; two runs from one seed agree on it tick for tick |
| `errors` | | `count` and the `recent` script errors |
| `console` | `line` | `out`: what typing that line into the console printed, a line a string (`game.console("why")`) |
| `quit` | | the game quits with its exit code |

Every reply has `ok` (with `error` when false) and `errors`, the script errors counted so far.

### Scenario expectations

Every scenario has an expectation: what it's there to show, which must still happen when it runs with its seed, so a
behaviour that quietly stops happening fails the tests. They're tables in `tests/scenarios-*.test.mjs` (infantry,
armour, air and sea, the ground and what's built on it); each file plays its rows one after another in one game, and
`tests/lib/expect.mjs` runs them. A row names the scenario, a seed, how long to run it and what must be true by then:

```js
{
  scenario: "breach",
  seed: 1,
  secs: 40,
  does: "two squads and a gun team breach the house and clear the fighter cell out of it",
  check: async (f) => {
    f.atLeast("room_entry", 1, "they went in room by room");
    const cell = await f.soldiers({ team: 1 });
    assert.equal(cell.filter(fighting).length, 0, "nobody in the house is still fighting");
  },
},
```

`f` holds the behaviour counters at the end (`f.n(key)`, `f.atLeast(key, n, why)`, `f.never(key, why)`, `f.sum(/re/)`)
and asks the test port's queries (`f.soldiers`, `f.vehicles`, `f.squads`, `f.structures`, with `{ team, kind, ids }`).
For what leaves no counter behind, `begin(f)` looks at the field before time moves and `during(f, t)` every `every`
seconds on the way. A script error during a row fails it; `load` adds load fields (`{ static: true }`).

To add a scenario, or change what one does: run it with a few seeds (`--scenario=X --seed=N --stats=20`, or
`game.stats()` and queries from a scratch script) and look at what happens. Then write down what it's for, the behaviour
that must happen with room to spare rather than that run's numbers, on a seed where it does. Something that only
happens with some seeds is fine to test on one of those. Something broken gets its row (or a subtest, `t.test(...)`)
marked `todo: "why"`: it still runs, and starts passing once it's fixed, but doesn't fail the suite meanwhile.

`tests/missions.test.mjs` plays each mission to its end on its autopilot and expects it accomplished (`winner` is the
mission's side). Each is a few minutes of battle on the full map, so they only run with `FL_TEST_LONG=1` (CI leaves them
out): `cd tests && FL_TEST_LONG=1 node --test missions.test.mjs`. They play side by side, `FL_TEST_JOBS` at a time
(default half the cores).

### Host / client

Two processes on one machine. Start the host, then the client a few seconds later (the host spends several seconds laying out the 1 km map):

```
godot --headless --path . -- --host --team=0 --players=2 --ai-allies --stats=100 --quit-after=200 --port=7935
godot --headless --path . -- --join=127.0.0.1 --team=1 --quit-after=200 --port=7935
```

The client prints a `CLIENT entities=...` summary when it quits. Check both outputs for `SCRIPT ERROR`. A client's
`--quit-after` counts from when the host's world has reached it and been built (`World.loaded`): the host answers
only once it has laid out the map and, with a window, drawn its first frame, which takes a minute or more off-screen.
`waited=` in the summary is how long the client took to get there (-1: nothing came, and it gave up 5 minutes past
`--quit-after`). With `FL_DEBUG_NET=1` the host prints what it sent a joiner (`JOIN sent peer ... entities in N kB`)
and the client when its world was laid out, built and covered (`JOIN loaded ...`).

The host's lobby takes `--battle-name=NAME`, `--coop` (everyone on `--team`'s side), `--max-players=N` and
`--password=PW`; a joiner gives `--password=PW`, and `--ready` / `--say=TEXT` press Ready and chat once it's in the
lobby. With `--players=N` the host shows its lobby while it waits, so a windowed host can be screenshotted there. On
a busy machine a host can take ten seconds or more to start listening: start the clients once its port is bound
(`netstat -ano -p UDP`), or ENet gives up connecting first. `FL_DEBUG_NET=1` prints each side of the lobby handshake
(connecting, registering, a password asked for, turned away, the battle starting).

Rejoining: `--drop-at=S` makes a client leave the battle S seconds in (as Leave Battle does) and press Rejoin
`--rejoin-after` seconds later (default 5). Put the client alone on the other side to see the AI stand in and step
down. The host's `--stats` shows the force's owner change (`own=`) and the counters `rejoined`, `rejoin_returned`
(squads and vehicles handed back) and `rejoin_ai_stood_down`; the client's summary ends `team=... mine=N`, the men
and vehicles it commands. `--no-drop-in` closes the battle to newcomers (a returning player still gets in):

```
godot --headless --path . -- --host --team=0 --players=2 --verbose --stats=15 --quit-after=110 --port=7936
godot --headless --path . -- --join=127.0.0.1 --team=1 --drop-at=20 --rejoin-after=5 --quit-after=30 --port=7936
```

A crash and restart: test runs leave the player's `user://rejoin.cfg` alone, so give the client its own with
`--rejoin-file=PATH`, kill it mid-battle, then start another with `--rejoin --rejoin-file=PATH`. The host still holds
the dead link (ENet takes 45-90 s to notice) and lets it go when the new one registers.

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

The matchmaker (`matchmaker/`, see its README) is a small Node service with its own tests, lint (oxlint) and
formatting (Prettier); `.github/workflows/matchmaker.yml` runs them whenever it changes:

```
cd matchmaker && npm test
cd matchmaker && npm install && npm run lint && npm run format:check
```

Without `npm install` the tests run as the service does, with no dependencies; the database's migrations
(`supabase/migrations/`) are then skipped, and after it they run on PGlite too. A change to the database is a new
migration (`supabase migration new <name>`, from `matchmaker/`); the README's "The database" has the rules, and how
the Database workflow applies new ones to the live project (as they merge, and before every release).

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
keeps that sign-in out of your real one, and `--menu-panel=browse|host|account|record|settings|insignia` opens those panels
for screenshots (`--host-mode=coop|versus|mission` for the host setup, `--browse-pick=TEXT` to choose a battle in the
browser, `--open-battle` to open the newest battle on the service record). `--host --list` also beacons on the LAN
(UDP 7787), so a second copy's server browser lists it even with a dead `--matchmaker`. Test runs keep no service
record and earn no rank; `--record-battles` turns both on (with `--pending=PATH` for the battles waiting to go up, out of your real ones):

```
godot --headless --path . -- --scenario=attack --play --end-at=40 --quit-after=55 --record-battles --no-stun \
  --matchmaker=http://127.0.0.1:8787 --login=me@test.dev:password1 --signup=Me --account=/tmp/a.cfg --pending=/tmp/p.json
```
Without `--matchmaker` the game uses the live service on Railway.

Ranks: a battle a signed-in player fights in counts once it's under way (so not `--scenario` setups, nor watching,
nor a test run without `--record-battles`). With `--quit-on-win` the game waits for the matchmaker's answer and prints
`BATTLE {"gained": ...} rank=... xp=...`; `FL_DEBUG_ONLINE=1` also prints the battle clock starting and stopping. XP is
timed on the matchmaker's clock, so a battle has to run two real minutes to earn any (a `--timescale` run counts the
real time, not the game's):

```
godot --headless --path . -- --mission=bridgehead --play --autoplay --quit-on-win --record-battles --port=7943 --no-stun \
  --matchmaker=http://127.0.0.1:8787 --account=user://test_account.cfg --login=a@example.test:password1 --signup=Tester
```

After changing the insignia (`scripts/ui/insignia.gd` for the catalog, `insignia_art.gd` for the drawing), run
`--insignia-dump=web` and commit what it writes: the website and the matchmaker's tests read it.

### Join links

A `frontline://` link can be passed after `--`, as a browser would: `godot --path . -- frontline://join/LOBBY_ID`
(or `frontline://find-match`). Test runs (anything with a `--switch`) don't listen for links handed on by a second
copy unless given `--links`, so to test the hand-off: start a listed host, then an idle game with `--links`, then a
third copy with only the link. The third prints `LINKS handed ...` (with `FL_DEBUG_ONLINE=1`) and quits; the idle
one joins. Only exported builds register the scheme with the OS (`Links._register`), so `--platform-test` checks
how a game tells whether the links still open it (`Links.windows_claimed`, `linux_claimed`). `FL_LINKS_PORT`
moves the socket off the one a game you're playing listens on: `tests/links.test.mjs` passes links between copies
on a port of its own.

Players sign in with GitHub on the website, which signs the game in. Email and password are for testing: from
source the game shows its own email and password form, and so does the website's dev server. `--web-sign-in`
makes a run from source go through the website (`--web-sign-in=URL` for a local one, its `VITE_MATCHMAKER_URL`
the same local matchmaker as the game's `--matchmaker`), and `--no-browser` prints the address instead of opening
it. A local matchmaker with `AUTH_BACKEND=memory` stands in for GitHub: its "Sign in with GitHub" comes straight
back, signed in as `GitHub Player`, so the whole round trip runs offline. The site then opens
`frontline://sign-in/STATE/TOKEN`; without an exported build to catch it, copy the link from the dialog's **Open
Frontline** button and pass it to a second copy as above (the waiting game needs `--links`). A link with any
state but the one the game made is refused.

### Website

`web/` is the website (React, Vite, Tailwind, shadcn/ui, React Router; see its README for its pages):
`npm install && npm run dev`, with `VITE_MATCHMAKER_URL` pointing at a local matchmaker if you like (with
`AUTH_BACKEND=memory` you can make throwaway accounts on the dev server to try the account pages). `npm run storybook`
shows every component and page on its own, in each of its states (loading, offline, nobody hosting, signed in...),
without the live matchmaker. `.github/workflows/web.yml` lints it, checks formatting and types, runs the unit tests, builds it, and
renders every story in headless Chromium as a test (its play function and an accessibility check).

### Builds, releases and updates

Merging a change never releases it. Releasing is one press and one merge: **Actions > Release > Run workflow** on
`main`, choosing `patch`, `minor` or `major` (and, if you like, a name; otherwise the release is named after its
headline change), then merge the pull request it opens. It ships everything merged since the last release: the version
is the newest `vX.Y.Z` tag plus that step (`.github/scripts/next-version.sh`), and the build stamps it into
`project.godot` (`application/config/version`); from source the game reads `0.0.0-dev`.

`export_presets.cfg` has a Windows and a Linux preset (one executable each, the game packed inside), a macOS one and a
Web one (see [The browser build](#the-browser-build)). The Mac build is `Frontline.app`, a folder: the program for
Apple silicon and Intel in one (`Contents/MacOS/Frontline`), the game beside it (`Contents/Resources/Frontline.pck`)
and an ad-hoc signature over both, which Godot writes from Linux and which is enough for Apple silicon to run it. It
isn't notarized (that needs a paid Apple developer account; Godot can sign and notarize from Linux through
`rcodesign`, given the certificate and an App Store Connect key), so macOS stops it the first time and the player
allows it under System Settings > Privacy & Security. Its Info.plist claims the `frontline://` scheme and explains
the local-network prompt (the LAN beacons), both through `application/additional_plist_content`. The run exports
all four from `main` as it stands and zips them, then makes the installers most players download instead (`installer/`):
`Frontline-windows-setup.exe`, a setup wizard NSIS builds on the Linux runner (`installer/windows.nsi`), which
installs for the player alone under `%LOCALAPPDATA%\Programs\Frontline` with no administrator rights, adds Start menu
and desktop shortcuts, the `frontline://` links and an entry in Settings > Apps that uninstalls it; and
`Frontline-macos.dmg`, a disk image with the app and a link to Applications to drag it onto, which a job on a macOS
runner makes with `hdiutil` (`installer/macos-dmg.sh`) and then mounts to check the app's signature. Both put the
game where it can update itself. Then
`.github/scripts/bake-release.sh` makes the release's own commit on a branch, `release/vX.Y.Z`: it files every entry
waiting in `changelog/unreleased/` under `changelog/vX.Y.Z/` (`changelog.py release`), regenerates `CHANGELOG.md` and
`web/src/changelog.json`, and writes `release.json` into `web/src/` and `matchmaker/` (`release_json.py`).
`.github/scripts/release.py` uploads the downloads as a draft release at that commit (`Frontline-windows.zip`,
`Frontline-macos.zip`, `Frontline-linux.zip`, `Frontline-web.zip`, the two installers, the changelog as its notes),
which nobody else can
see, and opens a pull request from the branch that says what the release is: its version, what it was built from, its
downloads and checksums, and the notes as they'll be published. Merge it: that runs Publish release (`.github/workflows/publish.yml`), which
checks the draft's downloads against the merged `release.json`, tags the release's commit and publishes it, while
Railway redeploys the website and the matchmaker, which is where the game hears about updates. Running Release again
before merging rebuilds the release and updates its pull request (or replaces it, if the version changed). If Publish
release fails, the release has merged but isn't out: re-run it, or run it by hand on `main`. Opening the pull request
needs Settings > Actions > General > "Allow GitHub Actions to create and approve pull requests"; without it, the run
ends with a link to open it yourself. `python .github/scripts/changelog.py pending` lists what the next release would
ship. Pull requests that change the export setup test-export without releasing.

A release build updates itself (`scripts/autoload/updater.gd`): at start it asks the matchmaker (`GET /release`,
falling back to GitHub's API) for the latest release,
downloads the zip for its platform (`release.json`'s `assets`; the installers are under `installers`, which only the
website reads), checks it against the SHA-256 GitHub publishes, renames the running executable
aside and puts the new one in its place, then offers a restart (the old file is deleted on the next launch). On a Mac
it does the same with the whole app: the new `Frontline.app` is unpacked beside the old one, the folders are
swapped, and the restart goes through `open -n`. Where it can't (a folder it can't write to, or a Mac app run
straight from Downloads, which macOS runs from a read-only copy), the menu links to the website instead.
`--platform-test` checks the installing, both ways, on any system. To try an update from source without touching
Godot itself: `--game-version=0.0.1` pretends to be an old release, `--update-target=PATH` swaps a stand-in
file instead of the running executable, and `--update-api=URL` reads the release from elsewhere (a local JSON file
with a higher `tag_name`). `--menu-update=0.1.2,ready` shows the notice for screenshots (`available`, `downloading`,
`ready` or `failed`).

### The browser build

The Web preset exports the game to WebAssembly: `index.html` with the engine (`index.wasm`, about 40 MB) and the
game (`index.pck`) beside it. It's the build without threads, so any static host serves it as it is, with no
cross-origin isolation headers. To try it, export it and serve the folder:

```
godot --headless --path . --export-release "Web" build/web/index.html
python -m http.server 8000 --directory build/web
```

then open `http://localhost:8000`. Exporting needs Godot's `web_nothreads_release.zip` template. Every release
attaches the export as `Frontline-web.zip`; the website on Railway is where it's to be played.

What's different in a browser (`OS.has_feature("web")`):

- **Alone only.** A browser can't open a port or send the UDP that ENet and the hole punching need, so a solo battle
  runs on an `OfflineMultiplayerPeer` (still as its own host), and the menu's multiplayer entries become a link to the
  desktop downloads. Accounts and the service record work: they're plain HTTPS to the matchmaker, which allows any
  origin.
- **No updater and no `frontline://` links** (the page always serves the latest release).
- **No worker threads:** the music renders a sample a frame instead of on a thread, and map generation blocks the
  page while it runs (about 20 s, as long as on the desktop).
- **Settings** a browser can't use (the screen-space effects, the upscalers, window size, VSync) are hidden.
- **Water quality starts at Medium** (High's extras cost little, but the browser is often a weaker machine); the
  water works the sun's glitter out per pixel itself, since the lighting there is per vertex.

It draws with the Compatibility renderer (OpenGL ES 3 / WebGL 2) instead of Forward+. Run the desktop build with
`--rendering-method gl_compatibility` (before the `--`) to see what the browser will. Code that draws has to keep
to what that renderer can do:

- **Per-object shader values** (`instance uniform`) share a buffer with room for 4096 there, far fewer than a town
  needs. Set them with `Mats.set_inst(node, &"param", value)`, never `set_instance_shader_parameter`, and compile a
  shader that declares them from `Mats.code(source)`: under Compatibility its instance uniforms become material
  uniforms, and a node given values gets a shared copy of its material carrying them. A later change to such a
  material goes through `Mats.set_shared`, so the copies follow it.
- **Depth reads:** OpenGL's clip-space depth runs -1..1, Vulkan's 0..1. Shaders that read `hint_depth_texture`
  define `NDC_Z` with `#if CURRENT_RENDERER == RENDERER_COMPATIBILITY` and rebuild positions with it.
- **No multiply blending:** Compatibility tonemaps each draw as it goes, so a `blend_mul` pass darkens everything
  (the fog of war lays black over instead there).
- **No particle trails, fog volumes or view-depth particle sorting** (the last reads every particle back from the
  GPU each frame, which stalls WebGL). `Vfx.gl` says which renderer is drawing.
- An unset `hint_default_black` texture reads alpha 1 there and 0 under Forward+: use `hint_default_transparent`
  where the alpha matters.
- **A MultiMesh's vertex colours read black** there unless it has instance colours (`use_colors`): `COLOR` comes
  out multiplied by an instance colour that isn't there. Per-vertex data a shader needs goes in `UV2` instead
  (`wildlife.gd`); `INSTANCE_CUSTOM` arrives fine.

**Shader compiling is what the browser build is shaped around.** Browsers on Windows run WebGL through ANGLE on
Direct3D 11, whose compiler is slow on Godot's Compatibility shaders, and a browser compiles each one the first time
it's drawn, inside that frame. Untreated, a first battle froze the page for five minutes and Chrome killed it. So,
for the browser:

- **Lighting is per vertex** (`shading/overrides/force_vertex_shading.web` in `project.godot`): per-pixel lighting
  is what Direct3D's compiler chokes on (0.2 to 4 s a program instead of a tenth of that). From above, the battle
  looks nearly the same; the Field Manual's close-up gets extra fill and a painted floor sheen to make up for it.
- **Particles are CPU particles** (`Vfx.part`): every GPU particle effect brings a simulation shader of its own,
  and those took up to 30 s each to compile. Effects are built as GPU particles as everywhere else and converted as
  they go into the scene; code that touches an emitter afterwards goes through `Vfx.set_emitting`, `set_ratio`,
  `restart_particles` and `pm_set` / `pm_get`, which work on either kind.
- **No light from effects** (explosion and muzzle flashes, fires): the first time a light falls on something, its
  shaders compile again with lights on.
- **The battle is built a stage at a time** (`World.build`, `MapGen.generate`): between stages `World._breathe`
  tells the loading screen and waits a frame, with the half-built world neither ticking nor drawn. Built in one go
  it held the page for about 30 s, long enough for Chrome to call it unresponsive; now no stage takes more than
  about 7 s. The battlefield then stays out of sight for a frame (`main.gd` `_reveal_next_frame`), so compiling its
  shaders (about 17 s the first time) is a wait of its own. The loading screen's field note says to choose Wait if
  the browser asks anyway. (A desktop host with a window builds a stage at a time too, its multiplayer polling
  paused meanwhile so a player who has loaded is sent the battlefield once it's all there: the loading bar moves,
  and Windows doesn't call the window Not Responding. Headless, and for a desktop `--scenario`, `_breathe` returns
  at once, so the build is one piece in one frame, as tests and dedicated hosts have it.)

With nothing cached, a first battle now starts after about a minute, then plays without long hitches; the browser
keeps the compiled shaders, so later battles wait only for the map. To see where the time goes, run the desktop
build with `--rendering-method gl_compatibility --rendering-driver opengl3_angle` (Godot's own ANGLE on Direct3D 11),
or time `WebGL2RenderingContext`'s `linkProgram` / `getProgramParameter` in the page. A battle holds about 1.5 GB of
the 2 GB the web build can have; the hierarchical pathfinding is the biggest single part (about 370 MB).

### Error reports

A release build reports its errors to the matchmaker (`scripts/autoload/errors.gd`, `matchmaker/src/errors.js`): a
custom `Logger` catches every error the engine reports, with the GDScript call stack that led to it, and sends each
distinct one (with a count) a few seconds later. A crash can't report itself, so the next launch reads the last
run's log (`user://logs/`, rotated at every start) and sends the crash from there: the signal, the GDScript calls it
died in, and the lines before it. The call stacks in a release build come from
`debug/settings/gdscript/always_track_call_stacks` in `project.godot` (a few nanoseconds a call). A release build
reports engine errors and `push_error()`; GDScript's own runtime errors (a null dereferenced, an index out of range)
are silent there, the call just returning null, so they only show in development runs and CI.

Only exported builds report (not `0.0.0-dev` ones). To try it from source, against a local matchmaker:

```
cd matchmaker && ERRORS_TOKEN=local PORT=8787 npm start
godot --headless --path . -- --scenario=attack --quit-after=20 --report-errors --matchmaker=http://127.0.0.1:8787 --test-error=1
godot --headless --path . -- --scenario=attack --report-errors --test-crash=1      # crashes; the next launch reports it
curl -H "Authorization: Bearer local" http://127.0.0.1:8787/errors
```

`--test-error=S` causes an engine error and a `push_error` S seconds after start; `--test-crash=S` crashes the game.
The matchmaker writes each new error to its log in full, then a line each time one passes another power of ten;
`GET /errors` (with `ERRORS_TOKEN` as the bearer token) is the tally since it started, most common first. On the live
service that's `railway logs --service matchmaker | grep -E "^(error|script|shader|crash) "`.

### Visibility regression checks

`tests/visibility.test.mjs` checks every lighting mood across close and map-wide camera distances,
including a bound on atmospheric optical depth, and checks that transparent world symbols and solid map
symbols have distinct atlas cells. Run `godot --path . scripts/test/visibility_test.tscn` with a renderer
to also sample their actual fill opacity. The test is headless-compatible; its two pixel checks run only
with a display. Fog-of-war sight and server enemy filtering are deliberately unchanged.

### Off-screen screenshots

`--screenshot=FILE.png --shot-at=SECONDS` (with `--shots=N --shot-every=S` for a series) saves frames and quits. Frame the shot with `--focus=X,Z --zoom=M --pitch=DEG --cam-yaw=RAD`, and hide the interface with `--nohud`. `--manual=category,key,side` opens a Field Manual page.

The menu and the title are screenshot with `--menu-shot=FILE.png`. The boot splash is the title's first frame,
so remake it whenever the title or the map shader changes, so that the splash hands over to the title without a
jump: run at 1920x1080 with `--curtain --intro-at=0 --menu-shot=assets/splash.png` (a held frame has no grain,
which keeps the PNG small).



## Recording and replay tests

Use `--record-replay=FOLDER` to save a test battle, and `--replay=FOLDER` to watch it. `--replay=URL` opens the recording API in the same observer. `--replay-test` checks forward and backward seeks against recorded state; `tests/replay.test.mjs` includes it in the game suite. See [REPLAYS.md](REPLAYS.md).

## Additional scaling diagnostics

`tests/structure_view_test.tscn` checks deferred scenery construction, camera-cell
changes, removal, and construction finishing outside the visible region.
The scaling runner includes this scene alongside the navigation and AI regressions.
Benchmark JSON includes loading-stage timings, route-cache hits and path queue
waiting time. `--require-target` makes the benchmark fail when any measured rendered
frame exceeds 16.67 ms or any simulation tick exceeds 33.33 ms; ordinary runs retain
these budget results without treating an unfinished optimization as a harness error.

## Generated elevation

`Landform` produces immutable 4 m geology samples using seeded, domain-warped ridged simplex noise,
thermal material transfer and seeded hydraulic droplet erosion. Rain cuts gullies and deposits sediment downhill. Planned roads, rivers, towns and bases
reserve level corridors before the final erosion pass. This keeps existing bridge, supply and town layouts
connected. The river network is planned for gameplay before erosion, rather than derived from the erosion simulation.

Ground materials blend bundled CC0 aerial rock, fractured stone and moss photographs with triplanar normal
maps and connected snowfields. Cliff slabs use a larger scale than loose scree; steep faces shed snow.
Photographic samples are converted from sRGB in Compatibility before computing the shared linear mineral masks.
`Landform.bake_surface()` samples eight horizon bearings out to 128 m
on an 8 m grid, baking sky visibility and broad concavity. A third channel traces toward the sun out to
512 m, extending ridge shadows beyond the live shadow cascades. The bake rebuilds when the lighting
mood changes and never changes geology or simulation data. Moving-object shadows, weather and crater
normals remain live. Keep mipmaps enabled in their import settings. Credits and hashes
are in `assets/terrain/`. Outside the playable boundary a 16 m, non-interactive mountain backdrop blends
into the map edge; it is scenery only and does not enter navigation, replication or combat.

`TerrainMap.dh` stores total height on the existing 50 cm deformation grid. The rendering texture carries
surface height in R and immutable geology in G; crater shading subtracts the latter. Use `world.ground_y`
for a soldier or touchdown (including trench floors and bridge decks), `landform.height` for foundations,
and `ray_ground` for terrain occlusion. Do not treat world Y as altitude above ground.

Navigation blocks slopes over 0.85 rise/run for infantry and 0.48 for vehicles. Remaining slopes increase
travel costs and reduce speed. Building and landing footprints sample their corners and edges for levelness.
Enemy visibility uses sampled terrain rays; the visual fog uses a cached pixel-resolution horizon sweep.

The host transmits elevation samples with the static map and recordings save them. Protocol 12 prevents
older builds from joining elevated maps. Empty samples preserve flat scenarios and older recordings.
`tests/landform.test.mjs` checks deterministic generation, malformed samples, sight, navigation, craters,
infantry grounding, truck slope limits, helicopter crossings/landings and serialization. Replay tests exercise
both flat scenarios and generated mountains. Run the full scenario suite and the long mission suite too.

### Alpine rendering options

`alpine_haze` retains distant atmospheric depth on elevated maps (High/Ultra defaults),
fading the extra haze as the camera tilts down to preserve command-view readability;
Low/Medium keep the thinner command-camera haze. `terrain_reflections` is opt-in on all
presets. A single UPDATE_ONCE ReflectionProbe captures only terrain on layer 3 (mask 4),
with shadows disabled, after surface baking. A lighting mood change rebuilds the capture;
turning the setting off releases it. Water uses environment specular instead of its synthetic
sky reflection while enabled. It approximates distant mountains, not nearby shoreline parallax
or moving boats. Ground remains visible on layer 1 as well. No capture includes hidden troops.

Campaigns retain their previous geology recipe and woodland density to preserve authored routes and cover.
Standard battles add bedrock fractures and denser woods.

Terrain beyond 170 m uses a 4 m grid matching the immutable geology samples; nearby
terrain retains the fine deformation grid. Woodland bark and foliage can join the existing
64 m scenery batches, with destruction and fire restoring only the affected tree.

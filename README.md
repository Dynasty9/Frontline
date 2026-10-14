# Frontline

A 3D squad-based RTS for **Godot 4.7** (GDScript), with co-op and PvP multiplayer.
Soldiers think for themselves: they evaluate the real collision shapes around them for
cover, keep their heads down under fire, drag the wounded to safety, and surrender when cut off.
All art (soldiers, vehicles, buildings) and all sound are generated in code, so there are no asset files.

## Running

1. Install Godot 4.7 (standard build, not .NET).
2. Open `project.godot` in the editor and press **F5**, or run from a terminal:
   `godot --path frontline`
3. In the menu, pick **Play vs AI**, **Watch AI Battle**, **Host Multiplayer** or **Join Game**.

### Watching the AI (observer mode)
**Watch AI Battle** puts you behind the camera while two AI commanders fight. A director camera cuts
between the hottest fighting and follows individual soldiers (the caption at the bottom says who and what
they're doing). The observer bar at the top has pause, speed (0.25x to 4x), director on/off and
"View": both sides, or one side's fog of war. Move the camera yourself and the director lets go; press **C** to hand it back.

### Settings and performance
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
- **Display:** window mode (windowed / borderless / exclusive fullscreen), window size, VSync, frame-rate cap,
  field of view, performance overlay.
- **Interface:** interface scale, unit activity labels, speech bubbles, cover preview, edge scrolling,
  camera speed, camera shake.

Settings are saved to `user://settings.cfg`.

**F3** cycles the performance overlay: off, FPS, compact (CPU / GPU / draw calls) and a full breakdown:
- a frame bar split into game logic, view scripts, render CPU and engine/idle time, with GPU time on a second bar
  and a CPU-bound / GPU-bound verdict
- min / max / 1% low FPS and a 240-frame frame-time graph
- the host simulation cost per tick by system (soldiers, structures, rules and fog, AI commanders...)
- this PC's per-frame script cost by system (soldier animation, effects, HUD, grass...)
- draw calls, objects, triangles, video memory, node count, entity counts, active effects, network traffic.

### Multiplayer
- The host is the authoritative server and runs the entire simulation, including the AI.
- Everyone else joins with the host's IP on UDP port **7777**. Forward that port or use a LAN/VPN
  (Tailscale, ZeroTier, Hamachi).
- **Co-op:** everyone picks the same side, and the AI takes the empty side.
  **PvP:** pick opposite sides. "Add an AI commander to sides that have players" gives you an AI teammate.
- If a player leaves, a teammate inherits their squads, or the AI takes over if nobody is left on that side.
- **Drop-in:** friends can join a battle that's already running (lobby option, on by default). They join the
  side with human players (the smaller side in PvP), get the current world, and receive a rifle squad and engineers at their FOB.
- **Fog of war is enforced by the host.** A client is only told about enemy units and buildings its side has spotted,
  gets a "hidden" marker instead of positions once they're out of sight, and never receives enemy supply, production
  or team stats. Enemy HQs and starting FOBs are revealed to everyone, like start locations in most RTS games.

## Controls

| | |
|---|---|
| Camera | WASD / arrows / screen edge pan, mouse wheel zoom, Q/E or middle-drag rotate |
| Select | Left-click a soldier to select his squad, drag a box, double-click for all of that type on screen. **Alt+click** a soldier (or click his name in the squad panel) to command just him |
| Groups | Ctrl+1..9 set, 1..9 recall (double-tap to jump there) |
| Orders | Right-click: move (Shift = fast run; **drag** to set which way they face), attack enemy, build/repair your structure, enter tunnel / MG nest / watchtower. The **cover pips** under the cursor show where each man will end up: green hard cover, lime medium, yellow soft (hides, doesn't stop bullets), grey dot none, red caught in the open; a tick on a pip points the way he'll fire over the barrier, and the label says how (prone, kneeling, standing, round the edges) |
| High-level | **X attack-move** (or Ctrl+right-click): the squad bounds forward by fire teams, cover to cover, fights whatever it meets, then digs in at the objective. **B defend**: click the area (drag to face) and the squad spreads into the best cover there and holds. **R retreat** to the nearest FOB (routes around known enemy fire, suppression halved). **H hold** |
| One soldier | With a single man picked out: right-click to move him into the best cover at that spot, right-click an enemy to engage, a nest or mortar pit to man it; G / T throw, H hold, R fall back. Any squad order brings him back into the squad |
| Squad | G grenade, T smoke, F mortar fire mission (mortar teams) |
| Build | Select infantry, click a building in the command card, left-click to place (R turns 90 degrees, Shift+wheel 45). Everything snaps to a 1 m build grid, shown round the cursor while you place. **Click and drag** to lay a whole line of trenches, sandbags, wire, walls or tank traps (lines run at 45 degree headings) |
| Defenses | Emplacements are crewed by any idle soldier standing next to them. Right-click a bunker with a squad to garrison it. Select a mortar pit for HE / smoke fire missions |
| Support | The buttons above the minimap (Z arms the first one ready): click the target, **drag** to set the run-in direction for gun runs and bombing runs |
| Observer | C director camera, V whose eyes to watch through, P pause, [ ] speed, F2 hide the interface. **Fire support** (observer bar) launches any air or artillery support anywhere to watch it |
| Command view | Tab tactical map, O order of battle (click a unit to select it and look at it, double-click to zoom in), the buttons beside the minimap turn map layers on and off (unit symbols, orders and attack plans, intelligence, weapon ranges, soldier labels) |
| Other | Home cycles FOBs, Space jumps to the last alert, Enter chats (Shift+Enter: team), L message history, F1 help, F3 performance overlay, **F4 field manual**, Esc menu |

## What's in it

**Soldier AI** (`scripts/game/soldier.gd`, `combat.gd`)
- **Fighting positions** (`scripts/game/cover.gd`): every wall, sandbag line, car, crate stack, wreck, rubble
  heap, window sill, nest and trench generates anchors along its faces - where a man stands, which way he
  faces, how high the barrier is there and what it's made of. How he fights from it follows from the height:
  prone behind a low lip (under 0.6 m), kneeling behind sandbags, a car or a garden wall (to 1.1 m),
  standing behind a chest-high wall or on a trench's fire step (to 1.55 m), and round the ends of anything
  taller, leaning out. His weapon rests on the top; when he ducks his head really is below it. Formation
  slots, the move preview and each man's own choice of cover all use the same positions, so a squad told to
  hold by a wall lines it.
- **What it's made of matters.** Hedges, tents and single crates are *soft*: they hide you, but rounds go
  through (a burst into a hedge finds whoever is behind it). Cars, house walls and stacked crates are *medium*:
  they stop a rifle, not a machine gun. Stone, brick, concrete, sandbags, earth and wrecks are *hard*: only a
  heavy machine gun or cannon gets through, slowly. Trenches, bunkers and HESCO walls are *fortified*. The same
  classes decide how much of a blast gets round them and how much near misses rattle the man behind.
- **The fight at a wall.** Come up, take a moment to find the target, fire a few bursts, get back down -
  reload only while down, calling for cover so the next man comes up. A man who drew fire stays down longer
  and comes up somewhere else: one position along the wall (crawling below the top of a low one), or the
  other corner of a tall one. If nobody near him is firing he stays up a little longer. Pinned, a regular
  waits for the fire to slacken; a fighter may hold his rifle up over the wall and fire blind. A machine gun
  can still pin men behind sandbags - that's what it's for - but they recover there, and shooters aim at the
  middle of a man behind cover as often as at his head, so what the cover is made of decides what gets through.
- Near misses add suppression, which pins soldiers in place (no peeking, they go prone), ruins their
  accuracy and slows their fire: whoever suppresses the other side more fires more (fire superiority).
  Pinned flat in the open a man only lifts his head for the odd burst. Nearby explosions make them flinch.
- Ammo runs out. When low they switch to single shots, then stop. They grab ammo off bodies they pass and run back to a FOB.
- Grenades get thrown at enemies hiding in cover. Soldiers dive away from incoming ones, and sometimes pick one up and throw it back.
- Explosions fling bodies. Some survivors get up dazed and stumble around. Soldiers vault low walls,
  slide into cover under fire, and fight hand to hand up close.
- FPV drones: soldiers hear them coming, shout, try to shoot them down, and dive at the last second.
- Downtime: after a quiet spell men get bored. They chat in pairs and rib each other (two-way banter, then a
  laugh), have a smoke, sit down, stretch, check their rifles or scan the horizon. Anything at all ends it.
- Animation: two-bone arm IK puts both hands on the weapon whatever it's doing: low ready, shouldered with a
  cheek weld and recoil, port arms at the run, compressed ready when crouch-walking, kneeling and prone aim,
  stepping out and tilting round a corner to lean and fire, a magazine change from the chest pouch. Walk/run
  cycles with torso twist, breathing at rest, a knee-buckle before the fall, three ways to lie dead.
- Kit: Coalition soldiers wear helmets with NVG mounts and headsets, plate carriers with mag pouches, assault packs
  and knee pads, and carry carbines with optics; Rebels wear shemaghs, mismatched chest rigs and carry AKs.

**Command and squad cohesion** (`squad.gd`, `commander_ai.gd`)
- Every squad has a callsign (Alpha 1, Bravo 2 / Lion 1, Hawk 2...) and a squad leader who takes the orders. On a
  long move he leads and the men keep their place in a wedge on him, laggards running to catch up, the leader
  easing off so nobody is left behind. When he goes down, the next man steps up and says so.
- The AI commander's orders go out over the command net ("Command: Jackal 1, Lion 2, assault D7.") and the squad
  leaders acknowledge them.
- **Deliberate attacks** (`attack_plan.gd`): an attack-move order is planned and executed the way infantry are
  taught. The leader halts and gives his orders; the support element (the machine guns and fire team Alpha, or a
  whole squad when several attack together) takes a support-by-fire position with cover and a view of the
  objective; the assault element (Bravo, with the leader, medic and AT man) moves round a flank on a covered
  route to an assault position. When support is set and firing, the assault goes in buddy team by buddy team,
  one pair dashing while the other fires, smoke thrown across open ground first and grenades at the last bound;
  support shifts its fire beyond the objective as they close, then lifts. On the objective everyone takes up
  all-round defence. Cut up or pinned, the assault falls back to the assault position and goes again when the
  fire slackens. Outnumbered, a squad goes firm and fixes the enemy instead and calls for help over the net:
  the AI commander answers with fire on the position (when its own men are clear) and sends up to two
  uncommitted squads to join; with the odds evened the plan re-forms and goes in. The assault flanks on the side
  it already stands, the base of fire sets up on the other, so their routes never cross.
- At a halt on a war footing (in an attack, defending, or with enemies about in the last minute) men in the
  open take a knee and machine gunners go down on the bipod; each watches his own sector, the flanks looking
  out and the last man of a big squad covering the rear. In town a moving squad folds into two staggered files
  along the street.
- Under fire men rush for cover and only crawl the last couple of metres; nobody glides across the ground,
  and nobody "vaults" a wall he's only walking along.
- Suppression lingers a moment after the last near miss, cover keeps out bullets better than it keeps out fear,
  and a man dashing between cover is much harder to hit than one walking; small arms aren't wasted on tanks.

**Pathfinding and tactics** (`nav.gd`, `hnav.gd`, `terrain.gd`, `squad.gd`)
- **Hierarchical A\* (HPA\*)** over both grids: the map is cut into 16 x 16 m clusters with entrances wherever
  neighbouring clusters connect (and wherever a road crosses), true costs inside each cluster precomputed. Long
  trips plan on the abstract graph, then refine cluster by cluster. When walls go up or are blown down only the
  touched clusters are rebuilt.
- **Danger maps:** every second each side marks the clusters its spotted enemies cover (MG nests, bunkers and
  armour count for more). Ordinary moves skirt them, retreats keep well clear.
- **Cover map:** every 1 m cell knows its cover level (heavy, light, none, exposed) and which way it faces, updated
  as things are built, destroyed or cratered. Formation slots snap to the best cover nearby (Company of Heroes
  style) and soldiers look for craters, rubble and woods when there's no wall to hide behind.
- Stuck watchdogs: infantry re-plan if they stop making progress; vehicles back off, turn and re-plan.

**The map** (`mapgen.gd`, `towngen.gd`, `decor.gd`)
- A town in the middle, laid out on a street grid: two main streets crossing at the centre, side streets closing
  some of the blocks, asphalt with a dashed centre line, curbs and sidewalks, zebra crossings at the crossroads.
  Houses stand on lots facing the street with their door to it; behind them, gardens closed off by hedges or
  walls, fences down the sides, vegetable patches, washing lines and trees; some have a drive with the car on it.
  Shops with awnings line the main street near the middle.
- A town square on one corner of the crossroads (fountain or statue, benches, planters, a flagpole, market
  stalls, bollards), a fenced playground (swings, slide, climbing frame, sandbox, seesaw, roundabout), a small
  park, allotments, a car park, a bombed-out lot and a water tower on the edge of town.
- Street lights down every street (they light up at dusk and at night), wooden utility poles carrying sagging
  power lines with a drop to each house, fire hydrants, stop signs where side streets meet the main road, the
  town's name on the way in and a bus stop. Power lines also run along the country roads.
- Country roads come in from both HQs and both edges of the map and join the main streets. A hamlet sits on the
  cross road; farmsteads (farmhouse and barn round a yard, hay bales, a fenced road frontage, an orchard) and
  hedged fields lie along the roads; abandoned cars on the verges, burnt-out armour off the road.
- Houses have dressed facades: sills and lintels, painted window frames with mullion and transom, panes (many
  shot out), shutters, door frames, steps and double doors hanging open.
- Walls, hedges, trees, cars and crates are all real cover. Street furniture is set dressing generated on the
  server and built on each client, and it breaks: a blast or a vehicle driving through knocks lamps, utility poles
  (their wires come down with them), signs, benches, bins, fences and playground kit over, and the pieces fall and
  lie where they land. Broken street lights stay dark at night.
- Trees are broadleaves (a flared trunk forking into limbs that carry clumps of leaves, darker underneath),
  spruces (many overlapping tiers of boughs) and small orchard trees; foliage has ragged, leafy edges and throws
  dappled shadows. A tree that is shelled or run over falls away from what hit it and stays down.

**Terrain** (`terrain.gd`, `mapgen.gd`)
- Country roads wind from HQ to HQ through the town, with a crossroad through the middle. On a road you're
  fast (vehicles +35%) but exposed. Mud slows everyone (vehicles badly) and leaves you exposed. Woods conceal you
  and give light cover. Vehicles strongly prefer roads.
- Deformable ground: every shell hole is dug into the ground itself (a fine ground mesh displaced by a height
  field kept identically on the server and every client): a bowl of churned earth with its rim thrown up
  around it, deeper for bigger rounds and deeper again when hit twice. Men lie in the holes, vehicles pitch
  and roll through them, grass is blown away, roads are holed, ragdolls and debris fall in. Craters give
  light cover and slow vehicles; wrecked buildings leave rubble. Cover and pathing update live.

**Wounded, medics and prisoners** (`squad.gd`, `rules.gd`)
- Badly hit soldiers go down screaming for a medic and start bleeding out. If they're strong enough they crawl to cover and keep firing a pistol, including while being dragged.
- The squad lays covering fire and throws smoke. A rescuer drags the wounded man back by the shoulders while an escort walks backwards beside them firing. Then he gets patched up (medics are 2x faster). Each time he goes down he comes back weaker.
- Medic tent: two stretcher bearers recover wounded *and dead* soldiers. If one bearer is hit, the other drags the stretcher alone. After the tent, soldiers limp back to base and rejoin a squad.
- Rarely, a cut-off soldier whose squad is all down will throw away his rifle and surrender. The Rebels march prisoners
  into their tunnels and interrogate them. The Coalition questions prisoners on the march back. Either way the
  prisoner gives **live intel** generated from the real game state (FOB supply and defenders, MG nests,
  mines, trucks on the road, production, attack plans), shown in the message log with a map ping.

**Interface**
- Boot splash and intro in Frontline's key art; the intro lifts once the menu's 3D backdrop has drawn.
- Main menu: grouped entries that say what they do, and a New Operation panel to pick a side (Coalition, Rebels
  or Observe, with each side's doctrine) and the time of day. The backdrop is a crewed .50 cal position at dusk.
- Loading screen before each battle: the operation's name, mission, side, area and conditions, a field note and
  the build's stages; it holds while the first frames compile behind it, then fades into the battlefield.
- **Order of battle** (O): every unit down the left, grouped into infantry, support teams and vehicles, each
  with its symbol, callsign, a pip per man, what it has been told to do and where an attack has got to ("Base of
  fire on D3", "Assaulting D3"), and alerts for contact, pinned, casualties and low ammunition. Click to select
  and look at it, Shift+click to add, double-click to zoom in. Observers see both sides.
- **Map layers** (the column beside the minimap): unit symbols at any zoom, orders and attack plans for all your
  units, intelligence (where the enemy was last seen and how long ago), weapon ranges of the selection, soldier
  labels. **Tactical map** (Tab): the battlefield dims under the symbols, every order, plan and contact, and the
  A-H / 1-8 grid on the ground.
- A selected squad shows each man's watch sector as a faint wedge on the ground, so you can see its all-round
  cover and any gap. An attack that goes firm against a stronger enemy raises an alert with its grid reference
  so you can send fires or reinforcements.
- Attack plans are drawn on the map: the objective with the current phase, the support-by-fire position with
  its fire converging on the objective, the assault route out to the flank and in. The squad card shows the
  phase as a PLAN > MOVE > ASSAULT > SECURE stepper.
- What you see over the troops depends on how far out you are:
  - **Close up** (the men): each soldier's name, an icon and what he's doing; speech bubbles (light for banter,
    dark for shouts, red for casualty calls, green for the radio); a line between men dealing with each other
    (two chatting, a medic and his patient, a guard and his prisoner); sergeant's chevrons on squad leaders, and
    when a leader shouts an order you see it go out to his men.
  - **Mid zoom** (the fire teams): no names, an icon over each man doing something worth knowing (firing,
    suppressed, pinned, reloading, wounded, treating, building, manning a gun, out of ammo, surrendering,
    chatting) and the combat shouts cut short.
  - **Zoomed out** (the squads): a NATO unit symbol per squad and vehicle (rectangle friendly, diamond hostile;
    X infantry, oval armour, both for mechanised, MG / AT / MORT / ENG tags) with a badge for its orders, a pip
    per man (white standing, red down), a burst when it's in contact and its callsign. Orders are drawn on the
    ground: dashed arrows for moves and withdrawals, a bold axis of advance and an objective ring for assaults,
    a defended arc for positions to hold.
  - **Orders coming down**: when the commander (you or the AI) gives a squad an order, it's seen leaving HQ and
    reaching the squad, the symbol pulses, the full route draws itself in and the order shows under the symbol
    ("ASSAULT D7"); closer in, it's heard over the squad leader's radio ("Six: assault D7.") before he
    acknowledges. Squads that bunch up spread their symbols out with a leader line to where they really are.
- The squad panel shows each selected squad's symbol, callsign, type and strength; the minimap carries the same
  symbols and the A-H / 1-8 grid the radio uses. FOB and HQ names are drawn over everything.

**Vehicles** (`vehicle.gd`, `drone.gd`, `projectile.gd`)
- Tanks smash through walls, trees and cars. Small arms ricochet off them. Frontal rockets can bounce,
  and a blown track leaves the tank stranded until engineers repair it. Destroyed vehicles become wrecks you can use as cover.
- Coalition: battle tank, **IFV** (tracked, 25 mm with airburst rounds, carries a four-man fire team), **Humvee**
  (.50 cal), supply helicopter, **attack helicopter** (circles its target with a 30 mm chain gun firing explosive
  rounds, plus rocket salvos).
- Rebels: old tank, **BTR** (eight-wheeled APC, 14.5 mm, carries a fighter cell), technical, **AA technical** (twin
  23 mm that tears helicopters and drones apart), FPV operators with kamikaze drones, RPG teams.
- **Mechanised infantry**: IFVs and BTRs come off the line loaded. The troops ride inside and dismount when the
  vehicle arrives, when the enemy is close on an attack-move, when it's badly hit, or on the Dismount button. If
  it's destroyed with them inside, the survivors scramble out of the wreck, most of them hurt.
- Armour classes: soft-skinned pickups and trucks bleed from rifle fire; light armour (Humvee, helicopters) shrugs
  it off and needs .50 cals, cannons, AA or rockets; tanks only fear anti-tank weapons.
- **Off-map support**, from minute five, each on its own cooldown:
  - Coalition: **air strike** (a jet drops a stick of four high-drag bombs across the spot), **A-10 gun run** (the
    Warthog comes in low and visible, nose down, and walks a burst of 30 mm through the target: the impacts land
    first, the BRRRT arrives after), **AC-130** (Spectre orbits for 25 seconds hunting anything in the circle:
    you hear the 105, 40 and 25 mm fire from overhead, then a second or two later the rounds rain down as tracer
    streaks), **155 mm artillery** (eight heavy shells, visible arcs and a tearing whistle).
  - Rebels: **rocket barrage** (sixteen rockets) and **mortar barrage** (twelve rounds).
  - Mortar and artillery shells are drawn a little larger than life with a smoke trail, so you can follow the arcs.
  - The AI calls them on dense groups of spotted enemies, never danger-close to its own troops, running gun runs
    in from its own lines.

**Base building and supply** (`structure.gd`, `rules.gd`)
- Placed buildings are just construction sites. Soldiers walk over and build them by hand, even mid-fight (engineers are 2x faster).
- Each finished FOB raises the unit cap by 20, resupplies nearby soldiers, and lays its own road back toward your HQ.
  Supply trucks drive those roads (Rebel trucks carry more, since the Rebels have no helicopters). If you ambush the trucks or block the road (tank traps, mines), every FOB past
  that point stops getting supply.
- Buildings: FOB, barracks, factory, medic tent, research post, helipad (supply helicopters fly over cut
  roads), sandbags, concrete walls, barbed wire, minefields, tank traps, watchtowers (long sight, shoots over
  walls), and Rebel tunnel entrances (move squads through the network or bring them back out with "Exit here").

**Base defenses**
- **Build grid**: buildings and works sit on a 1 m grid at 45 degree headings; a building's walls land on grid
  lines, a trench or wire line's centre line does, so separate lines meet cleanly. The AI and the map generator
  use the same grid.
- **Trench systems** (`trench_net.gd`): drag a trench line and it's laid as a crenellated fire trench: 6 m fire
  bays stepped back and forth by short traverses, all square to the grid (hold Alt for a straight communication
  trench). Every finished segment is dug into the ground and joins whatever it touches,
  so lines, junctions and communication trenches become one network: plank-revetted walls, duckboards on a muddy
  floor, spoil heaped along the lips. The AI digs a fire trench across each FOB's front with a communication
  trench back to it.
  - Inside, soldiers stand on the duckboards a metre down: crouched they're out of sight, standing they show head
    and shoulders over the parapet to fire. They prefer a trench to any other cover and move along trenches
    rather than across open ground.
  - Blasts that don't land in the trench itself mostly go over the men in it. A tank round fired flat at an
    entrenched man bursts on the lip in front of him, unless the tank is looking straight down that bay (enfilade),
    which is what the traverses are for. Tanks close in to get at a trench line, into RPG range.
  - The IFV's 25 mm airburst rounds burst right over the trench. Mortars, artillery and grenades that drop into it
    are deadly. That's how trenches are cleared.
  - Tracks claw across a trench slowly; wheels drop in and stick, so vehicles path around trench lines.
- **MG nest**: a sandbagged GPMG for pinning infantry - an M240B on the M192 mount for the Coalition, a PKM on
  its tripod for the Rebels, on a platform of bags behind a front wall low enough to fire over. The gunner kneels
  behind it with both hands on it; it traverses to where he aims within its arc, bucks as it fires and the
  tracers leave its muzzle. **Placed on a trench it becomes a gun bay**: the tripod on the front lip behind a low
  wall of bags, the gunner standing on the fire step, the trench left open. The AI sites its guns in its trench
  lines.
- **.50 cal nest** (M2HB on the M3 tripod / DShKM with a gun shield; also as a trench bay): 100 m range and crushing suppression. Its armour-piercing rounds shred trucks, technicals,
  helicopters and drones (they still bounce off tanks).
- **Mortar pit**: crewed automatically and fires on enemies your side has spotted, behind cover too, at 30–160 m.
  It holds fire when your own troops are within 8 m of the target. Select it to call 6-round HE or smoke fire missions.
  Rounds whistle on the way down, so soldiers shout "Incoming!" and hit the dirt, or dive if a shell is landing right on them.
- **Mortar teams** (both sides) do the same on the move with limited rounds. Press F to call a fire mission.
- **Bunker** (concrete pillbox, or a log-and-earth dugout for the Rebels): firing slits soldiers shoot through,
  and a roof that stops shrapnel. Right-click it with a squad to garrison.
- **AT post**: a crewed guided missile (Coalition, top attack) or recoilless rifle (Rebels) that engages vehicles out to 130 m.
- Soldiers in good cover are much harder to pin down than soldiers in the open, and only their head and shoulders are
  exposed when they pop up to fire. A fortified line beats a frontal assault by similar numbers.
- Everything can be shot up and repaired. Any FOB can be captured by whoever walks in and holds it. Lose your last FOB and you lose, but a side's last FOB is a last stand and takes four times as long to capture, and HQ sends a free reserve squad every 75 s to a side that is down to its last few soldiers.
- Fog of war, with intel pings.

**Look and feel** (`atmosphere.gd`, `mats.gd`, `vehicle_models.gd`, `vfx.gd`, `grass.gd`, `ui/`)
- Eight lighting moods (midday, golden hour, dawn, dusk, overcast, hazy, **night**, **rain & thunder**) with a
  procedural sky, AgX tonemapping, cloud shadows drifting over the ground, volumetric haze and a subtle film look.
  At night the sky fills with stars and illumination flares drift down on parachutes over the fighting, throwing
  moving shadows. In the rain, streaks fall around the camera, splashes hit the ground, puddles reflect the sky and
  lightning flashes are followed by thunder.
- Ambient sound: wind that grows as you zoom out, and a distant-battle rumble that swells with the fighting.
- Art direction: minimal modern-military hard-surface. Every box is chamfered so its edges catch the light; the
  palette is muted (low-contrast camo at a realistic scale, near-solid vehicle paint, parkerized gunmetal, faded
  civilian paint, weathered concrete, subdued ID panels and faded flags).
- Soldiers: the uniform in one colour and the kit over it in another (coyote or ranger green), as real units dress:
  helmet with rails, NVG mount and headset, plate carrier with flapped mag pouches, admin pouch, radio and
  tourniquet, battle belt, holster, knee pads, gloves, laced boots, a slim hydration carrier or an assault pack;
  rebels in muted clothes with AK chest rigs and caps, berets or shemaghs. Weapons at real size: M4A1 with ACOG,
  Mk18, AKM, M249, PKM, AT4, RPG-7 with its grenade, 60 mm mortar.
- Carried kit sits in standard attachment sockets (forward -Z, top +Y, origin at the balance point): launchers
  slung diagonally across the back, or level on the right shoulder with both hands on the grips to fire.
- Vehicles: real tyres and hubs, segmented skirts, bins, sights, lights; the Humvee is an M1151, the BTR a
  boat-hulled 8x8; each vehicle is merged per moving part (hull, turret, wheels, rotor).
- Every surface is a procedural material: plaster with brick showing through, concrete panels, corrugated metal
  with rust streaks, plank walls, HESCO baskets, camouflage on uniforms and vehicles, canvas, bark. Sandbag walls are
  stacked from individual lumpy bags, FOBs sit under camouflage netting that throws dappled shadows, trees sway.
- Vehicles are built from sloped, lofted armour: road wheels that turn, tracks, mantlets, cupolas, stowage, rotor blur.
- Explosions are layered GPU particles: a flash and light burst, a fireball that cools into soot, a lit smoke column
  that drifts with the wind, a dirt plume, sparks and debris that bounce on the ground, a rolling dust ring, a
  heat-shimmer shockwave and a scorch mark. Heavy rounds throw a fountain of earth high into the air that rains
  back down, and clods land around the crater once the debris has fallen.
- **Physics** (`physics_fx.gd`, `ragdoll.gd`, Jolt): the dead become ragdolls - eleven jointed bodies with
  anatomical limits (knees and elbows bend one way). A bullet knocks a man back and he folds; a blast throws him
  limbs flailing and he tumbles to a stop, into a trench if that's where he lands. Later blasts throw the bodies
  about again. Clods, stones and the pieces of anything destroyed are rigid bodies that bounce, roll and lie there.
  Heavy blasts throw cars and crates across the ground (they can land on their side or roof, and the cover goes
  with them), shove vehicles bodily, and a destroyed vehicle's wreck is thrown by the blast that killed it -
  a pickup flips, a tank barely lifts. Hulls ride on springs: they squat pulling away, dip braking, lean in turns,
  pitch over trenches and craters, rock when a shell lands close and kick back when the main gun fires.
  Where a wreck or a car ends up is decided on the server, so every player sees the same battlefield; the flight
  itself is run on each client. Ragdolls can be switched off in Settings (Low preset: off).
- Every shell, bomb or rocket that lands leaves a plume: smoke keeps billowing out of the crater for several
  seconds (up to a quarter of a minute for heavy rounds), swelling and leaning downwind as it rises, while dust rolls
  out along the ground and hangs there. Hits close together feed the same plume, so a barrage leaves one great
  drifting cloud over the target. Smoke is shaded like a volume (sun, sky, self-shadowing) and fades
  softly where it meets the ground. Burning wrecks burn, then smoulder. Smoke screens are real volumetric fog when
  volumetric fog is on. All effect shaders are compiled during loading, so the first explosion doesn't hitch.
- A minimal HUD: resources top-left, fading notifications, a terrain minimap, and selection / command panels that
  only appear when something is selected. Zoom in and every soldier shows what he's doing ("Bandaging Doyle",
  "Pinned down", "Manning the .50 Cal Nest", "Dragging Hakim to safety"); hover one for a small card.
- The main menu sits over a live 3D scene: a .50 cal crew at golden hour with a burning wreck and shelling on the horizon.

**Field Manual** (`ui/field_manual.gd`; main menu, Esc menu or F4): every soldier, squad, weapon, vehicle, building,
defence, fire mission and upgrade, with what it is modelled on (M4A1, PKM, M2HB, Bradley, BTR-80, AC-130J...), its
numbers read live from the game's tables with bars against the rest of its kind, derived figures (rate of fire,
sustained damage, squad firepower, km/h), what carries or trains it, and a 3D model to turn over and zoom.
A **Cover** chapter covers every kind of battlefield cover - stone and brick walls, hedges, sandbags, cars,
crates, wrecks, rubble, tall walls, windows, trenches, craters and woods - with what it stops, how much blast
gets through, how a man fights from it, and a diorama of a soldier doing so.

**AI commander** (`commander_ai.gd`) plays through the same command interface as a human. It places
buildings that its engineers must build, trains a mix of squads, saves for vehicles, expands with new FOBs,
garrisons, answers attacks on its bases, sends waves at your FOBs and ambushes your supply roads. The Rebel AI
digs forward tunnel entrances and moves its attack waves through them. AI-vs-AI results swing a lot between
batches of six games (from 5–1 one way to 5–1 the other with small parameter changes), so the sides are close
but balance needs real playtesting. With the base defenses, most games last 10–23 minutes.

## Architecture

```
main.gd                 menu <-> World, command-line test modes
autoload/defs.gd        all data tables (units, weapons, squads, vehicles, buildings, upgrades)
autoload/net.gd         ENet host/join, lobby, teams, start
autoload/sfx.gd         procedurally synthesised sounds
game/world.gd           entity registry, replication (spawn / snapshot / props / fx RPCs), commands, queries
game/entity.gd          base class: props on spawn, packed state in snapshots
game/soldier*.gd        brain + procedural articulated model
game/squad.gd           shared knowledge, rescues, smoke, surrender, auto-engineering
game/combat.gd          LOS, bullets (penetrating soft cover), suppression, explosions, choosing cover
game/cover.gd           fighting positions on everything solid, what each material stops, stances by height
game/rules.gd           supply network, trucks, cap, placement, capture, prisoners/intel, fog, victory
game/nav.gd             two AStarGrid2D layers (infantry: vaultable/slow cells; vehicles: smashable cells)
game/hnav.gd            hierarchical A* (clusters, entrances, danger-weighted abstract graphs)
game/terrain.gd         ground types, cover map, craters, speed / hit / concealment modifiers
game/trench_net.gd      the dug trench network (mask, walls, spoil, duckboards)
game/mapgen.gd          procedural battlefield + test scenarios
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
game/vfx.gd             GPU particle explosions, smoke, fire, decals, shockwaves (+ their shaders)
game/atmosphere.gd      sky, sun, fog, ground shader, post effects, moods
game/grass.gd           instanced grass, bushes and stones
game/mats.gd            procedural surface uber-shader, foliage, camouflage netting
game/vehicle_models.gd  lofted procedural vehicle models (also used for wrecks and the menu)
game/director.gd        observer camera and time controls
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
--focus-struct=kind[,n]                               camera on a structure of a kind
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
--follow=TEAM[,N]                                     keep the camera on that side's Nth squad (tactics review)
--trace=path.csv                                      log every man twice a second (position, posture, phase) for plotting
--manual=CATEGORY[,ENTRY[,SIDE]]                      open the field manual on a page (in a battle)
--pan=VX,VZ / --set=key:value,...                     drift the camera (shimmer tests) / override single settings
--scenario=guns                                       every machine-gun emplacement and trench bay, crewed, with targets
--curtain                                             show the intro / loading screens in an automated run
--menu-op=0|1|-1                                      open the New Operation panel on that side
--startup-trace                                       print the first frames' timings
--test-fire                                           every armed man, gunner and vehicle fires ahead (muzzle tests)
--seed=N                                              (with --aivai) the same map every run
--dump-structs                                        list every built structure when --quit-after fires
FL_DEBUG_HPA=1 (env)                                  benchmark hierarchical vs flat paths at start-up
FL_DEBUG_DECOR=1 (env)                                print the street-furniture chunk and mesh counts
--menu-shot=menu.png --shot-at=6                      screenshot of the main menu
```

Example:
`godot --headless --path frontline -- --aivai --timescale=8 --quit-after=600 --stats=120`

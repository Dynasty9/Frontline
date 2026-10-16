# What's in Frontline

The long version: how each system works and why. For the short version, see the [README](../README.md).

- [Full controls reference](#full-controls-reference)
- [Watching the AI](#watching-the-ai)
- [Multiplayer in detail](#multiplayer-in-detail)
- [Missions](#missions)
- [The systems](#the-systems)

## Full controls reference

| | |
|---|---|
| Camera | WASD / arrows / screen edge pan (Shift: faster), mouse wheel zoom toward the cursor (or + / -), Q/E turn, Page Up / Page Down tilt. Middle-drag turns and tilts; **Alt+middle-drag grabs the map** and pans (Settings swaps the two). **Backspace** squares the view up again, **Ctrl+F** follows the selection, **Ctrl+F5..F8** save a view and **F5..F8** go back to it |
| Minimap | Click or drag to look there, right-click to send the selection, wheel to zoom. Click the compass needle to square the view up |
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
| Other | Home cycles FOBs, Space jumps to the last alert (both glide there), Enter chats (Shift+Enter: team), L message history, F1 help, F3 performance overlay, **F4 field manual**, Esc menu |

## Watching the AI

**Watch AI Battle** puts you behind the camera while two AI commanders fight. A director camera cuts
between the hottest fighting and follows individual soldiers (the caption at the bottom says who and what
they're doing). The observer bar at the top has pause, speed (0.25x to 4x), director on/off and
"View": both sides, or one side's fog of war. Move the camera yourself and the director lets go; press **C** to hand it back.

## Multiplayer in detail

- The host is the authoritative server and runs the entire simulation, including the AI.
- **Matchmaking.** Hosted battles are listed on the matchmaker (`matchmaker/`, a small Node service on Railway) unless
  the host unticks "List online". **Find Match** joins the best open battle (ones still in the lobby first, then the
  fullest) or, if there is none, hosts one for the next player to find; **Join Game** shows the list. The matchmaker
  only introduces players: game traffic goes straight between them.
- **Getting through routers.** Before hosting, the game asks two public STUN servers what address and port its
  router shows the internet for the game port. A joiner does the same from a fresh port; the matchmaker swaps the
  two (the host hears about the joiner on a long poll), both send packets at each other so each router lets the
  other in, and ENet connects directly ("UDP hole punching"). Players behind the same router get the host's LAN
  address. If the two STUN servers see different ports the router is "symmetric" and can't be punched; the lobby
  says so, and that host needs UDP port **7777** forwarded. If a joiner isn't through in 12 seconds, Find Match
  moves on to the next battle.
- **The website** (`web/`) lists the battles being hosted, each with a **Join** link, `frontline://join/<id>`
  (and a Find Match one, `frontline://find-match`). An exported build registers the `frontline://` scheme the
  first time it runs (per user: HKCU on Windows, a hidden `.desktop` handler on Linux), so the browser starts the
  game with the link. If the game is already running, the new copy hands the link to it over a localhost socket
  and quits. A link is ignored in a battle or a lobby, so a stray click never pulls anyone out of a game, and a
  battle listed for another version of the game reads as not found.
- **Joining by address** still works without the matchmaker: the host's IP on UDP port **7777**, forwarded or over a
  LAN/VPN (Tailscale, ZeroTier, Hamachi).
- **Accounts** are optional (Supabase, through the matchmaker). Signed in, your callsign is yours: no other account can register it, and
  battles you host are listed under it with a tick. Sign in next to the callsign on the main menu;
  the session is remembered in `user://account.cfg`.
- **Co-op:** everyone picks the same side, and the AI takes the empty side.
  **PvP:** pick opposite sides. "Add an AI commander to sides that have players" gives you an AI teammate.
- If a player leaves, a teammate inherits their squads, or the AI takes over if nobody is left on that side.
- **Drop-in:** friends can join a battle that's already running (lobby option, on by default). They join the
  side with human players (the smaller side in PvP), get the current world, and receive a rifle squad and engineers at their FOB.
- **Fog of war is enforced by the host.** A client is only told about enemy units and buildings its side has spotted,
  gets a "hidden" marker instead of positions once they're out of sight, and never receives enemy supply, production
  or team stats. Enemy HQs and starting FOBs are revealed to everyone, like start locations in most RTS games.

## Missions

Short operations, about five minutes each, played alone or in co-op (**Missions** on the main menu; **Host Co-op**
opens a lobby, and friends join with Join Game). Each is built around something the game does well:

| Mission | Side | What it shows off |
|---|---|---|
| **Bridgehead** | Coalition | Clear a riverside village house by house, seize its bridge, hold it against infantry, a BTR and mortars coming over the bridge and the ford. 155 mm artillery on call. |
| **Beachhead** | Coalition | RHIBs land a party on the beach under a patrol ship's guns while enemy boats come out; kill two AA trucks, then a Blackfoot and a Ghost Hawk full of reinforcements come in from the sea. |
| **Sky Hook** | Coalition | Hook a Nyx tank destroyer under a Mohawk, fly it over the river to a cut-off outpost and stop the armoured column coming for it. |
| **Ambush Alley** | Rebels | Get into the woods above a lane before a convoy leaves, let the IED open the ambush, destroy the convoy, then break contact before the QRF (and its helicopter) arrives. |
| **Kingpin** | Coalition | A night raid: a checkpoint on the main street, a barred house, a Rebel commander to kill or capture, and a run back to the Hunters before the town cuts the road. |

- **Objectives** sit top right with the mission clock: each has a letter, and the same letter marks it on the
  ground (a ring round the area and a marker over it that waits at the screen edge when it's off screen) and on
  the minimap. A banner and a radio chime announce each one set, met or lost. Kinds: reach an area, clear it,
  hold it for a time, guard it, destroy targets, protect something, deliver a vehicle, extract, and timers.
- **The mission runs the enemy.** There's no AI commander: the mission places the enemy, sends in
  counterattacks and reinforcements, and calls their support; their own squad and crew drills do the rest.
- **The ground is the ordinary battlefield** on a fixed seed, and each mission places itself by the map's
  features (the lane bridges, the villages, the harbour, the main street), so it still works if map generation changes.
- **What's on call** is what the mission gives you, paid from a fixed stock of supply (no trucks, no reserves).
- **Co-op:** the force is shared out between the players in turn; a friend dropping in takes over half of
  whoever has the most. If everyone leaves, the mission's autopilot (the same one the automated tests use) keeps playing.
- The end screen says what happened and what it cost (time, objectives, men lost, enemy killed), with **Try Again**.

The code: `scripts/game/mission_director.gd` (the machinery), `scripts/game/missions.gd` (the content),
`scripts/ui/hud_objectives.gd` (the panel). Adding a mission is a catalogue entry in `Missions.LIST`, a setup
function and an autopilot function.

## The systems

**Soldier AI** (`scripts/game/soldier.gd`, `soldier_brain.gd`, `bt.gd`, `combat.gd`)
- **A behaviour tree decides what each man does** (`bt.gd`, `soldier_brain.gd`): one tree, shared by every
  soldier and walked each time he thinks. Reflexes come first, most urgent first; then, if he's free, the
  fight. The leaf that acted is kept on the soldier (`bt_path`) for debugging and the stats.
- **"Grenade!"** The first man to see it yells, and everyone near it picks one of, in order: *smother it* -
  when it's too late to throw and it's among men who can't get away (a wounded man being treated, a crowded
  bay), the man beside it may throw himself on it: it kills him and barely reaches anyone else; *throw it
  back* - two seconds or more on the fuse, within four metres, about one man in four has the nerve; *kick it
  away* - at his feet with a second to go, kicked off away from his mates and back towards the thrower; *get
  down behind the wall* if there's one between him and it; or *dive clear*. One man deals with a grenade;
  the others get out of the way.
- **Cooking grenades.** Against men in hard cover close by, a thrower often holds it a second or so after the
  spoon flies (you see him counting, grenade in hand) so it goes off as it lands - too late to throw back.
- **Clearing a house.** When a squad has seen an enemy inside a building, the man best placed stacks beside
  the doorway, back to the wall; pin out, he steps into the doorway and throws it in low under the lintel (or
  through a window), steps back against the wall for the bang, then goes in with a mate right behind him.
  If the door's shut he kicks it in first and only then pulls the pin. A new order waits until the grenade is in.
- **Doors.** Most houses' front doors are shut (double doors with panels and handles). Shut, they hide the room
  - nobody sees or shoots through them - and keep a grenade out. A man who walks into one in a fight kicks it
  in (a boot by the lock, the doors slam back against the wall inside, and whoever's in there hears it); with
  no enemy about he just opens it. A blast next to it blows it in. Door state is replicated to every client.
- **Behind cover with nothing happening** a man is up over the top keeping watch, weapon on the wall - not
  curled up behind it. The first round that cracks past and he's down.
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
- Grenades get thrown at enemies hiding in cover (see "Grenade!" above for what the other side does about it).
- Explosions fling bodies. Some survivors get up dazed and stumble around. Soldiers vault low walls,
  slide into cover under fire, and fight hand to hand up close.
- FPV drones: soldiers hear them coming, shout, try to shoot them down, and dive at the last second.
- Downtime: after a quiet spell men get bored. They chat in pairs and rib each other (two-way banter, then a
  laugh), have a smoke, sit down, stretch, check their rifles or scan the horizon. Anything at all ends it.
- Animation: two-bone arm IK puts both hands on the weapon whatever it's doing: low ready, shouldered with a
  cheek weld and recoil, port arms at the sprint, the weapon at the ready at a jog, compressed ready when
  crouch-walking, kneeling and prone aim, stepping out and tilting round a corner to lean and fire, a magazine
  change from the chest pouch. The stride is driven by ground speed (the planted foot doesn't skate) and the
  knee folds as the leg swings through; walking bent at the waist, or a low rush for cover under fire. A man
  moving one way while he aims another turns his hips and legs towards where he's going and his shoulders
  back to the target. Kicking, lying on a grenade, cooking one (grenade in hand), breathing at rest, a
  knee-buckle before the fall, three ways to lie dead.
- Kit: Coalition soldiers wear slate sneaking suits under armour vests, helmets and goggles (or a bandana),
  codec headsets, shoulder, elbow, knee and shin pads, and carry carbines with optics; Rebels wear balaclavas,
  berets, field caps and mismatched field jackets with chest rigs or bandoliers, and carry AKs.

**Command and squad cohesion** (`squad.gd`, `squad_brain.gd`, `commander_ai.gd`)
- **Battle drills** (`squad_brain.gd`): each squad has its own behaviour tree, walked twice a second, most
  urgent first. *React to contact*: fired on (or a new enemy in sight) while moving, everyone gets down where he
  is and returns fire while the leader calls it - "Contact! North-east, 150 metres!" - and once the enemy's fire
  slackens the squad carries on, by bounds while they're still about (a squad told to move fast keeps running).
  *React to indirect fire*: at the second shell or bomb among a squad that isn't dug in, it runs out of the
  impact area - sideways or back from the enemy, never towards him - and goes back to what it was doing when it
  lifts; men in trenches stay down in them. *Break contact*: a squad losing its nerve (or, for the AI, cut up and
  outnumbered) throws smoke and pulls back by bounds to a rally point, one team firing while the other moves,
  then counts off and checks its ammunition; crews on their guns and squads holding their own base don't.
  *Lying in wait*: a squad set to defend somewhere the enemy doesn't know about holds its fire until they're
  close, then the leader springs it and everyone fires at once.
- **Morale.** Casualties, fire it can't answer, tanks it can't fight and losing its leader wear a squad down;
  quiet, a leader, friends close by, a tank alongside and a hole in the ground build it back; dropping enemies
  lifts it. Steady, it fights as it should; shaken, it shoots worse and is pinned sooner; breaking, it breaks
  contact; routed, it runs for the rear and won't take orders until it has rallied. The squad card shows it.
- **Moving tactically** (`tactics.gd`). Out of contact a squad travels in its wedge; where contact is likely
  (the enemy about lately, or seen near where it's going) it moves by *bounding overwatch*: one fire team goes
  firm - down, spread out, watching its sectors - while the other dashes 30-odd metres to the next cover, then
  they leapfrog, so nobody is ever in the open without a team covering him. The covering team's gunner puts a
  burst into the hedge or house where the enemy was last heard (*recon by fire*). Ordered to run (Shift) it
  just runs. A squad sent to hold somewhere a long way off gets there as a squad, then spreads into its
  positions - and *clears* any house on that ground first: two men stack on the door, kick it in, go through
  (a grenade first only if someone's known to be inside) and call "Clear!".
- **Near ambush.** Hit at 30 metres or less, a steady squad that isn't hopelessly outnumbered assaults straight
  into the ambush instead of lying in the killing zone.
- **Stragglers and crews.** The last man of a squad attaches himself to the nearest friendly squad. A knocked-out
  vehicle's crew - those who live through it (few, if the ammunition goes up) - bail out in their coveralls and
  crew helmets and run for the nearest FOB to crew the next one; a little of the vehicle's cost comes back if
  they make it.
- **Spotting.** It's movement and muzzle flash that give men away: a man lying still or in cover who hasn't
  fired for a while is seen at little more than two-thirds the range.
- **Fatigue.** Sprints, rushes and dragging a man wear soldiers down: blown, they're slower and their aim
  heaves with their breathing, and a man catching his breath stands bent over, hands on his knees. A long move
  at a run arrives winded; a walk keeps men fresh. Men short of ammunition get a magazine from a mate beside them.
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
- **1 x 1 km** (`map_dims.gd`: every size, grid, mask and texture derives from one constant). The HQs sit
  at the north and south edges, their starting FOBs some 940 m apart, so a battle has room to move: fights for
  the villages, farms, woods and river line on the way in, then the town.
- **Water** (`water.gd`). The sea runs down the east side - a sandy beach, surf breaking along it, a concrete
  harbour quay where the cross road meets it, and the sea on out to the horizon. A river winds down the west
  flank from edge to edge: a concrete road bridge where the cross road crosses it, a ford in each half, muddy
  banks. A pond lies in each half. Deep water is impassable on foot or in a vehicle; men and vehicles can wade
  the shallows (fords, the edge of the beach) - slowly, and exposed. The beds are carved into the ground, so a
  man wading sinks to his knees, and the water is drawn with depth-tinted colour (turquoise shallows, deep
  blue sea, murky green ponds), soft ripples flowing downstream, foam along every shore and a swell on the sea.
  Bridges and the harbour are key points the AI fights over. The water is laid out on the server as a few
  shapes and rasterized identically on every client.
- On the 1 km map, country lanes branch off the main road to a village in each quarter (mirrored between the
  sides), and on the west the lanes run on over the river - each on its own bridge - to farming villages on
  the far bank: three bridges and two fords across the river in all.
- Country roads come in from both HQs and both edges of the map and join the main streets. Villages sit on the
  cross road either side of town and on the road between each HQ and the town; farmsteads (farmhouse and barn round a yard, hay bales, a fenced road frontage, an orchard) and
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
- **The camera** (`rts_camera.gd`) orbits a point on the ground and takes the controls players bring from other
  RTS games. The wheel zooms toward whatever is under the cursor and keeps it there. Middle-drag turns and tilts,
  Alt+middle-drag grabs the map like a sheet of paper (a setting swaps them), Page Up / Down tilt. The pitch comes
  from the zoom, low and level close in and steep from high up, and the player's tilt is added to it; close in it
  stops before the lens goes into the hedges. Keyboard and edge panning ease in and out, and Shift pans faster.
  Jumps (the last alert, a base, a group, a unit in the order of battle, a saved view) glide rather than cut.
  Backspace turns back to the heading the battle started on, Ctrl+F follows the selection until you pan away,
  and Ctrl+F5..F8 save views that F5..F8 glide back to.
- **The minimap** (`hud_minimap.gd`): the ground, water, roads (main roads light with a dark edge, supply
  tracks thinner), woods and every house's footprint (light while its roof stands, dark once it's a ruin) are
  baked into a texture. Over it go every man you can see as a dot (yours brightest, the selection white),
  vehicles by their map symbols, bases, objectives and alerts, and an orange ring pulsing wherever men are
  firing. The camera's view is a lit wedge with a line back to where the camera stands, and a compass needle
  shows where north lies in the view (click it to square up). Hovering gives the grid square under the cursor.
  Three sizes, and it can turn with the camera so the way you face is always up (Settings > Interface).

**Vehicles** (`vehicle.gd`, `vehicle_brain.gd`, `vehicle_roster.gd`, `drone.gd`, `projectile.gd`)
- **The core vehicles rebuilt** (`vehicles/vm_core.gd`): the M1A2 SEP Abrams, a worn T-55A, Hilux technicals (DShK
  or ZU-23-2 in the bed), the M1151 Humvee, the M2A3 Bradley, the BTR-80, the AH-64D Apache and the UH-60 Black
  Hawk - sloped armour, skirts, sights, stowage, rust and dents, each in its side's camouflage.
- **Sling loads.** Select a lift helicopter and right-click one of your vehicles: it flies over, hovers, hooks
  it on four strops and a cable, and climbs out with it swinging underneath - then flies it wherever you send
  it (slower with a load on), lowers it until it touches and lets go. The CH-49 Mohawk and the Rebels' Mi-290
  Taru (Lift) carry anything up to an APC (Humvees, technicals, BTRs, AA trucks); the Ghost Hawk and the Orca
  light vehicles only; nothing lifts a tank. A helicopter shot down drops its load - from height, it's
  wrecked. The AI uses its lift helicopters to ferry vehicles sitting idle far behind the lines up to its front.
- **Boats and ships** (built at the **Boat Dock**, which goes on the shore of the sea or the river facing open
  water, on your own half of the map). Coalition: the RHIB (six men, fast, unarmed), the Speedboat Minigun
  (armoured riverine craft, 40 mm GMG, a squad aboard) and the **Patrol Ship** (`vehicles/vm_ships.gd`, a Mk VI
  with a stabilised 25 mm). Rebels: an armed motorboat (PKM, four men), the Speedboat HMG and the **Gun
  Trawler** (a converted steel fishing boat with a ZU-23-2 on the foredeck). Boats find their way on their own
  grid of open water (shallows only to nose in to a beach; the low bridge stops them), sit in the water at
  their draft, pitch up as they get on the plane, heel into turns and leave a wake. Men board a boat lying off
  a beach or bank by wading out to it, and go ashore over the side wherever it stops by land at the end of a
  trip. A boat that's sunk goes down in a blast; whoever's aboard swims for the nearest bank. Shells landing in
  the water throw up a column of spray instead of digging a crater.
- **Driving.** A driver steers for a point some way down the road (pure pursuit: further ahead the faster he
  goes), slows for the bends he can see coming - as fast as the tyres or tracks hold the curve - and brakes to
  stop where he's sent. Wheeled vehicles steer like cars: a real turning circle from their wheelbase and
  steering lock, no turning on the spot, so a truck needs room to turn round. Tracked vehicles skid-steer:
  they pivot where they stand for a sharp turn but turn wider the faster they go. Weight sets how hard they
  accelerate and brake. A spot close behind is backed into rather than reached by a loop; a vehicle keeps its
  distance behind one going its way, drives round one standing in the road and passes oncoming traffic on
  the right; supply trucks keep to the right-hand side of the road. Hung up on something, it backs off, turns
  and plans again. (Trucks are slower on the road than they were, so each load carries more.)
- **Crews think for themselves** (`vehicle_brain.gd`): tanks, IFVs, APCs and armed cars have a behaviour tree,
  walked twice a second. *Smoke and back out*: a missile or rocket launched at it, the crew fires its smoke
  dischargers and reverses out of the line of fire, front armour still towards the shooter, then carries on
  with what it was doing. *Front armour to the threat*: halted with enemy armour or anti-tank teams in sight,
  a tracked vehicle swings its hull to face them while the gun stays on target. *Wait for the infantry*: an
  AI tank on an attack that sees rocket teams ahead with none of its own infantry about halts and shoots
  from where it is until they catch up (or pushes on after a while). *Pull back for repairs*: badly damaged,
  the crew takes it back to the nearest FOB to be patched up; a player can send it straight back in.
- **The Arma 3 garage.** Alongside the original vehicles, both sides field Arma 3's (`vehicle_roster.gd`), each
  modelled on the real vehicle Arma's is based on:
  - Coalition, NATO: Hunter (M-ATV, unarmed / HMG / GMG), Prowler (DAGOR, unarmed / HMG / AT), AMV-7 Marshall
    (Patria AMV, 40 mm), Rhino MGS and MGS UP (Rooikat, 120 mm), M2A1 Slammer and M2A4 Slammer UP (Merkava IV,
    carries a fire team), IFV-6c Panther (Namer), CRV-6e Bobcat (repair), IFV-6a Cheetah (twin 35 mm + missiles),
    M4 Scorcher (155 mm), M5 Sandstorm (rockets), HEMTT transport / ammo / repair / medical, UGV Stomper, and the
    AH-9 Pawnee, MH-9 Hummingbird, UH-80 Ghost Hawk (and stub wings), CH-67 Huron, AH-99 Blackfoot, MQ-12 Falcon and
    AR-2 Darter at the Helipad.
  - Coalition, AAF (the allied army): Strider (Fennek), AFV-4 Gorgon (Pandur II), FV-720 Mora (Warrior), MBT-52
    Kuma (Leopard 2), AWC Nyx autocannon / AT / AA / recon (Wiesel), Zamak ammo and medical trucks, CH-49 Mohawk
    and WY-55 Hellcat.
  - Rebels, FIA and Syndikat: Offroad (unarmed / HMG / AT / repair), MB 4WD LMG and AT, Quadbike, Truck, Van
    transport and ambulance, Zamak transport / repair / MRL, and a stolen M900.
  - Rebels, CSAT-supplied: Ifrit (Karatel, unarmed / HMG / GMG), Qilin (LSV, unarmed / minigun / AT), MSE-3 Marid,
    BTR-K Kamysh, T-100 Varsuk, T-100X Futura (railgun), T-140 Angara and T-140K, ZSU-39 Tigris, 2S9 Sochor,
    Tempest transport / ammo / medical / repair, Mi-48 Kajman, PO-30 Orca (and armed), Mi-290 Taru, KH-3A Fenghuang.
- **Tiers.** Light vehicles, trucks and transport helicopters from the start; tanks, IFVs, anti-aircraft
  vehicles and attack helicopters after Armoured Warfare (Coalition) or Foreign Advisers (Rebels); artillery, the
  heaviest tanks and drones after Combined Arms / Expeditionary Corps. The Factory and Helipad pages long lists
  by category (Light, Armour, Fire support, Logistics, Air) and show what's still locked.
- **What they do:** ATGMs at armour and bunkers, homing SAMs at anything flying; self-propelled guns and rocket
  launchers halt, lay the barrel or raise the launcher and fire salvos at spotted enemies (or on a fire mission:
  F); repair, ammunition and medical vehicles look after everything parked near them; troop helicopters fly
  their squad in, find clear ground, land, unload and fly home; drones circle where they're sent spotting for
  their side (the armed ones fire missiles); recon vehicles see further. New weapons: 40 mm grenade machine
  guns, 20/30/40 mm cannon, twin 35 mm, miniguns, each with its own sound; main guns by the vehicle (125 mm,
  120 mm, a railgun, recoilless rifles).
- **Boarding:** select infantry and right-click your truck, APC, Slammer or a landed helicopter: they climb in
  (as many as fit) and ride until they dismount or it arrives.
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
  - Coalition: **F/A-181 Black Wasp II strike** (a stick of four high-drag bombs across the spot), **A-10C
    Thunderbolt II** and **A-164 Wipeout gun runs** (in low and visible, nose down, walking a burst of 30 mm
    through the target: the impacts land first, the BRRRT arrives after), **AC-130U Spooky** and the cheaper
    **V-44X Blackfish** gunships (a left-hand orbit, port wing down, for 25 seconds, hunting anything in the
    circle with the side-firing 105, 40 and 25/20 mm), **A-143 Buzzard** strafe, **A-149 Gryphon** precision strike,
    **MQ-4A Greyhawk** drone (circles firing guided missiles), **UCAV Sentinel** (two bombs, no warning to the
    enemy), **155 mm artillery** (eight heavy shells, visible arcs and a tearing whistle).
  - Rebels: **To-199 Neophron** strafe, **To-201 Shikra** bomb run, **Y-32 Xi'an** gunship orbit, **rocket barrage**
    (sixteen rockets) and **mortar barrage** (twelve rounds).
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
- Soldiers (`soldier_model.gd`, `body_mesh.gd`) are styled after the early Metal Gear Solid games: heroic,
  heavy-shouldered figures with a strong silhouette, sculpted from lofted cross-sections (a deep chest tapering
  to the waist, muscle on the limbs, a squared jaw and a heavy brow over narrowed eyes, big gauntleted gloves and
  boots). The Coalition are FOXHOUND operators: slate-grey sneaking suits with a segmented belly, armour vests with
  a high padded collar, layered shoulder pads, elbow, knee and shin guards, black webbing, a pistol strapped to
  the thigh, and a helmet with goggles, a Genome trooper's balaclava with goggles down, or Snake's bandana, whose
  tails stream out behind him as he runs. The Rebels are Genome and Gurlukovich soldiers: balaclavas with goggles
  pushed up, berets pulled down over balaclavas, ushankas, Soviet field caps, watch caps and shemaghs, field
  jackets worn long with turned-up collars and breast pockets, sleeves rolled on some, AK chest rigs or
  bandoliers. Each side reads at a glance from the camera: cool slate against warm olive and khaki. Kit worn
  over the body follows its shape (straps, pads and plates sit on the cross-sections they cover). Weapons at real
  size: M4A1 with ACOG, Mk18, AKM, M249, PKM, AT4, RPG-7 with its grenade, 60 mm mortar.
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
gets through, how a man fights from it, and a diorama of a soldier doing so. **Drills & reflexes** shows what a
soldier does without being told: the grenade reflexes, cooking a grenade, clearing a house and kicking a door in,
each posed - and what squads and vehicle crews do (battle drills, morale, driving, smoke, waiting for the infantry).

**AI commander** (`commander_ai.gd`): spare squads go forward to hold the town, the villages and the larger
woods between its front and the enemy's, lying in wait, so the fighting is over the ground in between; a
forward FOB falls due every few minutes and supply is held back for it (each FOB runs its own supply truck,
so whoever expands first pulls ahead). It lays **ambushes** (`ambush_plan.gd`) on straight stretches of the
roads the enemy uses - his supply track above all - where there's cover to lie in: the squad moves to a rally
point back from the road, then into an L - the assault line 20-odd metres off the road, the gun at one end
firing down the killing zone, a man watching the flank - and holds its fire until they're in it. A short,
violent burst, then smoke and away (the Rebels, more often ambushers, simply melt away); an ambush nobody
walks into is given up after a few minutes, and one bumped on the way is called off. Its **navy**
(`naval_ai.gd`): once it has a factory it builds a dock on its stretch of coast and keeps a gunboat or two -
going after whatever of the enemy it can see near the water, else patrolling off the front - and a ferry that
runs raids, picking up a reserve squad at the shore and landing it on a beach near an enemy FOB or whatever's
being attacked. Spending draws on all of a side's FOBs (nearest first), so a big purchase - a tank, a dock -
isn't stuck waiting for one FOB to fill up; the AI saves for its factory and its first boat rather than
spending every round of supply on infantry. Armoured vehicles fire their smoke dischargers when a missile, rocket
or recoilless round is launched at them, and a guided missile whose operator loses sight of its target in the
smoke flies on blind.

The AI commander plays through the same command interface as a human. It places
buildings that its engineers must build, trains a mix of squads, saves for vehicles, expands with new FOBs,
garrisons, answers attacks on its bases, sends waves at your FOBs and ambushes your supply roads. The Rebel AI
digs forward tunnel entrances and moves its attack waves through them. AI-vs-AI results swing a lot between
batches of six games (from 5–1 one way to 5–1 the other with small parameter changes), so the sides are close
but balance needs real playtesting. With the base defenses, most games last 10–23 minutes.

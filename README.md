# Frontline

**A squad-level military RTS where every soldier thinks for himself.** Built in [Godot 4.7](https://godotengine.org) with GDScript, playable solo against the AI, co-op or head-to-head online.

[![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf?logo=godotengine&logoColor=white)](https://godotengine.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Check](https://github.com/Dynasty9/Frontline/actions/workflows/check.yml/badge.svg)](https://github.com/Dynasty9/Frontline/actions/workflows/check.yml)

![A firefight around a Coalition trench line](docs/screenshots/battle.jpg)

You command squads, not individual soldiers. You decide where they go and what they do there; they decide how. Men find real cover and fire over it, keep their heads down under fire, drag the wounded clear, throw grenades back, and break when the fight goes against them. Squads move by bounding overwatch, clear houses room by room, lie in ambush along the roads and assault in fire-and-movement. Tanks pop smoke and back out of a missile's path, boats land raiding parties on the beach, and helicopters carry vehicles in on a sling. All of it plays out on a 1 km battlefield with a town, villages, a river and the sea.

Every model and every sound is generated in code. There are no imported meshes, textures or audio files.

## Highlights

- **Soldiers who think.** A behaviour tree per man: cover chosen from the real collision shapes around him, suppression and pinning, grenade reflexes (smother it, throw it back, kick it away, dive), cooked grenades, kicking doors in, clearing houses, rescuing the wounded, surrendering when cut off.
- **Squads that fight like squads.** Battle drills (react to contact, react to indirect fire, break contact), morale and routing, bounding overwatch and recon by fire, deliberate attacks with support-by-fire and a flanking assault, L-shaped road ambushes, near-ambush assaults, stragglers joining other squads.
- **Combined arms.** Main battle tanks, IFVs, APCs, technicals and AA trucks, each with a crew AI: smoke and reverse out of a missile's line, keep the front armour to the threat, wait for the infantry, pull back for repairs, bail out when knocked out. Attack and transport helicopters, sling-loading vehicles, drones, mortars, artillery and air strikes.
- **War on the water.** The sea down one flank and a river down the other, with bridges and fords. Patrol ships, gunboats and RHIBs are built at a Boat Dock, and the AI runs amphibious raids.
- **A real battlefield.** A procedural 1 x 1 km map: a town on a street grid, villages, farms, woods, hedgerows, a river with three bridges, a sandy coast with a harbour, deformable ground that remembers every shell hole, and trenches you dig yourself.
- **Build and supply.** FOBs, barracks, factories, helipads and docks; supply trucks running real roads that can be cut; trenches, sandbags, wire, mines, bunkers and emplacements.
- **Multiplayer.** Co-op or PvP over the internet or LAN, with drop-in joining. The host is authoritative and enforces fog of war, so clients only ever learn what their side has seen.
- **A Field Manual** (F4) covering every unit, weapon, vehicle, building, drill and type of cover, each with a 3D model and the numbers behind it.

## Screenshots

| | |
|---|---|
| ![A Mk VI patrol ship off the coast](docs/screenshots/patrol_ship.jpg) | ![A road bridge over the river by a village](docs/screenshots/river_bridge.jpg) |
| A Mk VI patrol ship off the coast | The river, its bridges and the villages along it |
| ![A Humvee on a helicopter's sling](docs/screenshots/sling_load.jpg) | ![Armour fighting it out](docs/screenshots/armour.jpg) |
| Sling-loading a Humvee to the front | Armour fighting it out |
| ![The Field Manual](docs/screenshots/field_manual.jpg) | |
| The Field Manual | |

## Getting started

1. Install **Godot 4.7** (the standard build, not .NET) from [godotengine.org](https://godotengine.org/download).
2. Clone this repository:
   ```
   git clone https://github.com/Dynasty9/Frontline.git
   ```
3. Open `project.godot` in Godot and press **F5**, or run it from a terminal:
   ```
   godot --path Frontline
   ```
4. From the main menu, pick **Play vs AI**, **Watch AI Battle**, **Host Multiplayer** or **Join Game**.

New to it? Start with **Watch AI Battle** to see what the soldiers do on their own, then **Play vs AI**. Press **F1** in a battle for the controls and **F4** for the Field Manual.

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

## Watching the AI

**Watch AI Battle** puts you behind the camera while two AI commanders fight. A director camera cuts
between the hottest fighting and follows individual soldiers (the caption at the bottom says who and what
they're doing). The observer bar at the top has pause, speed (0.25x to 4x), director on/off and
"View": both sides, or one side's fog of war. Move the camera yourself and the director lets go; press **C** to hand it back.

## Multiplayer

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

## Documentation

- **[docs/FEATURES.md](docs/FEATURES.md)**: how each system works (soldier AI, squads, vehicles, the map, water, supply, the interface, the AI commander).
- **[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)**: the code layout, the settings and performance overlay, and the command-line test modes (AI vs AI, scenarios, off-screen screenshots).
- **[CONTRIBUTING.md](CONTRIBUTING.md)**: how to contribute.

## Contributing

Bug reports, ideas and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first; it covers running the headless checks before you open a pull request.

## License

[MIT](LICENSE) © 2026 Alexander Dines

Many vehicle names nod to the fictional vehicles of Bohemia Interactive's *Arma 3*. Frontline is a fan-made, independent project, not affiliated with or endorsed by Bohemia Interactive. All of its models are original, built in code from real-world references.

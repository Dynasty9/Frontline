# What's in Frontline

The long version: how each system works and why. For the short version, see the [README](../README.md).

- [Full controls reference](#full-controls-reference)
- [Watching the AI](#watching-the-ai)
- [Multiplayer in detail](#multiplayer-in-detail)
- [In a browser](#in-a-browser)
- [The console: finding out why it's slow](#the-console-finding-out-why-its-slow)
- [Missions](#missions)
- [The systems](#the-systems)

## Full controls reference

These are the default keys. **Settings â†’ Controls** (`scripts/autoload/keys.gd`, `scripts/ui/controls_page.gd`)
changes any of them:

- **By category:** camera, saved views, orders, abilities and fire support, building, control groups,
  co-commanders, interface, photo mode, observer, with the mouse's own controls listed at the end for reference.
- **Two keys per action.** A key can be a combination with Ctrl, Shift or Alt, a modifier on its own (Pan
  faster is Shift), or a mouse side button.
- **Rebinding:** click a key and press the new one. Esc cancels, right-click clears.
- **Clashes.** A key another action already has is moved off it, with a line saying so and an Undo. Keys only
  clash where both could be live at once: the turn-the-building key while placing doesn't clash with retreat,
  and observer keys don't clash with orders. Photo mode's keys are live only while it's on, so they clash only
  with each other and the interface's keys.
- **Matching.** The closest match wins: an exact combination first, then a key with extra modifiers held, so
  Shift + R still retreats while Ctrl + F follows rather than calling a fire mission.
- **Finding and resetting:** search by action or key, reset one action or everything (a second click
  confirms).
- **Saved** to `user://keybinds.cfg`, only the keys that differ from the defaults, so a new default reaches
  anyone who never changed that key.
- **Hints follow your keys:** the command card, the F1 help, the support buttons, the mode line, tooltips,
  camera messages and the loading-screen tips.
- Two optional actions start unbound: a ping key (tap: ping at the cursor; hold: the ping wheel) and a key that
  steps through your co-commanders' views.

| | |
|---|---|
| Camera | WASD / arrows / screen edge pan (Shift: faster), mouse wheel zoom toward the cursor (or + / -), Q/E turn, Page Up / Page Down tilt. Middle-drag turns and tilts; **Alt+middle-drag grabs the map** and pans (Settings swaps the two). **Backspace** squares the view up again, **Ctrl+F** follows the selection, **F9** cycles cameras on one selected object, **Ctrl+F5..F8** save a view and **F5..F8** go back to it. On a Mac's trackpad: two fingers grab the map (or zoom, a setting), pinch zooms, Option + two fingers turn and tilt |
| Minimap | Click or drag to look there, right-click to send the selection, wheel to zoom. Click the compass needle to square the view up. **Alt+click** pings, **Alt+right-drag** draws for your side |
| Co-commanders | **Alt+click** pings what's under the cursor (an enemy: "enemy spotted"; one of ours: "watch this"; the ground: "look here"). **Hold Alt + left button** for the ping wheel (attack, on my way, need support, danger, defend, look; let go in the middle to call it off). **Alt+right-drag** draws a line for your side. In the Command Net, click a name to look where they're looking, the screen button (or a double-click) to watch their view live |
| Select | Left-click a soldier to select his squad, drag a box, double-click for all of that type on screen. **Alt+click** a soldier (or click his name in the squad panel) to command just him |
| Groups | Ctrl+1..9 set, 1..9 recall (double-tap to jump there) |
| Orders | Right-click: move (Shift = fast run; **drag** to set which way they face), attack enemy, build/repair your structure, enter tunnel / MG nest / watchtower. The **cover pips** under the cursor show where each man will end up: green hard cover, lime medium, yellow soft (hides, doesn't stop bullets), grey dot none, red caught in the open; a tick on a pip points the way he'll fire over the barrier, and the label says how (prone, kneeling, standing, round the edges) |
| High-level | **X attack-move** (or Ctrl+right-click): the squad bounds forward by fire teams, cover to cover, fights whatever it meets, then digs in at the objective. **B defend**: click the area (drag to face) and the squad spreads into the best cover there and holds. **R retreat** to the nearest FOB (routes around known enemy fire, suppression halved). **H hold** |
| Delegate | **I** opens the intents on the command card: pick **Hold sector**, **Take objective**, **Screen**, **Reserve** or **Ambush**, then click the place (drag toward the enemy to set the front) and the XO carries it out. **Shift+I** takes the selection back; so does any order of your own to one of them. Each intent can have a key of its own (Settings > Controls, unbound to begin with) |
| Mixed groups | Give squads on foot and ground vehicles one Move order to drive at the selected foot pace. A fresh vehicle-only move restores normal driving speed. |
| One soldier | With a single man picked out: right-click to move him into the best cover at that spot, right-click an enemy to engage, a nest or mortar pit to man it; G / T throw, H hold, R fall back. Any squad order brings him back into the squad |
| Standing orders | **K stance** (auto, prone, crouch, stand) and **J fire discipline** (fire at will, return fire, hold fire) for squads or one picked-out soldier; for vehicles J and **N target priority** (auto, armour, infantry), **T smoke** (vehicles alone selected), **U dismount**. The command card shows each order in force and drops half the men aboard, or one squad of several |
| Squad | G grenade, T smoke, F mortar fire mission (mortar teams) |
| Build | Select infantry, click a building in the command card, left-click to place (R turns 90 degrees, Shift+wheel or Shift + two fingers 45). Everything snaps to a 1 m build grid, shown round the cursor while you place. **Click and drag** to lay a whole line of trenches, sandbags, wire, walls or tank traps (lines run at 45 degree headings) |
| Defenses | Emplacements are crewed by any idle soldier standing next to them. Right-click a bunker with a squad to garrison it. Select a mortar pit for HE / smoke fire missions |
| Support | The buttons above the minimap (Z arms the first one ready): press on the target, **drag** to set the run-in direction for gun runs, bombing runs and recon passes, then release to call it in. A click keeps the default approach; mortars, artillery and orbiting support target an area without a direction |
| Observer | C director camera, V whose eyes to watch through, P pause, [ ] speed, F2 hide the interface. **Fire support** (observer bar) launches any air or artillery support anywhere to watch it |
| Photo mode | **F9** opens and closes it (Esc closes it too). WASD fly the way the lens looks (Shift faster, Ctrl slower), E / Q up and down, Z / C roll (Backspace levels it), hold a mouse button and drag to look, the wheel zooms, Space takes the picture, F2 hides the panel |
| Command view | Tab tactical map (**hold Tab**: battle statistics), O order of battle (click a unit to select it and look at it, double-click to zoom in), the buttons beside the minimap turn map layers on and off (unit symbols, orders and attack plans, intelligence, fog of war, weapon ranges, soldier labels) |
| Other | Home cycles FOBs, Space jumps to the last alert or ping (both glide there), Enter chats (Shift+Enter: team), L message history, F1 help, F3 performance overlay, **F4 field manual**, **` (or ~) the console**, Esc menu |

## Watching the AI

**Watch AI Battle** puts you behind the camera while two AI commanders fight. A director camera cuts
between the hottest fighting and follows individual soldiers (the caption at the bottom says who and what
they're doing). The observer bar at the top has pause, speed (0.25x to 4x), director on/off and
"View": both sides, or one side's fog of war. Move the camera yourself and the director lets go; press **C** to hand it back.

## Photo mode

**F9** (Settings > Controls) opens photo mode in any battle, a replay or while spectating (`scripts/game/photo_mode.gd`,
its panel `scripts/ui/photo_panel.gd`):

- **The action holds still** in a solo battle or offline, the way the pause key holds it (the director's speed,
  which a solo battle's private host follows too), and in a replay by the replay's own speed. In multiplayer it
  never stops the battle: a host with anyone else in it, even a player still loading, plays on, and so does a
  client. Only the camera comes off.
- **The interface goes:** the HUD, the replay's controls and the performance overlay, and with them what marks
  the selection and a building being placed. The fog of war's shading on the ground can go too (only the
  drawing: who sees what is the host's, as ever).
- **A free camera** replaces the commander's orbit: WASD (the pan keys) fly the way the lens looks, the rise and
  sink keys straight up and down, easing in and out and faster the higher it is; holding a mouse button and
  dragging looks round, the wheel zooms. It stays between 0.6 m and 260 m over the ground and 120 m inside the
  map's edge, looks no more than 85 degrees up or down, and rolls up to 45 degrees either way.
- **The panel** (Signal, a sheet at the right edge; F2 hides it): field of view (15 to 90 degrees), focus (0.5 to
  600 m, on a logarithmic bar) and blur, real depth of field from the scene's `CameraAttributesPractical` with
  a round, high-quality bokeh while it's on; exposure in stops over the time of day's own; the time of day
  (`Atmosphere.apply_mood`); the colour grade with its contrast and saturation; vignette and grain; and the
  camera-and-lens passes (flare and glare, sun shafts, local exposure, eye adaptation, film look, heat haze), each on or off
  for the picture through `Atmosphere.look_override` whatever the settings say. The browser's renderer has none of
  those passes and no depth of field, so their rows aren't there.
- **The picture** (Space, or Capture) is the frame without the panel or any overlay, the film look kept, saved as
  a PNG in `user://screenshots/` (named by the date and time) with a note saying where. **Supersample** draws it
  at twice the render scale (as long as its long side stays within 7680 pixels) and scales it down, widening the
  depth of field's blur to match; in a browser, where a page's storage is out of reach, it's downloaded as well.
- **Leaving** (F9 or Esc, or the battle ending) puts back the camera, the battle's speed, the interface and every
  value it changed. Nothing is written to the player's settings.

The test switches `--photo-at=S --photo=key:value,... --photo-shot=PATH --photo-capture --photo-quit` open it in a
run and save the screen or a picture (listed with the other screenshot flags in `docs/DEVELOPMENT.md`), and
`tests/fixtures/photo-mode.gd` checks that entering and leaving put everything back.

## Multiplayer in detail

- The host is the authoritative server and runs the entire simulation, including the AI.
- **Hosting.** **Host a Battle** sets up the lobby: a name, the mode (**Co-op vs AI**: every player on one side and
  the AI commanding the other; **Versus**: players pick sides, and the AI can take an empty one; or a **Mission**
  played together), the seats (2 to 8), the time of day, drop-in, an AI commander alongside the players, and who
  can join: **Public** (listed), **Password** (listed with a padlock; the password never leaves the host, which
  checks what joiners send and asks again when it's wrong) or **Unlisted**. Missions' **Host Co-op** opens the same
  setup on that mission, so a co-op mission is listed like any other battle.
- **The server browser** lists every battle being hosted, online (from the matchmaker) and on the local network:
  name, host, mode (and side or mission), players and seats, whether it's in the lobby or running (open to drop-in or
  closed), and how good the connection should be (LAN, direct, hole punching, or a strict router). It can be searched,
  filtered (mode, full, running, passworded) and sorted by any column, refreshes itself every 10 seconds, and shows
  the chosen battle's sides and seats beside the list. Double-click (or **Join**) to join; a battle with a password
  asks for it first. **Direct connect** takes an address (and a port and password). A dialog ticks off each step of a
  join (checking the connection, asking the host to open the way in, connecting, joining the lobby) and says plainly
  what went wrong if it fails.
- **LAN discovery.** A host broadcasts a small beacon (UDP port 7787) every second with what the server browser
  needs; the browser listens while it's open, so battles on the same network show up with no internet. A battle that
  is listed online and also heard on the LAN is joined over the LAN.
- **The lobby** shows the two sides as columns: each player with their ready state (and HOST and YOU tags), the AI
  commander where the AI will play, the open seats, players still connecting, and anyone watching. Players switch
  sides (where the mode allows), watch instead, press **Ready**, and chat; the host changes the settings, removes
  players and starts when they like (it says who it's still waiting on). A player arriving gets a chime and their row
  lights up, and the host's taskbar flashes if the game isn't in front. Names are made unique (a second "Commander"
  becomes "Commander 2"). **Copy invite link** gives the website's page for a listed battle (`/?join=<id>`), which
  any player in the lobby can send a friend. Closing the lobby tells everyone in it why.
- **Matchmaking.** Listed battles are on the matchmaker (`matchmaker/`, a small Node service on Railway), which also
  hears each battle's mode, sides and whether it's locked. **Find Match** joins the best open battle (ones still in
  the lobby first, then the fullest; never one with a password) or, if there is none, hosts one for the next player
  to find. The matchmaker only introduces players: game traffic goes straight between them.
- **Getting through routers.** Before hosting, the game asks two public STUN servers what address and port its
  router shows the internet for the game port. A joiner does the same from a fresh port; the matchmaker swaps the
  two (the host hears about the joiner on a long poll), both send packets at each other so each router lets the
  other in, and ENet connects directly ("UDP hole punching"). Players behind the same router get the host's LAN
  address. If the two STUN servers see different ports the router is "symmetric" and can't be punched; the lobby
  says so, and that host needs UDP port **7777** forwarded. If a joiner isn't through in 12 seconds, Find Match
  moves on to the next battle.
- **The website** (`web/`) is pages, like any online game's site: a front page that shows the game off, Play,
  the Field Manual (how the game fights, and every soldier, squad, weapon, vehicle, building, fire mission and
  upgrade with its figures and 3D model), the live battles, the ranks and insignia, your profile and the changelog.
  Every page sits on the menu's living topographic map, quieter behind the text. Sign in, in the header, opens a dialog
  over whatever page you're on, and once you're in it takes you to your profile. It lists the battles being hosted,
  each with a **Join** link, `frontline://join/<id>` (and a Find Match one, `frontline://find-match`). Its Play page launches the game with `frontline://open`: any
  link the game doesn't know starts it (or brings a running copy to the front) and does nothing else, so older
  versions open too. The browser can't tell the page whether anything took the link, so the page watches for
  losing focus to the browser's prompt or the game's window, and otherwise explains how to set the game up the
  first time. An exported build registers the `frontline://` scheme when it starts (per user: HKCU on Windows, a
  hidden `.desktop` handler on Linux; a Mac app claims it in its Info.plist, which macOS reads when the app is first
  opened), so the browser starts the game with the link (on a Mac, as `--uri="frontline://..."`). It asks the
  system each time whether the links still open this copy (`reg export` of the command key, or `xdg-mime query
  default` and the `.desktop` entry's `Exec`) rather than trusting its own note of having claimed them
  (`user://links.cfg`): uninstalling another copy (the installer's uninstaller takes the links with it), a
  registry cleaner or another copy claiming them can take them away, and a game that went by its note never claimed
  them back. So the copy started last has the links. Asking runs another program, so it's done on a worker and the
  title doesn't wait. If the game is already running, the new copy hands the link to it over a
  localhost socket and quits. Only one copy can hold the socket, and one that finds it taken asks again every
  second: the copy an update replaces quits only after starting the new one, and a game that gave up on the socket
  would leave every later link to start a second game once the old copy had gone. A link is ignored in a battle or a lobby, so a stray click never pulls anyone out of a game, and a
  battle listed for another version of the game reads as not found.
- **Joining by address** (Direct connect) still works without the matchmaker: the host's IP on UDP port **7777**,
  forwarded or over a LAN/VPN (Tailscale, ZeroTier, Hamachi).
- **Accounts** are optional (Supabase, through the matchmaker). Signed in, your callsign is yours: no other account can register it, and
  battles you host are listed under it with a tick. The account card top right of the main menu signs you in or
  makes an account (the end-of-battle screen offers it too); the session is remembered in `user://account.cfg`.
  - **Players sign in with GitHub, on the website.** The game never asks for a password: Sign in opens the
    website with `?sign-in=<state>`, a random one-time value the game keeps (in `account.cfg` too, so it survives
    the game closing, for half an hour). The site sends the player to GitHub (OAuth with PKCE, through the
    matchmaker and Supabase); the first time makes the account, its callsign taken from the GitHub username
    (made to fit, and numbered if it's taken). Back on the site, it hands the game a session of its own in
    `frontline://sign-in/<state>/<refresh token>`. If the website is already signed in, it automatically
    authorizes a separate game session and returns to the game without asking for GitHub again.
    The game takes only the state it made, so no other page can
    sign it in to someone else's account, and spends the token at once. The game's session and the site's are
    separate (a refresh token works once, so the two can't share one), and signing out ends only that one.
    Both ends say what's happening, since the work is in the browser: the game's panel lists the steps (sign in
    on the website, let the browser open Frontline, the game signs in), lights up the one it's on and keeps a
    "Waiting for the website" line moving, then "Signing in..." when the link arrives; the site's dialog shows the
    two steps, and after handing over the link watches whether the browser took it (the page loses focus to its
    prompt or the game) and, if nothing did, says what to do.
  - **Email and password are for testing**: the game shows its own form when it runs from source or against a
    matchmaker the website doesn't know, and the website shows one on its dev server or when built against
    another matchmaker. The live site and the players' game only offer GitHub.
- **Service record.** Signed in, every battle you fight (as a commander, not watching) goes on your record when it
  ends: what kind of battle, your side, the result and length, your rating, score, kills and losses, and the
  after-action report itself, trimmed (every commander, both sides, the units that did most, the timeline). The
  menu's **Service Record** shows your career (battles, wins, kills, K/D, average rating, time in battle) and every
  battle newest first; open one for its after-action report. A battle fought signed out or offline waits in
  `user://pending_battles.json` (the last ten) and goes up at the next sign-in. A record is stamped with when it
  arrives, and a day holds 200.
- **Public profiles and leaderboards** (the website, `matchmaker/src/players.js`). Every player has a page on the
  website, `/player/<callsign>`: their rank, XP and record, their place on the all-time board, and (unless they
  keep them to themselves) their career and every battle on their service record, each with its after-action
  report, every commander rated as the game's stats screen rates them. The figures in a battle are that player's
  own game's word, and the page says so; they're never ranked. The **leaderboards** rank XP, which only the
  accounts database writes, timed on its own clock: all time, this month and this week (what was earned since the
  first, or since Monday, UTC), with a signed-in player's own row marked or added at the foot. A player can find
  any other by callsign.
  - **Your picture** on the website is your insignia, or the picture on your GitHub account (copied from GitHub at
    each sign-in; only GitHub's own image host is taken). No uploads, so nothing to moderate.
  - **Keeping your battles to yourself** (your profile, "Show my battles") takes your battles and career off your
    page; your rank, XP and record stay public, and the game still shows you your service record.
  - **A battle counts on the record** (battles fought, won) only if it earned XP: two minutes or more on the
    database's clock. Before, a "win" reported a moment after starting counted as a battle won.
  - **Moderation**: a player marked `hidden` in the database is on no board and has no page
    (`matchmaker/README.md`).
- **Ranks and insignia** (`ui/insignia.gd`, `ui/insignia_art.gd`, `matchmaker/src/ranks.js`). Signed in, every
  battle you fight earns XP, and you climb 50 ranks from Recruit to General of the Army (Private I-V, Corporal,
  Sergeant, Staff Sergeant, Master Sergeant, Lieutenant, Captain, Major and Colonel I-V, then the five grades of
  general). Each rank takes 20 XP more than the last: 150 for the first, 32,000 in all.
  - **XP.** A point for every six seconds of battle, up to 45 minutes; a win is worth half as much again, leaving
    before the end half as much. A battle under two minutes earns nothing. Watching a battle (or a test
    scenario) doesn't count. There's no game server to referee (players host), so each game reports its own
    battle, but the matchmaker times it on its own clock, from the battle getting under way to its end: a
    modified game can't claim more time than really passed. Players can't write their XP to the database
    directly; it changes only through functions that act on the caller's own row (`supabase/migrations/`).
  - **Insignia.** 160 of them, all drawn as SVG by the game from short descriptions: ten starter patches every
    account has (the branches: infantry, armour, artillery...), a patch for each rank (subdued training patches
    at the bottom, lettered company patches, tabbed patches, special forces arrowheads, then bullion and the
    generals' stars at the top), and 100 shown but locked for now: medals, badges and ribbon racks, and company
    and squadron patches in the style of the Vietnam war and of the battlefield's own units. They're original
    designs in the style of real ones, not copies.
  - **Where you see them.** Your insignia sits on the account card at the top right of the main menu, with your
    rank and how far through it you are; click it for the collection, where the unlocked can be worn and the
    locked say what unlocks them. The after-action report's header says what the battle earned, and a promotion
    shows the new patch. In the lobby each signed-in player's insignia is beside their name, and on the website beside the host of a listed battle. The
    website has the same collection, and picking one there is picking it in the game: it's kept on the account.
- **Error reports.** When something goes wrong in a release build (an engine error, a shader the graphics driver
  rejects, a crash), the game tells the matchmaker what failed and where in its code, with the GDScript calls that
  led there, so the developers hear about it without anyone writing in (`autoload/errors.gd`). A crash is sent by the
  next launch, from the log the engine left. A report carries the game's version, the operating system, the graphics
  card and driver, and whether it happened in the menus or a battle; paths on the player's machine, addresses and
  emails are taken out, and nothing says who sent it. Settings > Interface > Send error reports switches it off.
- **Co-op:** everyone on the battle's side, and the AI takes the other. **Versus:** players pick sides ("The AI
  takes a side nobody plays" fills an empty one). "AI commands alongside players" gives either an AI teammate.
- If a player leaves, a teammate inherits their squads, or the AI takes over if nobody is left on that side.
- **Rejoining** (`net.gd`, `World._on_player_rejoined`): a player who drops out (a lost connection, a crash, Leave
  Battle) can come back for the rest of the battle, even one closed to drop-ins, full or behind a password (they were
  let in before, so it isn't asked again). Each copy of the game makes itself a
  random token and registers with it; the host keeps a departed player's place by token (side, colour) and the
  squads and vehicles they commanded, and hands back whatever is still fighting from whoever held it. Units they had
  queued that came out while they were away go to the stand-in and back to them too. An AI that only stood in for a
  side left without commanders steps down and hands over everything it held; an AI ally the lobby asked for stays.
  In a mission they get their share back (or, if it's all gone, a share like a newcomer). Their after-action record
  (`BattleStats.rejoined`) carries on under their new peer id, and a player back after the end gets the report and
  the end screen. The host never passes the token on, so nobody else can claim a player's place.
  - **The client remembers the battle** in `user://rejoin.cfg` (address and port, the matchmaker listing, the host's
    name, the token), kept fresh while playing, so after a lost connection or a restart the main menu shows a
    "Battle in progress" card with **Rejoin** (and Forget) for two hours. Rejoin goes through the matchmaker again if
    the battle was listed (its router may need punching afresh), else, or if it's gone from the list, to the address
    it had. The record is dropped when the battle is decided, when nobody answers, or when the host is back in a lobby.
  - **A crash**: the host can't tell a dead link from a quiet one for 45-90 s (the long ENet timeouts), so when the
    same token connects again it lets the old link go at once and the new one takes the place.
- **Co-commanders** (`co_command.gd`, `ui/hud_coop.gd`, `ui/hud_coop_roster.gd`): you see what the other
  commanders on your side are doing, as they do it, the way officers in one command post see each other's
  map markings and hear what each is calling for.
  - **Colours.** Each player is given a colour in the lobby (the swatch by their name), kept all battle and
    clear of the two sides' blue and red, so "I'm the pink one" works over voice.
  - **Presence.** Ten times a second while anything changes (once a second when nothing does) each game tells
    the host where its camera is looking, where the cursor is, what's selected and what's being lined up; the
    host passes it on to that side only, and to observers (never the enemy: where you're looking gives your
    plan away). About 110 bytes a packet; it only ever drives drawing, never the simulation.
  - **On the battlefield**, in the commander's colour: a viewfinder on the ground at the middle of their
    screen, turned the way they face and sized to their zoom, with "ROOK'S VIEW" under it (the tactical map
    adds the whole patch of ground their screen takes in); their cursor, an arrow pointer with a name tag
    that says what they're doing ("Laying a trench line", "Aiming 155 mm Artillery", "Ordering an attack");
    a dashed ring round each squad or vehicle they have selected; and whatever they're about to commit:
    the building's ghost or the line being dragged out (with a tick per length), the fire mission's beaten
    zone with a hazard sign on it, the order being dragged out with a line from their units to it. A
    commander looking somewhere off your screen waits at its edge with how far away it is: click the marker
    to look there. Their units carry their initials on the unit symbols, a fresh order under a symbol says
    who sent it, and the order's link from HQ is in their colour.
  - **Command Net** (top right, under a mission's objectives): one row per commander with their colour and
    initials, what they command, and what they're doing this moment, in order: lining something up; the
    order they've just given ("Ordered Golf 1: ASSAULT D4"); what they've just committed ("Called in 155 mm
    Artillery · E5"); who they have selected; idle; or which square they're watching. A row flashes when its
    commander pings. Its buttons look at their view, or watch it live: your camera keeps to their view
    until you pan, turn or zoom, with their colour round the screen and a caption saying whose view it is.
  - **Who spent the supply.** The host tells the side when a commander puts down a building, lays a line,
    calls in fire support, sets a squad training or starts research. Fire support and research show as a
    notification, the rest go to the message log (L).
  - **Pings.** Alt+click marks what's under the cursor (an enemy in sight: "Enemy spotted: BTR-80", stuck
    to him while he can be seen; one of ours: "Watch this: Bravo 2"; the ground: "Look here"). Holding Alt
    and the left button opens a wheel: attack here, on my way (drawn as a line from their units), need
    support, danger, defend here, look here. A ping is a pin with its sign, rings spreading over the ground,
    who sent it and how far it is; off the screen it waits at the edge; it pulses on the minimap, chimes
    (a sharper chime for danger, enemies and calls for help) and goes in the message log. Space jumps to
    the newest. The host lets each commander send a few a second at most.
  - **Sketches.** Alt+right-drag (on the battlefield or the minimap) draws a line for the side, a route or
    an axis of advance; it draws itself in on their screens with an arrowhead and the drawer's initials,
    and fades after 14 seconds, like a grease-pencil line wiped off the map case.
  - Settings > Interface > "Co-commanders' views and cursors" turns the presence drawing off (pings,
    sketches and the Command Net stay).
- **Drop-in:** friends can join a battle that's already running (lobby option, on by default). They join the
  side with human players (the smaller side in PvP), get the current world, and receive a rifle squad and engineers at their FOB.
- **Joining** (`World._client_ready`, "joining" in `world.gd`): a client's world starts empty and the host sends it
  the battle as it stands in a few compressed messages (a few hundred kB for a whole town): the ground first (the
  water's shapes, the roads, the set dressing and the host's own ground kinds, so paving and bridge decks are road
  on every peer), then every entity it may know of, a structure only with what differs from a new one. The client
  lays the ground out on a worker thread while the rest arrives, then builds the entities and works out the cover
  map a slice of each frame at a time, answering the connection every frame. The loading screen stays up, saying
  how far it has got, until all of it is built, so play starts on the whole battlefield with no backlog.
- **Fog of war is enforced by the host.** A client is only told about enemy units and buildings its side has spotted,
  gets a "hidden" marker instead of positions once they're out of sight, and never receives enemy supply, production
  or team stats. Enemy HQs and starting FOBs are revealed to everyone, like start locations in most RTS games. Each
  player's game draws the fog from its own side's units (which it always knows), so nothing extra crosses the wire
  but the strips a recon flight has just photographed.

## In a browser

Every release also comes as a browser build (WebAssembly and WebGL 2), the same game with nothing to install. It
plays alone: **Play vs AI**, **Missions** and **Watch AI Battle**, the Field Manual and Settings, and signing in for
a service record. Multiplayer needs the desktop game, since a browser can't make the direct connections a battle
between players runs over; the menu links to the downloads instead. It looks a little different (no screen-space
lighting, volumetric fog or particle trails, which the browser's renderer doesn't have: the mist and the weather's
smoke and dust thicken the plain fog where you look instead, and the water's caustics are a single web) and, with no threads to
spread the work over, the map takes about 30 seconds to lay out, a stage at a time behind the loading screen. The
simulation runs about as fast as on the desktop. The first battle also waits while the browser compiles the game's
shaders (it keeps them, so only the first time); to keep that short, surface lighting is worked out per vertex and emitter particles run on the processor. Animated blast clouds and
batched debris still run in shaders; explosions, muzzle flashes and fires don't cast light.

## The console: finding out why it's slow

The key under Esc (**`** or **~**, rebindable in Settings > Controls) drops a console down from the top of the
screen, in a battle or in the menus. Its commands are mostly about one question: why is the game slow? Tab
inserts a command or its argument from a scrollable dropdown. With an empty prompt, the dropdown lists every
command and its description; typing ranks prefixes, partial spellings and small typos. Up/Down chooses a
suggestion, Tab or a click inserts it, and Enter inserts an explicitly chosen suggestion without running it.
Otherwise Enter runs the prompt as typed. Ctrl+Up/Down browses command history; Esc dismisses the dropdown,
then closes the console. Completion works at the caret and preserves arguments after it. `help` lists everything.

Select output with the mouse, double-click words, or focus it and use Ctrl+A; Ctrl+C copies the selection
without colour markup. Both output and prompt have right-click menus. Ctrl+V (or Ctrl+Shift+V) pastes into
the prompt for editing; Enter is still required to run it. The prompt supports selection, cut, undo/redo,
and word/caret movement. Ctrl+Shift+C copies selected output, or all output when nothing is selected.
The toolbar also has **Copy all** and **Save text** (`save`), which writes a timestamped text file in the
game's user-data directory and prints its full path.

Ctrl+F searches scrollback, ignoring case; Enter/Shift+Enter jumps to the next/previous match with wraparound.
Esc dismisses search first. PgUp/PgDn scroll, Ctrl+Home/End jump to the oldest/latest output, and **Latest**
returns to the live output. Ctrl+L clears output without losing command history. Ctrl+C with no selection
clears the prompt and stops an active benchmark, restoring its settings. Ctrl+plus/minus changes text size,
Ctrl+0 resets it. Scrollback is bounded to 600 paragraphs and command history to 60 entries.

- **`why`** reads the last five seconds and says what's holding the frame rate back: the screen's refresh or the
  frame limit (not a problem), the graphics card (with the resolution it's drawing at), or the processor, and then
  which part of it: the battle's game logic (its biggest systems, and whether the simulation keeps up with the
  clock), the view's scripts, the renderer's draw calls. It adds the stutters of the last minute and what they
  were, a flood of engine errors, an integrated graphics chip, a slow connection to the host.
- **`bench`** (about a minute, or `bench quick`) turns each graphics setting down in turn, times the frames, and
  lists what each saves, the most first. Vsync and the frame limit are off while it runs so a saving shows; your
  own settings are measured again every few steps, so a battle that changes as it runs doesn't skew the answer,
  and the middle frame of each measure is taken, so the stutter of a setting rebuilding (water, grass) doesn't
  count against it. It also tries the battle paused (how much of each frame is the battle itself) and the
  interface hidden, and puts everything back at the end.
- **`graph`** pins a panel of every frame of the last ten seconds, each a column stacked by what its time went on
  (game logic, view scripts, the renderer, the rest), the GPU's time as a line over it, and each stutter marked.
- **`hitches`** lists the latest stutters (frames far longer than those round them, or over a threshold you give)
  with what each was: the game logic catching up several ticks at once, a script, shaders compiling, engine errors.
- **`top`** the costliest systems, game logic per tick and view scripts per frame, on average and at their worst;
  **`render`** draw calls for the scene, the shadows and the interface; **`sys`** the computer (graphics card and
  driver, processor, memory, screen, renderer); **`net`** the round trip and packet loss; **`errors`** what the
  engine has logged.
- **`perf 0-3`** and **`fps`** set the performance overlay (F3 cycles it); **`set`**, **`settings`** and
  **`preset`** change settings as the Settings screen would (`set shadows off`, `set scale 77%`); **`pause`**
  pauses a battle you play alone; **`draw overdraw`** and its kin show the scene's debug views.
- **`report`** writes all of it (and the last bench) to `perf_report.txt` in the game's user folder and copies it
  to the clipboard, to send to whoever is helping.

Every frame is measured (`scripts/ui/perf_probe.gd`) for the overlay and the console: how long it took, the game
logic and view scripts run in it, the renderer's CPU and GPU time, shader compilations and engine errors, kept
frame by frame for ten seconds. Each system's own frame-by-frame cost (its worst frame, which system a stutter was
in) starts being kept when the console first opens, since it costs a little every frame.

## Missions

Short operations, about five minutes each, played alone or in co-op (**Missions** on the main menu; **Host Co-op**
sets one up as a listed battle, and friends join it from the server browser). Each is built around something the game does well:

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
`scripts/game/mission_list.gd` (the catalogue), `scripts/ui/hud_objectives.gd` (the panel). Adding a mission is a
catalogue entry in `MissionList.LIST`, a setup function and an autopilot function.

Ambush Alley autoplay can call its existing mortar support against spotted, stopped convoy vehicles before extracting; player resources and mission objectives are unchanged.

## The systems

**Soldier AI** (`scripts/game/soldier.gd`, `soldier_brain.gd`, `bt.gd`, `combat.gd`)
- **Priority decisions govern each man** (`soldier_brain.gd`): reflexes come first, most urgent first;
  then, if he's free, the fight. Direct checks avoid dispatching a tree of callbacks for every soldier.
  The action that won is kept on the soldier (`bt_path`) for debugging and the stats.
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
  hold by a wall lines it. Tall barriers also offer a second row 1.5 metres behind the first:
  overflow soldiers shelter there when the front row is occupied. Physical wall blocking still applies,
  but their effective cover rating is one tier lower (less shelter from near misses), and they
  cannot lean around an edge from that row. The wall itself retains its normal bullet resistance.
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

**Standing orders** (`soldier.gd`, `squad.gd`, `vehicle.gd`; `World.execute_cmd` "stance", "roe", "prio",
"pop_smoke", "dismount")
- Orders that stick until changed, through every move and attack, for a whole squad (each man gets it), one
  picked-out soldier (he stays in his squad's formation for it) or a vehicle's crew. They replicate as each
  soldier's and vehicle's props, and the command card shows the one in force as filled segments (none filled
  when the selection differs).
- **Stance**: auto (his own judgement), prone, crouch or stand. Told to stay down he crawls when he moves at a
  walk (a run order gets him up) and fights from the ground; behind a wall too high to fire over from there, or
  kneeling by a corner, he keeps watch and leaves the shooting to others. A pinned man won't stand up whatever
  he's told, and the reflexes win over the order: hitting the dirt, diving from a grenade, deep water.
- **Fire discipline**: fire at will; return fire, which frees the trigger for 10 s after a round cracks past
  any man of the squad or hits one; or hold fire. Holding fire, men don't shoot, throw grenades, fire rockets,
  launch drones, call their own mortar targets or clear a house - with two exceptions decided as the design:
  an enemy within 15 m is overrunning them and they fight (holding fire never means letting them into the hole
  with you), and anything they're explicitly told to attack is fair game. Fire missions you order still fire,
  and hand to hand is always on. A squad holding or returning fire doesn't stop for a contact drill at an
  enemy it merely sees, only when it's fired on.
- **Vehicles**: the same fire discipline (the crew answers anything within 22 m, or once it's been shot at,
  for return fire), with smoke, backing out of a missile's path and pulling out badly damaged still the
  crew's own. **Target priority**: armour first (the main gun saved for vehicles, the machine gun for the
  men) or infantry first (high explosive on any man in the open). **Smoke on call** fires the dischargers
  towards the nearest threat (or along the turret) at least 4 s after the last salvo; the salvoes left are
  on the card.

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
- **Moving tactically** (`tactics.gd`). Out of contact a squad travels in a compact group; where contact is likely
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
  long move he leads and the men keep a compact circle behind him, laggards running to catch up, the leader
  easing off for the furthest laggard. Followers file through the same gaps before spreading out again.
  Orders place the men within 5.5 metres of their destination (6.5 when defending), favoring cover on
  the same side of walls. Fighting men search within 3 metres of their assigned place without crossing
  a barrier; detached soldiers, emergency dives and casualty rescue retain their own freedom.
  Formation placement shares ground candidates across the order; native builds score them in Rust,
  with a GDScript fallback preserving the same destinations and cover rules.
  When the leader goes down, the next man steps up and says so.
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

**Reconnaissance and the fog of war** (`vision.gd`, `fog_view.gd`, `rules.gd`, `projectile.gd`)
- **What a side sees** is the sum of its eyes, each a circle of sight (`vision.gd`): a man 56 m (75 m up a
  watchtower), a man down 22 m, a vehicle what its optics give it (most 50 m, scout cars 75-85 m, the Nyx Recon
  110 m, drones 70-75 m), a FOB or HQ its perimeter, other positions their sentries, an FPV drone its camera. The
  host works out the fog from them two and a half times a second; enemies outside every circle aren't sent.
- **You see the fog.** Ground your side can't see right now is drawn darker and cooler, on the battlefield and on the
  minimap, so the edge of what you know is plain. Every eye is drawn as a soft disc into a small map of the
  battlefield (about 5 m to the pixel, fifteen times a second); a full-screen pass finds where each pixel lies on the
  ground from the depth buffer and darkens it there. Aircraft high overhead aren't darkened; at night the fog is
  lighter, because everything is dark already. The "Fog of war" map layer (the eye) turns it off.
- **Watchtowers** see over the hedges and roofs: 85 m, and 115 m with a lookout up it (any idle soldier beside it
  climbs up). Placing one shows both rings; selecting one shows what it sees now.
- **Drones.** The Coalition's AR-2 Darter and the Rebels' AR-2 Tayran are cheap quadcopters from the Helipad (tier
  1) that circle where they're sent and show 70 m round them; the armed MQ-12 Falcon and KH-3A Fenghuang see 75 m.
  Selecting a drone or recon vehicle shows its sight ring.
- **Every aircraft spots.** A jet on a bomb run sees 70 m round it as it flies, a gun run 55 m, and an orbiting
  gunship or armed drone the 70 m circle its sensor turret is watching (and the ground beneath it). So an air strike
  also shows you what's around the target, and the minimap draws each aircraft with the ground it can see.
- **Recon flights** (support panel, from minute two): the Coalition's **A-149 Gryphon Recon Pass** (a Gripen with a
  recce pod, fast and high, 100 m either side of its track) and the Rebels' **Caesar BTT Spotter Flight** (a
  smuggler's light plane with a man and binoculars in the right seat: slow and low, 80 m either side, cheap), dragged
  out along a line; the strip they fly over stays lit for six seconds while the pictures are read. From minute four,
  **MQ-4A Greyhawk Overwatch** and **KH-3A Fenghuang Overwatch**: an unarmed drone circles a spot for most of a minute
  and shows 80-85 m round it. The enemy hears them coming.
- **What you've seen stays on the map.** Every enemy your side has seen, by any eye, is remembered where it was last
  seen for 90 seconds: a hollow red diamond with how long ago, on the battlefield and the minimap (the Intelligence
  layer). Buildings once seen stay on the map for good.
- **The AI** sends a recon flight over when the picture's thin: before an attack on ground it can't see, or when it
  has next to nothing of the enemy in sight. It builds a watchtower at each FOB and an early recon drone.

**Pathfinding and tactics** (
av.gd`, `hnav.gd`, `terrain.gd`, `squad.gd`)
- **Hierarchical A\* (HPA\*)** over both grids: the map is cut into 16 x 16 m clusters with entrances wherever
  neighbouring clusters connect (and wherever a road crosses), true costs inside each cluster precomputed. Long
  trips plan on the abstract graph, then refine cluster by cluster. When walls go up or are blown down only the
  touched clusters are rebuilt, and of those only the borders and links the change can reach.
- **Danger maps:** every second each side marks the clusters its spotted enemies cover (MG nests, bunkers and
  armour count for more). Ordinary moves skirt them, retreats keep well clear.
- **Cover map:** every 1 m cell knows its cover level (heavy, light, none, exposed) and which way it faces, updated
  as things are built, destroyed or cratered. Formation slots snap to the best cover nearby (Company of Heroes
  style) and soldiers look for craters, rubble and woods when there's no wall to hide behind.
- Stuck watchdogs: infantry re-plan if they stop making progress; vehicles back off, turn and re-plan.

**The map** (`mapgen.gd`, `landform.gd`, `towngen.gd`, `decor.gd`)
- Town asphalt combines fine photographed aggregate with larger cracks and repairs, continuous across street junctions. Traffic wears it by lane: polished wheel paths, oil down each lane's middle, grit and damp in the gutters, with drain grates along the kerbs and manhole covers in the lanes. Repairs are saw-cut patches edged with sealant and cracks are filled with tar. Zebra crossings and parking lines are paint on that same asphalt, worn through in places, and junctions and markings take the rain as the roads do. Sidewalk slabs are shaded along the photograph's own stretcher-bond joints; the square is laid in larger slabs of the same concrete. Road and pavement normal maps follow their actual slopes. Photographic roof, concrete, wood and bark materials are calibrated to their intended colours, so grey roofs remain grey and terracotta stays distinct at distance.
- Standard battlefields have seeded mountain belts, hills, valleys and rivers. Domain-warped ridged noise,
  jointed bedrock shelves, thermal weathering and seeded rainfall erosion shape the relief. Roads, bridges, starting bases and settlements
  occupy graded valley corridors; forests stay below the snow line and off steep faces.
- Skirmish valley floors roll a few metres over a few hundred (enough to fold a squad from view); roads ride over
  the swells while rivers, ponds, towns and bases keep level ground. Hills rise out of concave aprons, end in
  spurs and re-entrants where they meet a road or the shore, and are roughened before the rain so it cuts
  branching gullies rather than parallel rills. Steep bare rock carries crag relief (knobs, ledges and clefts
  up to 3.5 m) at the ground mesh's 0.5 m, which every peer derives from the same heights; slopes for movement
  and growth read the smooth geology, so routes are unchanged. Mission terrain keeps its authored relief exactly.
- Meadows follow what the soil holds: lush in hollows, along drainage lines and for a few tens of metres beside
  rivers and ponds, drying to thin straw on crests and sun-facing banks, with broad soil differences parting one
  pasture from the next. Lush ground takes its colour from a 90 m drone survey of grassland, dry ground from a
  2.5 m turf scan, each drawn twice at a turned angle so no repeat lines up; grass clumps grow thicker, taller
  and greener on the same damp ground. Hill shoulders pass through stony grass before bare rock, pale talus
  collects where the ground eases off below a crag, rock within ~150 m of the camera gains a finer pass of
  the same scan, and the mud that slows men down shows as dark rutted soil.
- Cloud shadows are a few hundred metres across and drift with the wind over the ground, grass and bushes.
- Steep rock faces carry rain-cut gullies from an offline erosion bake (an original texture layer). Its channels run
  down the texture's v axis, which the ground shader's side projections map to world up, so they run downhill and
  branch on any face: a few metres apart on near crags, some 15-30 m on the distant ranges.
- Distant massifs break their surveyed ridges into crags (ridged noise within the scenery height bounds) and
  shade steep faces with finer crags still, so their snow and bare rock lie in ribs and gullies.
- Distant woods grow in broad, warped stands from just above the water to the treeline, climbing higher and
  steeper in the gullies than on the spurs, and take the same distance haze as the ground beneath them.
- Distant scenery composes surveyed Mont Blanc, Matterhorn and Jungfrau ridge shapes into seeded fictional mountain groups and low passes, with floating-point heights and a finer indexed mesh at Medium/Far detail. Coastal scenery continues into an irregular shoreline and a coarse ocean surface beyond the detailed battlefield water. Boundary rivers extend into curved scenery pools with matching beds and banks; these extensions leave authoritative water shapes and navigation unchanged. Reusable cliff forms have uneven shoulders and irregular drainage cuts before erosion.
- Coastal scenery continues through a broad water channel to outer islands, with gentler foothills and a coarse ocean horizon beyond the terrain. The channel is entirely outside the playable boundary; inland maps keep their land backdrop. Shared shoreline masks, seed phase and beach/seabed profiles keep scenery ground and water continuous across the playable edge.
- Distant mountain groups lose contrast into sky-coloured haze while nearby ground retains its detail. Localized 3D cloud banks and thin trailing ridge mist sit beyond the playable boundary, with shaded bases, soft edges and lighting matched to the weather. A baked 64� R8 noise volume avoids runtime generation; scene-depth termination prevents clouds behind mountains showing through them. Stronger aerial perspective is masked to distant scenery, preserving foreground contrast. Mountain clouds have independent Off/Low/Medium/High/Ultra settings (8/12/20/32 samples), work in Compatibility, and stop drifting with reduced motion. They do not affect visibility rules.
- Rock beds catch light along their ledges instead of appearing only as painted colour bands.
- Broad cliff fractures and smaller joint patterns break up recognisable repeated rock tiles.
- Sheltered lower slopes collect pale loose stone while exposed walls retain darker bedrock.
- Snow shelves gain shallow wind grooves and granular highlights instead of perfectly smooth white surfaces.
- Sheltered runoff channels darken and develop a restrained sheen while exposed rock remains dry.
- Conifers have broken, asymmetric branch silhouettes that read as trees against rock and snow.
- Browser vertex lighting follows displaced mountain slopes and softly lights leaf cards without enabling global per-pixel lighting.
- Rain streaks surround the camera; soft splashes follow ground or water height and fade before becoming distant speckles. Procedural clouds remain smooth across their noise cells and use subdued moonlit shading at night, including the clouds reflected on the sea.
- Stones at the mountain foot have irregular broken faces instead of flattened round primitives.
- Coastal margins transition through exposed gravel and darker wet stone instead of a uniformly sandy strip.
- Moss and soil blend into exposed stone on slopes, with baked slab fractures, broken mineral beds, sheltered weathering, loose-stone pockets and snow on high sheltered ground. A cached downhill catchment mask places runoff stains and retained snow in connected gullies; it shares the existing surface textures and leaves gameplay elevations unchanged.
- Optional alpine haze takes on the sky colour and settles lightly into lower valleys.
- Narrow mineral stains run down exposed cliffs, interrupted by ledges and changes in rock type.
- Wind exposure and rock relief break up snow edges, with cooler compacted snow in sheltered pockets.
- Sheltered rock crevices receive stronger ambient occlusion while exposed rock stays open to sky light.
- World-space texture warping breaks up repeated slab patterns without adding material samples.
  Photograph-derived height, normals, crevice shading and roughness give each material distinct relief.
  Full-precision surface/geology textures keep elevated slopes and snow edges smooth; wall grime follows height above ground.
  Snow uses a two-metre powder scan with dirtier melt edges; wooded foothills use three-metre moss
  and leaf litter. Five material layers share two texture arrays with independent mipmaps, preserving
  the browser sampler budget. Detailed snow and litter follow the existing terrain-detail setting;
  height-based transitions let rock emerge through moss and snow. Reusable buttress, bowl and saddle
  forms shape standard foothills before erosion, with small conifer stands along suitable slopes.
  Generated skirmishes cap the base relief at 80 metres, opening the playable valley; tall massifs
  rise only in scenery beyond the water buffer. Snow stays above the low foothills, with matching
  terrain and forest masks and expanded culling bounds for the distant range.
  Warped mineral bands, dry grass patches and broken scree vary the surfaces at several scales. Mixed
  lowland trees give way to conifers and an irregular tree line; passable scrub and small stones
  cluster by altitude and slope below the snowy summits. Sheltered bowls retain greener soil and scrub;
  exposed ribs stay stony. Woodland stretches along contours, and tree roots can occupy steeper
  mountain ledges without relaxing the level-ground requirement for buildings.
  Baked sky visibility and distant sun shadows deepen the gullies, rebuilding when the lighting mood changes.
  Optional alpine haze adds atmospheric depth; cached terrain reflections exclude moving units and refresh with lighting.
  Standard-battle woods are denser and share spatial bark and foliage batches; changed trees recover their individual models.
  Campaign missions retain their previous geology and woodland layout to preserve authored routes and cover.
  Infantry and vehicles follow the ground, slow on slopes, and route around faces too steep to cross.
  Infantry, wheels and tracks have separate traversal limits (about 40, 26 and 33 degrees). Vehicle slopes
  use an eight-metre envelope so a flat centre cannot conceal a cliff under the hull. Routes favour roads;
  blocked rock/structure footprints retain clearance, and precomputed connectivity rejects separated regions.
  Ridges block shots and enemy detection. Helicopters anticipate rising ground and land relative to the surface.
- Construction requires a sufficiently level footprint. Trenches, shell holes, fires, selection and targeting
  use local ground height. The host sends the exact elevation samples to joiners and recordings retain them,
  including backward seeks; older recordings and dedicated flat test scenarios remain supported.
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
  man wading sinks to his knees. Actual depth is limited to 55 cm, including shore-cell edges;
  living men stay upright while wading. Movement checks the whole step, so old routes, dives, separation
  and knockback cannot carry a man through deep water. Spawns and disembarking find safe ground;
  a living man stranded by a removed crossing is repositioned to the nearest safe bank. Bridges and the harbour are key points the AI fights over. The water is laid
  out on the server as a few shapes and rasterized identically on every client. Erosion preserves the graded
  beach and both host and client carve the beds after the hills are in place.
- **How the water looks** (`water_view.gd`). The surface is drawn in tiles only where there's water. The sea
  runs two wave systems that cross: a swell from weather far out at sea, long and regular and coming in sets
  (its heading a little different on each map), and the wind's own shorter, steeper sea running offshore with
  the wind that carries the smoke. They're Gerstner waves, so the crests come up sharp and the troughs broad,
  and they build up over the first 35 m out from the beach. The weather sets the sea: glassy at dawn, dusk and
  golden hour, moderate by day, choppy under cloud, a storm sea in the rain with whitecaps breaking off the
  crests and streaks of foam laid down the wind. Breakers rise as they shoal, spill unevenly along the beach and
  surge up the sand, leaving it dark and wet. The bed shows through the water, bent by the ripples and dimmed
  with depth (red light dies first, so sand under the sea turns turquoise and the open sea goes deep blue; fresh
  water is peaty green-brown), with the light the ripples focus dancing on it in the shallows (laid on the bed along the sun's way
  down through the water; from High it is also thrown back up onto hulls, piles and banks, `caustics.gd`), and the sky and
  its clouds are reflected, more the flatter you look across it. The sun glitters off every ripple (a moon path
  at night, only a sheen under cloud), rain dimples the water with rings, the chop roughens in gusts, and foam
  gathers wherever the water meets a bank, a hull or a pile. Impacts throw up narrow sheets of spray that fall
  back into the spreading foam. Boats ride the same waves the player sees (the
  CPU samples the waves the shader draws). **Water quality** (Settings > Graphics) trades this against speed:
  Low draws no see-through water (copying the screen for it is the costly part, most of all in a browser) and
  fewer waves on a coarser grid; Medium is the full surface; High adds the light on the bed and the wind's
  streaks; Ultra a finer grid for the swell.
- On the 1 km map, country lanes branch off the main road to a village in each quarter (mirrored between the
  sides), and on the west the lanes run on over the river - each on its own bridge - to farming villages on
  the far bank: three bridges and two fords across the river in all.
- Country roads come in from both HQs and both edges of the map and join the main streets. Villages sit on the
  cross road either side of town and on the road between each HQ and the town; farmsteads (farmhouse and barn round a yard, hay bales, a fenced road frontage, an orchard) and
  hedged fields lie along the roads; abandoned cars on the verges, burnt-out armour off the road.
- **The town and every village have a name and a supply dump** (crated stores on a pallet, fuel drums and a
  flagpole): the town's on its square where the flagpole stood, a village's on the verge of its main street.
  Nobody holds them at the start. They are the supply worth fighting over: see *Towns* under Base building and
  supply. (Missions don't have them; the dumps use their own random numbers, so a seed's map is otherwise
  unchanged.)
- Houses are rendered and painted, bare brick or rough stone, and dressed as they're built: a darker plinth and a
  band under the eaves, sills and lintels in render, concrete or dressed stone (a keystone over stone windows),
  painted window frames with mullion and transom, panes whole, cracked to shards or shot out, louvred or boarded
  shutters on their hinges, door frames, steps, now and then a hood over the door, and double doors hanging open.
  Pitched roofs bear on the walls with a fascia, barge boards, gutters and downpipes, a round-tiled ridge and
  often a chimney with its pots; flat roofs have a coped parapet, scuppers with a hopper and downpipe, and the
  water tanks, air conditioners and dishes on them. Garden walls have saddleback stone copings, or brick-on-edge
  over a blue-brick base. Houses look lived in: drapes, blinds and nets in the windows, flowers in window boxes,
  lanterns by front doors, TV aerials on the roofs, and inside (seen when the roof hides for the men in there, or
  in a ruin) painted walls with skirting, radiators, pictures, mirrors, clocks, shelves of books and rugs, all
  hung flat or laid flat so nothing stands where a man does. At dusk and at night a lamp is on behind about a
  third of the windows, in the barracks and the research post, under the factory's north lights and in the door
  lanterns (brightest at night, a glimmer on a dark day). Weeds grow at the foot of walls and ivy up some of
  them (most often on old stone), and a ruin's floor carries its fallen roof: soot, charred rafters, broken
  tiles, plaster and glass. Round the houses are what the people in them keep: wheelie bins at a front corner,
  pots of flowers by the door, a bicycle against a side wall, and out the back a woodpile and chopping block, a
  table and chairs (under a parasol now and then) and the odd kennel, all set dressing that a blast or a truck
  knocks over. All of it, and the military buildings' weatherboard, sheeting, roller shutters, north
  lights, masts and guys, drums, crates and pallets, comes from shared building components (see
  [building-components.md](building-components.md)).
- Walls, hedges, trees, cars and crates are all real cover. Street furniture is set dressing generated on the
  server and built on each client, and it breaks: a blast or a vehicle driving through knocks lamps, utility poles
  (their wires come down with them), signs, benches, bins, fences and playground kit over, and the pieces fall and
  lie where they land. Broken street lights stay dark at night.
- Trees are broadleaves (a flared trunk forking into limbs that carry clumps of leaves, darker underneath),
  spruces (many overlapping tiers of boughs) and small orchard trees; foliage has ragged, leafy edges and throws
  dappled shadows. A tree that is shelled or run over falls away from what hit it and stays down.

**Terrain** (`terrain.gd`, `mapgen.gd`)
- Capturing towns updates only changed supply-road geometry; unchanged roads and their drawings are retained. Road terrain painting checks the strip beside each segment, preserving the same ground and cover cells.
- Country roads wind from HQ to HQ through the town, with a crossroad through the middle. On a road you're
  fast (vehicles +35%) but exposed. Mud slows everyone (vehicles badly) and leaves you exposed. Woods conceal you
  and give light cover. Vehicles strongly prefer roads.
- Deformable ground: every shell hole is dug into the ground itself (a fine ground mesh displaced by a height
  field kept identically on the server and every client): a bowl of churned earth with its rim thrown up
  around it, deeper for bigger rounds and deeper again when hit twice. Men lie in the holes, vehicles pitch
  and roll through them, grass is blown away, roads are holed, ragdolls and debris fall in. Craters give
  light cover and slow vehicles; wrecked buildings leave rubble. Cover and pathing update live.

**Fire** (`fires.gd`; the look in `vfx.gd`)
- Whatever is made of wood, cloth or fuel can catch alight: trees, hedges, crates, watchtowers, log dugouts,
  tents and plank huts, the timbers of a pitched roof (flat concrete roofs don't burn), parked cars. Stone,
  brick, concrete, earth, sandbags and steel don't. A blast may set things alight - the bigger the round and
  the closer, the likelier (a grenade rarely, a shell or a bomb often) - and a car that's been shot to pieces
  may go up. A vehicle that brews up burns where it died.
- A fire takes a few seconds to get hold, roars, then dies down as its fuel runs out. While it roars it
  throws heat and sparks at whatever will burn nearby, far more readily downwind than up, so a hedgerow or a
  wood can go up one tree after another. A heavy round on grass or in the woods' undergrowth can start a
  grass fire: a ring of low flames that creeps outward over blackened ground and may spread on downwind for
  a while before it burns itself out.
- What burns is charred and weakened, and in the end burns away: a hedge, a crate stack, a watchtower or a
  roof falls in as ash (a house is left a roofless shell), a tree is left a bare black snag, a car a
  burnt-out shell. Rain damps everything down: fires catch less, spread less and burn lower.
- Men caught too close get burnt and get back out of the heat ("Fire! Get back!"); nobody takes cover behind
  something that's burning or in a patch of burning grass, and a man whose cover catches fire moves. Routes
  go round fires (men well round, drivers if it's not far out of their way). A roof fire burns whoever's in
  the house under it. Your side is warned when one of its buildings catches fire, and engineers repairing it
  beat the flames out first.
- A fire that's well alight lays a pall of smoke across the ground downwind - a burning vehicle, a roof, a
  grass fire most of all - and nobody sees or aims through it, just as with a smoke screen.
- The look: tongues of flame that cool from yellow-white through orange to sooty red as they rise, sparks
  swirling up on the heat, a smoke column leaning off downwind (charcoal off fuel and rubber, brown-grey off
  wood, paler off green leaves) lit orange from below, and a flickering light that matters most at night.
  The fire chars what it burns - black creeping over it with embers glowing in the cracks; leaves wither,
  blacken and burn away - and you hear it crackle close to. Burnt-out things smoulder for a while after.

**Wounded, medics and prisoners** (`squad.gd`, `rules.gd`)
- Badly hit soldiers go down screaming for a medic and start bleeding out. If they're strong enough they crawl to cover and keep firing a pistol, including while being dragged.
- The squad lays covering fire and throws smoke. A rescuer drags the wounded man back by the shoulders while an escort walks backwards beside them firing. Then he gets patched up (medics are 2x faster). Each time he goes down he comes back weaker.
- Medic tent: two stretcher bearers recover wounded *and dead* soldiers. If one bearer is hit, the other drags the stretcher alone. After the tent, soldiers limp back to base and rejoin a squad.
- Rarely, a cut-off soldier whose squad is all down will throw away his rifle and surrender. The Rebels march prisoners
  into their tunnels and interrogate them. The Coalition questions prisoners on the march back. Either way the
  prisoner gives **live intel** generated from the real game state (FOB supply and defenders, MG nests,
  mines, trucks on the road, production, attack plans), shown in the message log with a map ping.

**Interface**
- A living topographic map lies behind everything outside a battle, drawn like a survey sheet of hill country
  seen from high up: fine contours on land that climbs gently across the sheet, valleys cut into V's, every fifth
  contour a heavier index contour lettered with its height (the line broken under the figure), spot heights on
  the summits, and a map grid with corner crosses, its numbers and a ruler round the margins. One shader draws the
  ground, which folds and drifts over minutes, its lines tinted in colours that turn round a wheel of brass,
  ember, rose, violet, blue and jade over three minutes. To letter it, `TopoSurvey` works the same ground out
  again on the CPU (the shader's noise uses an integer hash, so the two agree to the pixel) and surveys it every
  half second on a worker thread, carrying the figures along as the ground drifts. It stays a backdrop: awake, it
  is only a little brighter than the boot splash's map. The whole sheet leans a few pixels after the cursor, and
  a click sends a faint ring out across it. The view pans slowly to the right over the sheet (the ground, its
  grid and its figures drift left, and new ground is surveyed in from the right), and clouds drift over it,
  nearer than the ground: they slide faster, lean further after the cursor and cast soft shadows. On the
  title and the menu the map is at work: every 11 s a band of interference races across the screen in about
  a second (the map in it torn into rows shifted sideways, static, rows dropping out, a cyan and magenta
  fringe), and what it passes over turns up for nine seconds before fading: a contact (a hostile frame, a ring as it's found, its grid square bracketed and its
  six-figure grid reference), a friendly unit moving off along a dashed track, or an axis of advance pencilled
  in to a named objective. It's all a pure function of the map's clock, so it repeats exactly in screenshots,
  and none of it shows over a battle or on the loading screen. Every copy shares one clock, cursor and survey,
  so the title, the menu and the loading screen hand over to each other without a seam.
- **Themes** (Settings > Interface), each named for what a soldier looks at the war through: Field Brass (the
  original), Night Vision (phosphor greens), Thermal (an ironbow of violet, red, orange and white-hot), Arctic
  (ice and intelligence blues) and Dusk (violet and rose). A theme sets the accent, the text, the panels and the
  six colours the map's contours turn through; the colours that mean something (good, bad, warning, intel) stay
  the same in all of them. It changes live: the interface recolours at once and the map's colours flow into the
  new ones over a second or so.
- **Signal** ([UI.md](UI.md)): the interface is a battle management display laid onto the scene. The HUD sits
  on the battlefield over scrims that darken toward the screen's edges, with no boxes: 1 px rules under rows and
  corner ticks where a region needs marking, everything square. Names and labels are condensed capitals, every
  figure and code is mono (`SUP 2115 +230/M`, `PINNED · TO SPT D4`, `T+04:31`, `RDY`), and prose is kept for
  sentences. One accent colour marks what's selected, active or primary. Short choices in the settings are rows
  of segments, amounts are counted bars, keys are drawn as key boxes. Things cut, type on, count or flicker
  rather than glide or glow, and Settings > Interface > Reduce motion makes all of it cut.
- In a battle, the map comes back see-through behind the Esc menu, the help, the settings and the end of the
  battle (where a wave from the middle of the screen wakes it), with the battlefield showing through it.
- Boot splash and title: the splash is the title's first frame (the map asleep under the emblem and the name).
  A wave runs out of the emblem's dot, wakes the map and lights the letters as it passes; then the title rises
  away and the menu glides in on the same map. A click or a key skips it. Only the scripts the title and the
  menu need compile before the splash gives way: the rest of the game (`World` and everything it reaches)
  compiles on a worker thread while the title plays (`scripts/game_scripts.gd`), and a battle or the Field
  Manual wanted before it's done waits for it. The Field Manual and the Settings are built the first time
  they're opened.
- Main menu: grouped entries in capitals, each with a square marker that lights while its panel is open and a
  line saying what it does beside the one under the cursor, and a New Operation panel to pick a side (Coalition,
  Rebels or Observe, with each side's doctrine as a line of codes) and the time of day as one row of segments.
- Loading screen before each battle: the operation's name, then mission, side, area and conditions as label and
  code rows, a field note under a rule and the build's stages as a row of counted steps, over the map with a survey beam sweeping across it and the view closing in on the ground.
  It holds while the first frames compile behind it, then dives into the map as the battlefield fades up.
- **Shared allied command:** every player can select and order any squad, vehicle or individual soldier on
  their side, regardless of who recruited it. Click, drag-select, control groups and the order-of-battle list
  all use the same allied selection. Other commanders' current selections still show in their colours;
  these are coordination cues, not ownership locks. Enemy and neutral troops cannot be commanded, and
  observers can inspect but cannot issue orders. A human order takes an AI-controlled unit out of the
  strategic AI's allocation so it does not overwrite the player's orders. Orders between human allies leave
  recruitment attribution intact. Construction can assign an allied engineer, and tunnel orders move allied
  passengers, without requiring the issuing commander to own them. Supply convoys and supply helicopters
  continue their automatic routes rather than taking troop orders.
- **Order of battle** (O): every unit down the left, grouped into infantry, support teams and vehicles, each
  with its symbol, callsign, a pip per man, what it has been told to do and where an attack has got to ("Base of
  fire on D3", "Assaulting D3"), and alerts for contact, pinned, casualties and low ammunition. Click to select
  and look at it, Shift+click to add, double-click to zoom in. Observers see both sides.
- **Map layers** (the column beside the minimap): unit symbols at any zoom, orders and attack plans for all your
  units, intelligence (where the enemy was last seen and how long ago), the fog of war, weapon ranges of the
  selection, soldier labels. **Tactical map** (Tab): the battlefield dims under the symbols, every order, plan and contact, and the
  A-H / 1-8 grid on the ground.
- **Battle statistics and the after-action report** (`battle_stats.gd`, `stats_panel.gd`). The host keeps a record of
  the battle and credits everything to the commander whose unit did it (a player, or a side's AI): the man who last
  hurt a soldier gets the kill even if he bleeds out later, fire support and mines count for whoever called or laid
  them, and the men killed in a burning vehicle for whoever knocked it out. Hold **Tab** (or Esc > Battle
  Statistics) for your side's figures so far; the enemy's are classified until the end, when the after-action
  report shows everything, in four tabs:
  - **Summary**: the two sides head to head (killed, wounded, lost, captured, vehicles, buildings, the supply value
    destroyed, accuracy, prisoners, FOBs and towns taken, wounded saved, supply delivered and spent, units fielded, fire
    missions), honours (most valuable, most effective, marksman, tank hunter...) and the soldiers who stood out.
  - **Commanders**: every player and AI with a **rating** out of 100 - 60% the exchange (supply value destroyed
    against lost, on a log scale: 4:1 is as good as it gets), 20% marksmanship and 20% their share of their side's
    fight - and a score, kills, losses, vehicles, accuracy, supply spent and units fielded. Click one for the
    breakdown: how the rating was made, and everything they did in combat, lost and spent.
  - **Units**: every squad and vehicle, with its commander, kills, losses, strength, time in action and fate.
  - **Timeline**: men in the field, vehicles, enemy killed and supply in hand over the battle, with FOBs built,
    taken and wrecked, vehicles lost and fire missions marked along the bottom; hover for the figures at any moment.
- **How it moves** (`ui_fx.gd`, `end_banner.gd`). The end of a battle is a moment: the battlefield drains of colour
  and goes soft (red for a defeat), the camera eases back, a band opens across the screen and VICTORY or DEFEAT
  slams into it with a hit and a glint, your rating fills its bar and its word lands, then the report rises into
  place (click to skip). Every tab comes in row by row on cut-cornered glass: numbers count up with a tick, the
  head-to-head bars open out from the middle, rating dials and bars fill, honours land one at a time as medals
  with a sweep of light, and the timeline's lines draw themselves across. The sounds are synthesised like the
  rest: a whoosh, the ticks, the impact, the medal chime. The menu's account card, Service Record and sign-in
  share the look.
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
  On a Mac's trackpad (which scrolls in gestures, not wheel clicks) two fingers grab the map at the middle of the
  screen, a pinch zooms toward the fingers, and Option + two fingers turn and tilt; a setting, shown only on a
  Mac, makes two fingers zoom instead, for a Magic Mouse.
  Jumps (the last alert, a base, a group, a unit in the order of battle, a saved view) glide rather than cut.
  Backspace turns back to the heading the battle started on, Ctrl+F follows the selection until you pan away,
  and Ctrl+F5..F8 save views that F5..F8 glide back to. Select one vehicle, building or individual soldier and press F10 to cycle its views. Each has behind and aerial views. Vehicle models can also offer tracks or wheels, barrel, roof gun and engine deck. Rotorcraft offer a cabin-side view. Sling-capable helicopters offer a wide view of the lift and a cargo-door view looking down at the load. The stern-quarter view looks past a boat's cabin with the horizon level as the hull rolls. On the patrol ship, Bridge roof looks down past the port rail as boats come alongside. Boats also offer bow and waterline views. On a RHIB the starboard camera looks forward past the console. The Helm view rides behind the driver’s right shoulder as he sits at the controls. Escape returns to command with the object still selected.
- **The minimap** (`hud_minimap.gd`): the ground, water, roads (main roads light with a dark edge, supply
  tracks thinner), woods and every house's footprint (light while its roof stands, dark once it's a ruin) are
  baked into a texture. Over it go the fog of war (darker where your side can't see), every man you can see as a
  dot (allies brightest, the selection white), vehicles by their map symbols, where the enemy was last seen, aircraft
  overhead (yours with the ground they can see), bases, objectives and alerts, each town as a flag in its holder's
  colour inside the ring of ground that takes it (with how far a capture has got round the ring), and an orange
  ring pulsing wherever men are firing. The camera's view is a lit wedge with a line back to where the camera stands, and a compass needle
  shows where north lies in the view (click it to square up). Hovering gives the grid square under the cursor.
  Three sizes, and it can turn with the camera so the way you face is always up (Settings > Interface).
  Building destruction is painted across several frames, keeping the previous map visible while it updates;
  moving units, selection and minimap controls continue to update normally. Its map, fighting,
  unit and co-op layers take turns refreshing across four frames, while the camera wedge and pointer
  refresh each frame. Rotating or resizing refreshes all layers together to keep their positions aligned.
  In co-op each other commander's view is a wedge in their colour with their initial at their camera, with
  their cursor, rings round what they've selected, their pings and sketches.
- **Interface scale** (Settings > Interface): the interface grows with the window, so at 100% it takes the same
  share of the screen at any resolution (1.35x at 1080p, 1.8x at 1440p, 2.7x at 4K), and the slider scales it
  from there up to the largest that still fits the window (2x in a 1080p window, 2.7x at 1440p). Text is
  rasterised at the size it's drawn, and the map symbols are re-drawn at a higher resolution on a big scale, so
  both stay sharp. On a narrow screen the command card drops to three columns, the minimap shrinks to leave room
  for the support buttons, notifications stop above the command card, the observer bar moves to the bottom right,
  the squad card's attack stepper goes under its orders, and the settings, controls and Field Manual fit the
  screen and scroll. The windowed size picked in Settings > Display is the one the game opens at (maximised if
  it's too big for the screen), so a bigger window means a bigger interface from the start. The menus (laid out for a full
  1600 x 900) only grow until they fill the window. The scale applies when the slider is let go, so the panel
  doesn't move under the mouse while it's being dragged.

**Vehicles** (`vehicle.gd`, `vehicle_brain.gd`, `vehicle_roster.gd`, `drone.gd`, `projectile.gd`)
- **The core vehicles rebuilt** (`vehicles/vm_core.gd`): the M1A2 SEP Abrams, a worn T-55A, Hilux technicals (DShK
  or ZU-23-2 in the bed), the M1151 Humvee, the M2A3 Bradley, the BTR-80, the AH-64D Apache and the UH-60 Black
  Hawk - sloped armour, skirts, sights, stowage, rust and dents, each in its side's camouflage.
- **Sling loads.** Select a lift helicopter and right-click one of your vehicles. A ring marks the load on the ground. The helicopter flies over, hovers, hooks
  it on four strops and a cable, and climbs out with it swinging underneath - then flies it wherever you send
  it (slower with a load on), lowers it until it touches and lets go. The CH-49 Mohawk and the Rebels' Mi-290
  Taru (Lift) carry anything up to an APC (Humvees, technicals, BTRs, AA trucks); the Ghost Hawk and the Orca
  light vehicles only; nothing lifts a tank. A helicopter shot down drops its load - from height, it's
  wrecked. The Cargo door camera follows the suspended hull through turns and looks straight back down
  its original sightline when the helicopter releases the vehicle. The AI uses its lift helicopters to ferry vehicles sitting idle far behind the lines up to its front.
- **Boats and ships** (built at the **Boat Dock**, which goes on the shore of the sea or the river facing open
  water, on your own half of the map). Coalition: the RHIB (six men, fast, unarmed), the Speedboat Minigun
  (armoured riverine craft, 40 mm GMG, a squad aboard) and the **Patrol Ship** (`vehicles/vm_ships.gd`, a Mk VI
  with a stabilised 25 mm). Rebels: an armed motorboat (PKM, four men), the Speedboat HMG and the **Gun
  Trawler** (a converted steel fishing boat with a ZU-23-2 on the foredeck). Boats find their way on their own
  grid of open water (shallows only to nose in to a beach; the low bridge stops them), sit in the water at
  their draft, pitch and roll over the swell, lift their bows as they get on the plane, heel into turns and
  throw spray off the bow going hard. Each leaves a wake on the water: white water churned up astern in streaks
  that spread and fade into a smooth streak, and the bow wave running out in a V at the Kelvin angle (a wake
  hides with a boat hidden in the fog of war).
  Each boat has a tuned cruise cap, thrust, engine/helm response and turning profile;
  matching riverine hulls share their handling (see [the naval audit](VEHICLE_HANDLING.md#boat-movement-audit)).
  **A boat handles like a boat, not a car** (`Vehicle._hull_tick`, the coxswain in `_con`): nothing grips the
  road, so her hull slides through the water - in a hard turn she skids, bow inside the circle she's making
  and stern swinging out, and the skid costs her way. There are no brakes: the water's drag takes her way off,
  hard when she's fast and hardly at all once she's slow, and to stop she goes astern (an RHIB needs some 40 m
  from a fast approach, with larger hulls carrying farther). Her rudder or jets turn her only with water going past them -
  her own way, or the wash of the engines going ahead, which is how she turns from lying stopped - and going
  astern she hardly steers. Engines, helm and hull answer after a moment, a big hull's after a long one, so
  the coxswain starts a turn early, meets her with opposite helm as she comes round, and slows for the bends
  he sees coming as far off as she'd need to; at speed she can't be turned as tight as she can going slow. A
  river carries a boat down with it (it runs south, fastest in mid-stream), and he steers the course she's
  really making, current and skid and all. The Gun Trawler, a deep displacement hull, is the slowest of all to
  answer, needs a wide turn, and heels out of a turn where the planing boats bank into it.
  On an attack a boat fights at a steady speed rather than stop dead for the shot, as a tank would; she lies
  to only to fight it out with an enemy abaft her beam, rather than steam away from it.
  A big hull needs a lot of water to turn round in (the patrol ship's turning circle is over 50 m across):
  coming about for somewhere astern, she goes round towards her course, or the other way, out to sea, when
  the shore's in the way; she backs into a spot not far behind rather than swing out in a loop for it (an
  RHIB, which spins round in her own length, comes about and runs in bow first); and once she's round she
  picks her route up further on instead of going back for its first points. A boat that runs onto the bank
  goes astern off it, swinging her bow round towards her course, and tries again (sent close in by the shore,
  she settles as near as she can get); where her route rounds a point of land she doesn't cut the corner
  over it.
  Men board a boat lying off a beach or bank by wading out to it, and go ashore over the side wherever it stops
  by land at the end of a trip. A boat that's sunk blows up and
  founders: she floods, lists over and goes down by the head or the stern, burning till the water closes over
  the fire, foam boiling up along her as the air comes out, and leaves a rainbowed oil slick with wreckage
  drifting in it; whoever's aboard swims for the nearest bank. Shells landing in the water throw up a column of
  spray and leave a ring of foam spreading on the surface instead of a crater; bullets kick up white spouts.
- **Driving.** A driver steers for a point some way down the road (pure pursuit: further ahead the faster he
  goes), slows for the bends he can see coming - as fast as the tyres or tracks hold the curve - and brakes to
  stop where he's sent. Wheeled vehicles steer like cars: a real turning circle from their wheelbase and
  steering lock, no turning on the spot, so a truck needs room to turn round. Tracked vehicles skid-steer:
  they pivot where they stand for a sharp turn but turn wider the faster they go. Weight sets how hard they
  accelerate and brake. A spot close behind is backed into rather than reached by a loop; for one further
  back the driver comes round on full lock (boats have handling of their own: see above); a vehicle keeps its
  distance behind one going its way, drives round one standing in the road and passes oncoming traffic on
  the right; supply trucks keep to the right-hand side of the road. Hung up on something, it backs off, turns
  and plans again. (Trucks are slower on the road than they were, so each load carries more.)
- **Vehicle gun handling.** Old tanks, modern MBTs, IFVs, AA mounts, artillery and aircraft
  have distinct traverse, acceleration and braking profiles ([rates and complete roster audit](VEHICLE_HANDLING.md)).
  Mounted machine guns must traverse onto the bearing before firing. Vehicle and gunship shots leave the
  actual model barrels, including separately positioned gunship guns. Tank drivers build into turns. Turrets accelerate into a traverse and brake onto
  the target, holding their world bearing as the hull turns underneath. The gunner holds a steady aim
  for 0.3 seconds before firing, and reacquires when switching targets. Without a target, the turret
  returns forward by the shortest arc.
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
    Tempest transport / ammo / medical / repair, Mi-48 Kajman, PO-30 Orca (and armed), Mi-290 Taru, AR-2 Tayran,
    KH-3A Fenghuang.
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
- **Rotorcraft flight.** Attack, transport and supply helicopters share a flight model (`helicopter_flight.gd`)
  that flies the way a real one does: the pilot tilts the rotor and the tilt is what accelerates her, so the nose
  dips before she gathers speed and comes up into a flare before she slows, and the cyclic only moves so fast (a
  big lifter answers slowly, a scout snaps round). Parasite drag keeps the nose a few degrees down in cruise, more
  with a load on the cable. In forward flight the nose stays on the flight path and turns are banked arcs, slower
  and tighter for a sharp one; a reversal at speed is flown as a decelerating turn. Near the hover she can pedal
  turn and side-step, but only at a walking pace sideways or backwards. Climbs are best with forward speed, and a
  slow descent is kept under about 2 m/s, out of the rotor's own downwash. Each flight follows a profile: the rotor
  winds up before lift-off, she lifts into a hover check a couple of metres up, then noses over and climbs away as
  speed builds (never racing along just over the ground); she cruises 16 m above the highest ground ahead, then
  comes down a 12-degree glide path, slowing all the way, into a low hover over the spot and sets down gently. No
  big flare close to the ground, where the tail would strike. Sling loads hang as a pendulum: they lag on
  acceleration, swing forward in the flare and trail in the airflow; the load is lowered from a hover and let go
  once it has stopped swinging. Gunships fly to their firing position nose first, then hold the nose on the target
  and side-step round it. Stop holds a transport in the air without dropping its load; a new move resumes the
  flight, even during a landing. On the ground the rotor stays at flight speed while she's busy and idles down when
  she's been sitting with nothing to do. The host simulates flight and sends pitch, bank and the rotor's state
  with its snapshots; clients draw the rest: a hovering helicopter's slight nose-up, one-side-low hang and gentle
  wander, the rotor's beat following its speed and slapping louder under load, and the downwash throwing a ring
  of dust (spray over water) when she's low. Four shaded straps follow the suspended vehicle. Its wheels and tracks stop spinning in the air.
  Drones and ground vehicles keep their own movement.
- **Shot down.** A helicopter destroyed in the air falls rather than vanishing. With the tail rotor or controls
  gone (or too low to settle) she winds up into a spin against the rotor's torque and corkscrews in, still carrying
  her speed; with only the engines gone she autorotates, gliding steeply nose-down and flaring into a heavy landing.
  Where she hits, her fuel goes up (blast damage, a crater and fire, credited to whoever shot her down), how hard
  she hit decides who aboard walks away, and the burnt-out helicopter lies there, on her side after a spin-in. Over
  deep water she ditches and sinks. The kill, its stats and the messages count at the moment she's hit.
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
  it's destroyed with them inside, the survivors scramble out of the wreck, most of them hurt. The command card
  can drop only some of them (`Vehicle.dismount(n, sid)`): half the men aboard (the last in, so a squad's leader
  stays with its main body), or one squad of several. The rest stay aboard (`keep_aboard`) until dismounted too,
  or until the vehicle is moved on and stops again; badly hit, everyone bails out regardless.
- Armour classes: soft-skinned pickups and trucks bleed from rifle fire; light armour (Humvee, helicopters) shrugs
  it off and needs .50 cals, cannons, AA or rockets; tanks only fear anti-tank weapons.
- **Off-map support**, from minute five (recon flights sooner), each on its own cooldown:
  - Coalition: **F/A-181 Black Wasp II strike** (a stick of four high-drag bombs across the spot), **A-10C
    Thunderbolt II** and **A-164 Wipeout gun runs** (in low and visible, nose down, walking a burst of 30 mm
    through the target: the impacts land first, the BRRRT arrives after), **AC-130U Spooky** and the cheaper
    **V-44X Blackfish** gunships (a left-hand orbit, port wing down, for 25 seconds, hunting anything in the
    circle with the side-firing 105, 40 and 25/20 mm), **A-143 Buzzard** strafe, **A-149 Gryphon** precision strike,
    **MQ-4A Greyhawk** drone (circles firing guided missiles), **UCAV Sentinel** (two bombs, no warning to the
    enemy), **155 mm artillery** (eight heavy shells, visible arcs and a tearing whistle).
  - Rebels: **To-199 Neophron** strafe, **To-201 Shikra** bomb run, **Y-32 Xi'an** gunship orbit, **rocket barrage**
    (sixteen rockets) and **mortar barrage** (twelve rounds).
  - Recon: **A-149 Gryphon Recon Pass**, **MQ-4A Greyhawk Overwatch** (Coalition), **Caesar BTT Spotter Flight**,
    **KH-3A Fenghuang Overwatch** (Rebels): see "Reconnaissance and the fog of war". Every aircraft on a run spots
    for its side as it flies.
  - Mortar and artillery shells are drawn a little larger than life with a smoke trail, so you can follow the arcs.
  - The AI calls them on dense groups of spotted enemies, never danger-close to its own troops, running gun runs
    in from its own lines.

**Base building and supply** (`structure.gd`, `rules.gd`)
- Placed buildings are just construction sites. Soldiers walk over and build them by hand, even mid-fight (engineers are 2x faster).
- Each finished FOB raises the unit cap by 20, resupplies nearby soldiers, and lays its own road back toward your HQ.
  HQ sends each FOB a supply truck a minute down those roads (a Rebel lorry carries a little more), however near
  HQ it stands, so no map hands one side a richer start; a long road can only make a truck late for the next. A
  road that couldn't be laid when the battle began is surveyed again. If you ambush the trucks or block the road
  (tank traps, mines), every FOB past that point stops getting supply.
- **Comeback pressure** (`rules.gd` `hq_load`, `_fire_the_dump`, `_reserves`): HQ sends bigger loads to a side
  holding fewer towns and villages than the enemy, a quarter more for each one it is behind by (up to three), and
  says so on the radio; the side ahead loses nothing. A FOB or town dump that falls is half burnt by its holders,
  so the taker gets half its stock. And HQ sends a reserve squad now and then to a side down to its last few men
  or outnumbered three to one.
- **Towns** (`structure.gd` `_town_tick`, `rules.gd`): the town in the middle and every village are supply. Whoever
  holds one draws on it - food, fuel, lorries, labour - into its dump: 24 supply a minute from a village, 60 from
  the town, less as its houses are knocked down (a place shelled to ruins gives about a third), up to what the dump
  holds. Once there's a load, the town's own lorry drives it to the holder's nearest FOB along a supply road of its
  own (drawn on the map like the others, and just as easy to ambush or block); the truck's loss costs its load.
  - To take one, get men inside its ring (30 m round a village's middle, 42 m round the town's crossroads) with none
    of the other side's there: a squad takes a village in about half a minute, the town in nearer a minute (more
    men, faster). Both sides there and nobody gains; the holder's men push it back; half of what's in the dump changes
    hands with it (the holders burn the rest). The holder is warned as soon as the enemy starts.
  - Holding a town also lets you put a FOB up near it (not just near your own bases), your men round the dump
    refill their ammunition from it, and the townsfolk tell you who's about (it sees like a building).
  - Right-click a town that isn't yours with squads selected to send them to take it; select a dump to see who
    holds it, what it gives and how much of it stands, its stock and where its trucks run.
- **Supply on the HUD**: the top bar shows your supply and what's coming in a minute (truck and helicopter loads
  over the last two minutes) and how many towns you hold; beside the FOB lines, a line of its own (stock, rate,
  where its trucks go) for each town being taken or whose trucks aren't getting through, and the quiet ones in
  one line once there are more than a couple. The order of battle moves down to make room.
- Buildings: FOB, barracks, factory, medic tent, research post, helipad (supply helicopters fly over cut
  roads), sandbags, HESCO walls and T-walls (Coalition), barricades (Rebels), barbed wire, minefields, tank traps,
  camouflage nets, ammo caches, watchtowers (see 85 m, 115 m with a lookout up; shoot over walls), and Rebel
  tunnel entrances (move squads through the network or bring them back out with "Exit here").

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
  - **Excavation:** builders reserve separate reachable work stations, dig with their shovels, then move
    down into the excavation. Spare workers wait for space. Eight depth stages provide light cover before
    full protection; interrupted work stays put. A 6 m bay takes 60 work-seconds (engineers work faster),
    scaled by length, with compacted roadbeds taking 50% longer. Repair orders clear collapsed earth.
  - **Shape and materials:** floors and individual duckboard slats follow local terrain. Open ends ramp
    to the surface; connected ends stay continuous. Earth fire steps run along the walls, leaving the
    centre route clear. Soil layers, roots, uneven spoil, damp ground and boot marks break up the surfaces.
  - **Rear bays:** occasional long sections include a recessed supply shelf or a timber-roofed resting
    bay, with kit kept off the through route. The timber roof is physical cover, not a bombproof bunker.
    Moving soldiers yield and sidestep inside narrow passages; crossing a high lip takes a slower climb.
  - **Damage:** a trench remains excavated after bombardment. Damage affects one section's depth,
    exposes earth and broken timber, removes its fitted kit and slows passage until repaired. Neighbouring
    sections remain usable. Cover, ground contact and excavation stages agree on host and clients.
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
- **Walls and obstacles** (`works_models.gd` builds them all, from the real thing):
  - *Sandbags*: filled bags laid the way they are in the field, stretcher courses along the wall and header
    courses across a thick one, joints broken, the face battered back, the tied neck folded under; tan and coyote
    polypropylene with some olive for the Coalition, hessian and white feed sacks for the Rebels.
  - *HESCO wall* (Coalition): a line of earth-filled cells, chest high and a metre thick - geotextile behind the
    welded mesh, coil joints at the corners, weeds in the fill. Stand and fire over it; it stops even a .50 cal,
    and vehicles.
  - *Barricade* (Rebels): oil drums, tyre stacks, a sheet of roofing against a heap of rubble, a torn-off lump of
    concrete, pallets and sacks, chest high. Stand and fire over it. Tanks shove it aside, and the tyres burn black.
  - *T-walls* (Coalition): precast slabs on wide feet with lifting loops, too tall to see over; men fight round the
    ends. Light vehicles can't push through.
  - *Barbed wire*: triple-strand concertina - two coils of razor wire side by side and one on top - wired to steel
    pickets (the Rebels' to cut stakes). Infantry crawl through it.
  - *Tank traps*: Czech hedgehogs, three beams at right angles standing on three ends; steel angle bolted through
    gussets for the Coalition, welded lengths of old rail for the Rebels.
  - *Minefields*: anti-tank and anti-personnel mines dug in under loosened earth inside a cordon of pickets and
    tape hung with red triangles - all of which only their own side ever sees.
- **Camouflage net**: pitched over a gun pit, a mortar, an AT post or a parked vehicle (it goes up over anything,
  and anything can go in under one). Whatever is under it is spotted at half the range - by men, by vehicles and
  from the air - but it stops nothing, and it burns. The AI nets its mortar pits, AT posts and .50 cals.
- **Ammo cache**: forward stores on pallets under a fly sheet, a red flag on a stake. Every man of its side within
  7 m tops up his magazines, grenades, rockets and mortar bombs from it until it runs dry; a man who's out of
  ammunition falls back to the nearest cache before the FOB. Hit hard enough to wreck it (or burnt), it cooks off:
  a blast, then rounds and grenades going off round it for a few seconds. The AI puts one ahead of its front FOB.
- Soldiers in good cover are much harder to pin down than soldiers in the open, and only their head and shoulders are
  exposed when they pop up to fire. A fortified line beats a frontal assault by similar numbers.
- Everything can be shot up and repaired. Any FOB can be captured by whoever walks in and holds it. Lose your last FOB and you lose, but a side's last FOB is a last stand and takes four times as long to capture, and HQ sends a free reserve squad every 75 s to a side that is down to its last few soldiers.
- Fog of war, drawn on the ground and the minimap, with intel pings and last-known enemy positions.

**Look and feel** (`atmosphere.gd`, `cinematic_fx.gd`, `physical_sky.gd`, `cloud_shadow.gd`, `mats.gd`, `vehicle_models.gd`, `vfx.gd`, `gunfx.gd`, `grass.gd`, `wildlife.gd`, `ui/`)
- Eight lighting moods (midday, golden hour, dawn, dusk, overcast, hazy, **night**, **rain & thunder**) with a
  procedural sky, AgX tonemapping, cloud shadows drifting over the ground, volumetric haze and a subtle film look.
  At night the sky fills with stars and illumination flares drift down on parachutes over the fighting, throwing
  moving shadows. In the rain, streaks fall around the camera, splashes hit the ground, puddles reflect the sky and
  lightning flashes are followed by thunder.
- **Cloud shadows fall on everything** (`cloud_shadow.gd`), not just the ground: soldiers, vehicles, buildings,
  trees, grass, roads and trenches darken in the same drifting shade, so a tank parked in it isn't lit up for the
  enemy to spot from above. Every surface reads one pattern at its own position (global shader uniforms the
  atmosphere moves downwind, with the smoke), and the shade takes direct sunlight only, never skylight: the shared
  surface, foliage and grass shaders light themselves with Godot's own light model and let the sun through the
  cloud, and in the browser, which lights per vertex, the albedo dims and AO hands the skylight back. It's a
  graphics setting (Cloud shadows on everything; on from High, and in Cinematic; off, the grass and bushes fold the
  shade into their colour instead), works in both renderers and is drawn only on each screen, never simulated.
  Vehicle windows and the opt-in mocap soldiers still take full sun.
- **Layered air and weather across the map** (`air_layers.gd`, `weather_grid.gd`): the air between the camera and the
  far side of the field lies in layers. Mist hugs the ground, pooled in the hollows and along the water and torn into
  wisps by the wind (thickest at dawn, rising off wet ground as it dries after rain); a haze lies aloft, lit by the sun,
  so a cloud's shadow falls through it as a shaft. Over that, a coarse weather grid sized from the map (32 cells
  across a 1 km map, 64 on the bigger ones) holds the mist, rain, dust and smoke over each patch of ground: rain
  comes over in heavier and lighter bands, shells on dry ground and vehicles on dry tracks raise dust, and barrages,
  burning buildings and smoke screens leave a pall. The grid drifts with the wind as a whole (a sub-cell offset the
  shader reads, the grid shifting a cell downwind once it reaches one), mist and rain settle toward what the weather
  makes of each cell, and dust and smoke thin away (half-lives of about 20 s and 55 s); it's swept a few rows a frame
  and uploaded once a sweep. With volumetric fog it's one fog volume over the map with its own fog shader (ground
  height from the terrain tiles, the grid, a drifting noise, the cloud pattern); without it, and in the browser, the
  plain fog takes the air at the camera's focus and a height fog lays the mist in the low ground below it. All of it
  thins as the camera pulls back, so it never veils the battle you're looking at. It's looks only: who can see whom
  is the host's own smoke (`Combat.smoke_blocks`), so the grid runs on every peer from what it already has (the
  mood, the rain's wetness, replicated fires, smoke rounds and vehicles, the blasts' effect events), sends nothing
  and never touches the battle's seed.
- **Cinematic lighting** (`atmosphere.gd`, `cinematic_fx.gd`, `physical_sky.gd`), each part its own setting and all
  of it on the **Cinematic** preset (Ultra plus everything below; for a fast graphics card, screenshots and replays).
  None of it reaches the simulation, so it can't change a battle or its seed.
  - **Adaptive shadows** (on from Medium up): the sun's shadow cascades are fitted every frame to the ground the
    camera can see, instead of always reaching 800 m, so close in every cascade is several times as fine. The fit is
    worked out from the view's corner rays (the idea of sample distribution shadow maps, Lauritzen, Salvi and Lefohn,
    I3D 2011) and split by the practical scheme of parallel-split shadow maps (Zhang et al. 2006); the reach moves in
    tenths, so a still or panning camera keeps its fit and only zooming re-fits.
  - **Shadows from fire and flares**: explosions, muzzle flashes, burning wrecks, illumination flares and street lamps
    are in the `fx_light` group, and the two or six of them that light the most near the camera's focus are lent soft
    (PCSS) cube-map shadows, re-picked ten times a second.
  - **Physical sky** (golden hour, dawn, dusk, haze): each view ray is marched through a spherical atmosphere with
    Rayleigh, Mie (Cornette-Shanks) and ozone, using Hillaire's coefficients ("A Scalable and Production Ready Sky and
    Atmosphere Rendering Technique", EGSR 2020, after Bruneton and Neyret 2008), with the sunlight reaching each sample
    marched too, so a low sun reddens and the earth's shadow rises at dusk; multiple scattering is an isotropic share of
    that light. Its brightness matches the painted sky's average over the dome, so exposure and ambient stay where each
    mood had them, and the copy the battlefield is lit and reflects by is nearly half way to a warm grey so shade
    turns cool without going cyan. The sun's direction is passed in, not read from the light: a reflection probe draws
    the sky with no light. Midday keeps its photographed sky; overcast, rain and night their painted ones.
  - **Camera and lens** (Settings > Lighting & Look): compute passes run on the HDR scene just before it is
    tonemapped (a `CompositorEffect`, Forward+ only), at a quarter of the resolution except the final composite.
    Sun shafts are a radial blur of the open sky near the sun (Mitchell, GPU Gems 3, 2007). Lens flare and glare:
    a Karis-weighted bright pass (Jimenez, SIGGRAPH 2014) feeds ghosts and a halo mirrored through the lens centre
    (Hullin et al., SIGGRAPH 2011, as approximated in screen space by Chapman), anamorphic streaks from the hottest
    cores only (Kawase's streak filter, GDC 2003), and the glare round each light lighting dust and grease on the
    front glass. Local exposure pulls the scene's large-scale brightness towards its average and keeps the detail on
    top (Durand and Dorsey, SIGGRAPH 2002), with the base blurred cross-bilaterally at quarter resolution and brought
    back edge-aware (joint bilateral upsampling, Kopf et al., SIGGRAPH 2007). Eye adaptation meters the frame
    (centre-weighted) and follows it quickly towards a flash and slowly back into the dark (Pattanaik et al., SIGGRAPH
    2000), relative to the scene's own long-term level so a night battle stays night; at night, dusk and dawn colour
    drains towards a cool grey as the rods take over (the Purkinje shift, after Thompson, Shirley and Ferwerda 2002).
    Film look adds halation and contrast-adaptive sharpening (AMD FidelityFX CAS). Every pass scrubs NaN and infinite
    pixels, so a bad one can't be smeared across the screen. The browser build has none of these (its renderer has
    no compositor) and hides them.
  - **Heat haze** (Camera and lens; `heat_haze.gd`, the heat pass in `cinematic_fx.gd`): the air shimmers over fires
    and burning wrecks, over the engine decks of vehicles with their engines running and out of their exhausts (a
    helicopter's turbines too, beaten down by its rotor), and for a moment round a blast, a tank gun's muzzle and a
    launcher's back-blast. Each source is a blob of hot air stretched along its axis (a Gaussian: up for a fire, out
    of the pipe and up for an exhaust). `Vfx.heat_sources` and `Vehicle.heat_sources` add them every frame, the
    models mark their exhaust mouths (`VehicleModels.exhausts`), and the 48 in view that would show the most go to the
    graphics card. At quarter resolution the heat pass integrates each one along every view ray in closed form, cut
    off where the ray meets the scene, so whatever stands in front of a fire is never bent by it; the turbulence is
    noise carried up the source's axis in the world, and the bend is sized in metres at the hot air, so nearer haze
    bends more and haze too small on screen to read is left out. The composite then bends only what lies behind the
    hot air, and never pulls in the sky or anything in front of it. With Reduce motion on, the air holds still.
  - **Motion blur** (Camera and lens: Off / Objects / Objects + camera; Cinematic: Objects): the reconstruction
    filter of McGuire, Hennessy, Bukowski and Osman ("A Reconstruction Filter for Plausible Motion Blur", I3D 2012)
    with Jimenez's refinements (SIGGRAPH 2014), four more passes in `cinematic_fx.gd`. Each pixel's movement comes
    from the engine's velocity buffer (drawn only while the blur is on: `needs_motion_vectors`); the camera's share
    is found by reprojecting the pixel's depth with last frame's camera and taken out, so on Objects a commander's
    pan stays sharp while rotor blades, flung bodies and debris still smear (Objects + camera puts 60% of the pan
    back, none with Reduce motion). The blur is half a frame long (a 180-degree shutter), at most 32 pixels: the
    longest blur in each 32-pixel tile and its neighbours tells each pixel how far to look, and 14 jittered samples
    along it are weighed by depth and speed, so a blurred foreground smears over the background and not the reverse.
    Godot's velocity buffer holds where each pixel was less where it is, in uv (measured: `FL_DEBUG_CINE_VIEW=7`).
- **Rain on everything** (`Mats.SURFACE_SHADER`, the `rain_wet` global; `Atmosphere._wet_tick`): in the rain the
  vehicles, buildings, sandbags and gear standing out in it take a film of water, as the ground and streets
  already did (after Lagarde, "Water drop 2b: dynamic rain and its effects", 2013). Rough, porous stuff (cloth,
  timber, concrete) darkens as water fills its pores and gains little gloss; paint and metal barely darken but
  take a glossy film. Upturned faces soak most, faces turned down stay drier, and water runs down walls and hulls
  in streaks. A battle that opens in the rain starts soaked; rain that sets in mid-battle wets things over 30 s,
  and they dry over three minutes once it stops. It costs a few instructions per pixel, so every preset has it,
  the browser too.
- **Level-of-detail cross-fades**: a vehicle and its distant single-mesh stand-in (`Mats.add_distance_lod`), cab
  glass, the street's fine stones and distant blast clouds dissolve into each other over a few metres (Godot's
  dithered visibility-range fade) instead of popping as the camera zooms.
- **Wildlife** (`wildlife.gd`), drawn only on each player's own screen and never simulated or sent by the server,
  so it can't change a battle or its seed. Flocks of sparrows and starlings (pigeons about the town) feed on bare
  ground - tracks, yards, pavements, mud, shell holes, where the grass doesn't hide them - hopping and pecking,
  and move on now and then; hares graze in the open; rats run along the walls in town and keep to their own
  stretch of it; crows and buzzards turn circles overhead (gulls along the coast), throwing shadows; fish swim
  under the surface of the rivers and ponds and sometimes jump; mallards paddle and upend to feed; dolphins
  cruise the open sea, rolling up through the swell to breathe and now and then leaping clear. At night the
  small and soaring birds roost, bats come out and so do more rats; in the rain fewer birds fly. They take
  fright at gunfire, shells and rockets (Fx tells them), rounds cracking past or striking near, grass fires,
  falling trees, low helicopters, a death among them and at the men and vehicles the local player can see coming
  near - never at a hidden enemy - and a flock goes up with a rush of wings (the flocks nearby going up after
  it), a rat runs for a hole in the nearest wall, a hare zigzags off, fish dart away, crows and gulls make off.
  They can be killed, only for the eye: every shot's path is tested against the animals round it (group first,
  then each), and a round through one, or a blast close by, kills it in a puff of blood and feathers - the round
  flies on as it would have. Birds tumble out of the air, the dead lie on their sides where they fell (up to 30,
  cleared out of sight later), fish stunned by a shell in the water float up belly-up. Synthesised calls: birdsong, a coo, caws, a gull's cry, a
  squeak, the splash of a fish or a dolphin. Only the camera's surroundings are alive: whatever falls behind is
  moved on ahead out of sight (birds fly in), so the cost doesn't grow with the map. Each kind is one MultiMesh
  written in one go a frame, with wings, tails and flukes moved in the shader; groups off the screen aren't
  drawn. Settings > Graphics > Wildlife: Plenty, Some or Off (Off on the Low preset).
- Ambient sound: wind that grows as you zoom out (air rushing past and a hollow howl, in irregular gusts), and
  a distant battle (far-off artillery thumps, machine-gun bursts) that swells with the fighting.
- Music (`music.gd`), synthesised at run time: a small orchestra (strings, low strings, horns, a wordless
  choir, piano, timpani, a war drum, a snare) rendered into samples at start-up and played by a sequencer through a
  hall reverb. The menu has a theme in D minor (piano, then the horn's tune over a parade snare, then the strings).
  In battle the score is in layers that follow the fighting: a quiet bed of strings and a few piano notes while
  it's calm, then low strings driving eighths, drums, and horns as it heats up; in a long lull it rests and
  leaves the battlefield to the wind. Victory and defeat each get a short sting.
- Separate volumes for music, effects, ambience and the interface (Settings > Audio).
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
  stacked from individual bags in proper courses, FOBs and camouflage nets throw dappled shadows, trees sway.
  Defences sit in the ground: trodden earth round the nests and pits, earth banked against the bunkers up to their
  slits.
- Vehicles are built from sloped, lofted armour: road wheels that turn, tracks, mantlets, cupolas, stowage, rotor blur.
  On the Abrams, T-55 and Bradley, each track cycles independently and its road wheels follow the ground under that side.
  Hinged shoes retain their place around the track. The T-55's upper run rests on its road wheels and sags in the gaps.
  Dust rises from the end of the contact patch that leaves the soil and switches ends in reverse.
  Rolling noise follows belt travel, including pivot turns, and falls silent at rest while the engine idles.
  Moving Abrams and T-55 tanks leave a faint exhaust trail at the outlet. Damage vents fire and soot through the engine grille, including on the wreck. Each eddy uses the heat and opacity baked from the same volume, so its bright base rolls into darker smoke.
  The ridge camera cuts from the eyepiece to the firing muzzle on discharge, then looks down over the tracks. Nearby shots and impacts jolt the lens when camera shake is enabled.
  The Abrams has a turbine note and the T-55 and Bradley use a diesel recording. Both tanks have a recorded gun report
  and elevate and recoil their main barrels independently of the turret. The visible cradle eases into elevation changes and brakes as it settles. The Abrams has recessed wheel pressings,
  a second row of rim fasteners, stencilled turret bins and strapped canvas rolls. Its rolling loop comes from
  a moving Abrams and blends with the turbine as the hull accelerates. The ridge film uses fictional breakaway
  plates to show a dent and a tear, with the damaged skirt moving at its upper attachment.
  Paint, wear and grime on vehicle fittings follow the part as it moves.
  The ridge film opens above an Abrams and a T-55A, then cuts to an eyepiece mounted on the Abrams turret. Its lens opens wide on the far crest
  and zooms in while the etched reticle stays fixed in the glass.
  Sound is muffled inside the tank. Each contacting track shoe leaves a paired pad impression and presses down the grass it passes over. Each driver chooses among local relay and supply posts.
  A second relay claim unlocks the forward objective for either crew with a claim of its own.
  Reaching it wins the encounter and triggers the finishing impact. A camera beside the ridge holds on the struck vehicle before and after the hit. The film uses the same tank knockout event, fuel burst and burning-vehicle particles as a match. The short flash stays on the hull above the ground, and the hull settles on its suspension. Fuel smoke uses the baked directional lighting maps, with motion-vector interpolation in close views. A fuel vent releases billows at a steady rate as the smoke thickens or thins. The closing camera frames the surviving tank from the side of its turret, keeping the barrel in view as the hull turns.
  The T-55A has a grainier finish on its cast turret and rolled rims on its painted rear drums.
  In a match, hard hits can bend the skirt on the struck side. A complete repair straightens it.
  In a match, both the Abrams and the T-55A keep their last turret bearing on destruction and carry visible plate damage onto the wreck. Soot spreads over the original paint from the engine deck. Cannon hits land on the battle clock when the tracer reaches its destination. A hull contact produces a metal strike, and nearby soft terrain takes paired tread prints. Select either tank and press F10 to cycle to its periscope.
  Its wreck rests on the grade beneath the front and rear of both tracks.
- **Shared vehicle finishes** (`vehicle_materials.gd`, `assets/vehicles/surfaces/`): armor paint, aircraft
  coatings, civilian clearcoat, marine paint, rubber, canvas, exposed metal, glass, nonslip decks and charred
  wrecks use distinct roughness and reflection settings. Eight shared, mipmapped detail maps (six derived
  from ambientCG CC0 sources) add fine relief without requiring UV unwraps. RHIB decks have raised tread;
  selected trawler fittings use nonmetallic rust over exposed steel. Paint is nonmetallic; texture and lower-body dust
  stay attached to the model as it moves or climbs. Faction palettes and distant merged meshes are retained.
  Eight companion normal maps retain the bundled CC0 surface relief; all 18 profiles tune weathering,
  roughness and grain independently. Metal brushing, canvas weave, moulded rubber, timber fibres and
  charred surfaces use separate treatments, filtered at distance.
- **Shared antennas, mirrors and gun tubes** (`VehicleFittings`): land-vehicle radio whips have bolted feet, rubber boots and spring mounts. Nearby visible whips lean with travel, braking and lateral acceleration, then settle; one visual spring per vehicle drives their pivots without physics bodies. Rear-view mirrors share jointed arms, moulded housings, seals and reflective faces. Major tank/artillery gun tubes use open bores, muzzle crowns and segmented thermal sleeves, while retaining family-specific extractors and gun pivots. The T-55 keeps its bare tube.
- **Shared service fittings** (`VehicleFittings`, `VehicleCloth.bag`): truck and Hunter radiator grilles have recessed cores and angled slats; HEMTT and Tempest exhausts have open, soot-lined outlets and heat shields. Shared rubber mudflaps have curved lower edges, ribs and clamps. Padded vehicle stowage uses softened canvas shells, sewn welts and retaining straps. These parts join the existing opaque material bake.
- **Material-aware panels** (`VehicleBody.panel`, `VehicleCloth.panel`): painted and metal panels
  include folded edges, gaskets and fasteners; fabric uses draped meshes, hems and filtered stitching;
  rubber/plastic use chamfered moulded sheets; wood keeps its grain and glass uses fitted seals.
  HEMTT, Zamak and Tempest troop canopies share cloth bays fitted to their own support profiles.
  Baked military body pieces retain edge coordinates for broken paint rubs and primer chips;
  upright paint has restrained runoff streaks. Vehicle camouflage uses larger separated colours,
  while aircraft paint is matte. See [military exterior comparisons](military-exterior-review/README.md).
- **Shared vehicle bodywork** (`vehicle_body.gd`): curved helicopter skins share crease-aware normals
  without moving the vertices beneath fitted glazing. Skin joins and flush fasteners follow the hull;
  deliberately angular stealth sections remain faceted. On the Black Wasp, the curved canopy catches the light along its rim and reveals the pilot and seat beneath. HEMTT, Zamak and Tempest families share pressed
  door panels, gaskets and fasteners, with shaped louvres on Zamak bonnets. Family builders retain silhouettes.
- All HEMTT, Zamak and Tempest bodies share open cabs with seats, dashboards and steering wheels
  behind separate transparent panes. Offroad pickups, hatchbacks and SUVs have open glasshouses with
  their original window outlines and painted pillars. Glass switches to opaque panes beyond 100 m;
  wrecks lose intact glazing. Rounded tyres, recessed rims and rotating tread extend across shared
  wheeled models, with finer road tread and smooth aircraft tyres. Tracked road wheels share twin tyres, recessed discs and hub bolts while retaining
  family-specific spoke patterns and sprockets. HEMTT and Zamak cargo covers share draped cloth and fitted restraints.
- **Shared helicopter rotors** (`vehicle_rotors.gd`): main and exposed tail rotors use tapered airfoil
  sections with spanwise twist, gentle droop, shaped swept or paddle tips, erosion strips and muted tip
  markings. Forked grips, hinge pins, pitch links and a stepped swashplate add depth to rotor heads.
  A dedicated matte nonmetallic finish separates composite blades from painted fuselages and metal hubs.
  Conventional, tandem and coaxial assemblies keep their existing blade counts, pivots and blur switching;
  enclosed ducted fans remain specialised. Detail is most visible while stopped or turning slowly.
- **Reusable vehicle components** (`vehicle_wheels.gd`, `vehicle_tracks.gd`, `vehicle_frames.gd`,
  `vehicle_glazing.gd`): running and spare tyres share profiles; tank and ED-1 track shoes follow each
  vehicle's own outline. Frames, struts, rails and window seals use common builders. Clear panes require
  an open cab; armoured panes stay opaque. Parked civilian cars have fitted windscreens, divided side
  windows and mirrors. See [the component guide](vehicle-components.md), [construction inventory](../tools/vehicles/README.md), and [30-technique review](vehicle-construction-review.md), and [shared equipment detail pass](vehicle-detail-40-review.md).
- **Shared guns and turret fittings** (`vehicle_weapons.gd`, `VehicleMounts`, `VehicleFittings`): heavy,
  medium and grenade machine guns, autocannon, coaxial ports, rotary barrel clusters and missile launch
  tubes each have one builder, used by every family that carries them; muzzle markers and turret pivots
  stay where they were. Turret race rings, sight heads, commander's cupolas, reactive armour bricks,
  rectangular hatches and bore evacuators are shared across the armour; helicopters share rotor masts and
  turbine exhausts, and aircraft and boats share red/green sidelights and dome lights. Trucks share fender
  sheets and saddle fuel tanks; rolled tarps are common stowage. See "Twenty shared components" in
  [the component guide](vehicle-components.md).
- Explosions are layered GPU particles: a flash and light burst, a rolling fireball that cools from the edges in
  until it's dark smoke, a lit smoke column that drifts with the wind, a dirt plume, sparks and debris that
  bounce on the ground, a rolling dust ring, a faint heat-shimmer shockwave and a scorch mark. Heavy rounds
  throw a fountain of earth high into the air that rains back down, fling burning fragments out in arcs that
  burn on where they land, leave flames licking about the crater for a moment, and irregular stones and clods tumble and land around the
  crater once the debris has fallen.
- **Explosions** distinguish fragmentation grenades, high explosive shells and fuel explosions. Grenades
  give a short flash, fast dark fragments and a small dirt burst. HE shells, including the visual scale of a
  roughly 110 mm round, throw a fountain of earth, falling clods and a ground dust cloud; sustained flames
  and burning fragments belong to vehicle fuel explosions. Calibre is an artistic scale reference, not a
  physical blast calculator. Airbursts omit ground layers, and impacts use height above the local terrain.
  Connected smoke and dust billows come from CC0 JangaFX fluid simulations baked into animated textures.
  Six directional lighting channels let them respond to the battlefield's sun and sky. Two elevation views and
  motion-assisted frame blending preserve detail as the cloud rolls and expands. Depth fading softens its
  contact with scenery. Road and rubble bursts are greyer; mud and rain suppress the fine dust.
  The initial flash uses the immediate shared batch, followed by thinner soil dust that clears sooner than
  fuel smoke. Ground-only decals keep scorch off walls and smoke. HE leaves lighter char, while crater
  shading follows the fine height field so the bowl and raised rim remain legible. Ground chunks use local
  height bounds for distance detail, keeping the fine crater mesh near the camera and the coarse grid far away.
  A low dust skirt spreads along the ground and upper dust drifts downwind.
  Reports layer a pressure crack, turbulent bass, irregular ground returns and scattered grit, with clean
  endpoints and peak headroom. Fragmentation grenades use the shorter report rather than a shell's boom.
  Each blast uses one pooled surface. Per-frame bounds trim empty pixels before drawing; quality sets the pool
  budget, and quality and distance limit interpolation. Low and medium settings leave optical-flow maps unloaded
  until a higher-quality burst needs them.
  Fast fragments, curved fans of earth, tumbling clods and delayed landing dust use shared GPU instance rings
  without per-fragment nodes. The fluid simulation runs offline, and expired surfaces stop drawing.
  The same animated volumes and batched fragments work through WebGL; the remaining flash and flame emitters
  use CPU particles on the Compatibility renderer. Source licenses and reproducible baking tools are in
  `assets/vfx/LICENSE.md` and `tools/vfx/`.
- **Illumination flares** descend under a rounded, open cloth canopy with suspension lines, drift with the wind,
  shed fine sparks and leave animated smoke behind in world space. The charge lights its freshest smoke,
  fades as it burns out and stops emitting before its remaining smoke disperses. Each flare uses two bounded
  particle emitters, and the canopy mesh is shared.
- **Gunfire** (`gunfx.gd`), sized to life: a rifle's muzzle flash is a hand's breadth of flame gone in a frame,
  a .50's a forearm's, an autocannon's a man's height - a hot core and a short jet split into petals by the flash
  hider (thrown out sideways by a heavy gun's muzzle brake), with a moment's light on everything round it
  (striking at night). The gas that follows the round out glows for an instant and cools into a breath of smoke,
  and the case spins out of the ejection port to lie in the grass (brass piles up round a machine gun). However
  small, a flash never shrinks below a few pixels, so you can still see who's firing from high up. The weapon
  kicks with each shot: the rifle back into the shoulder and the muzzle up, the mounted gun on its pintle, the
  turret back on its ring when the main gun fires. One round in so many is a tracer, red for the Coalition and
  green for the Rebels (Soviet-pattern ammunition): a thin bright thread at night, fainter and shorter by day,
  with distance-dependent dimming and a short ignition delay for small-arms tracers. What a round hits decides what flies, small and quick as in real footage: a
  crown of dust and soil thrown up out of the ground, a puff of stone dust and chips off a wall, a dry burst of
  sand off sandbags, splinters, leaves fluttering down, sparks and a glint off steel, a dark mist off a man, a
  spout off water - shown when the round gets there, not when it's fired. Now and then one skips off steel, stone
  or the ground. A tank's gun throws out a fireball of burning gas that's full size within a frame or two and
  rolls into a cloud of smoke left hanging in front of the gun, with burning flecks and the blast driving dust
  off the ground; a rocket's back-blast burns into a cloud behind the launcher. The smoke is shaded as a volume
  from a warped density field - lit on the sun's side, in its own shadow on the far one, its thin edges glowing
  against the sun - so no two puffs come out round. All of it is drawn on the GPU, each kind in a single draw
  call, with nothing moved from script once it's spawned, so a heavy firefight costs about what a light one did.
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
  softly where it meets the ground. Burning wrecks burn, then smoulder (see Fire). Smoke screens are real volumetric fog when
  volumetric fog is on. All effect shaders are compiled during loading, so the first explosion doesn't hitch.
- A minimal HUD: the status line along the top, the order of battle and the ready fire missions down the left,
  the latest radio lines top right, a terrain minimap, and the selection and its orders along the bottom only when
  something is selected. Zoom in and every soldier shows what he's doing ("Bandaging Doyle",
  "Pinned down", "Manning the .50 Cal Nest", "Dragging Hakim to safety"); hover one for a small card.
- The main menu sits over a live 3D scene: a .50 cal crew at golden hour with a burning wreck and shelling on the horizon.

**Field Manual** (`ui/field_manual.gd`; main menu, Esc menu or F4): every soldier, squad, weapon, vehicle, building,
defence, fire mission and upgrade, with what it is modelled on (M4A1, PKM, M2HB, Bradley, BTR-80, AC-130J...), its
numbers read live from the game's tables with counted bars against the rest of its kind, derived figures (rate of fire,
sustained damage, squad firepower, km/h), what carries or trains it, and a 3D model to turn over and zoom. The website's Field Manual embeds this same model stage beside its own pages of every entry (vehicles, infantry, squads, weapons, buildings, fire support; upgrades have no model): the model, lighting, rotation and zoom come from the manual; the search, filters, figures and accessible camera buttons use the site UI.
The shared survey grid has occasional subtle interference, disabled by reduced-motion settings. Armed support aircraft have a demonstration button: a stationary training range runs the real support command, aircraft flight, weapons and impacts inside the viewer. Replay retains the prepared range and resets its aircraft and targets; returning to inspection releases the simulation.
A **Cover** chapter covers every kind of battlefield cover - stone and brick walls, hedges, sandbags, cars,
crates, wrecks, rubble, tall walls, windows, trenches, craters and woods - with what it stops, how much blast
gets through, how a man fights from it, and a diorama of a soldier doing so. **Drills & reflexes** shows what a
soldier does without being told: the grenade reflexes, cooking a grenade, clearing a house and kicking a door in,
each posed - and what squads and vehicle crews do (battle drills, morale, driving, smoke, waiting for the infantry).

**AI commander** (`commander_ai.gd`): spare squads go forward to hold the town, the villages and the larger
woods between its front and the enemy's, lying in wait, so the fighting is over the ground in between; a
forward FOB falls due every few minutes and supply is held back for it (each FOB runs its own supply truck,
so whoever expands first pulls ahead). **Towns** are supply, and it goes after them from the start: a squad at a
time to each village or the town within reach that it doesn't hold (two to one the enemy holds), the near ones
first; it stays a few minutes once the flag is up, sends the nearest squad back when the enemy starts taking
one of its own, and gives up on one it can't get into. Its attack waves count an enemy-held town as a softer
target than a base, and a town it holds out beyond its bases gets the next FOB beside it, on its own side.
It lays **ambushes** (`ambush_plan.gd`) on straight stretches of the
roads the enemy uses - his supply track above all - where there's cover to lie in: the squad moves to a rally
point back from the road, then into an L - the assault line 20-odd metres off the road, the gun at one end
firing down the killing zone, a man watching the flank - and holds its fire until they're in it. A short,
violent burst, then smoke and away (the Rebels, more often ambushers, simply melt away); an ambush nobody
walks into is given up after a few minutes, and one bumped on the way is called off. Its **navy**
(
aval_ai.gd`): once it has a factory it builds a dock on its stretch of coast and keeps a gunboat or two -
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

**AI difficulty** (`Defs.AI_LEVELS`, `CommanderAI._apply_skill`): Play vs AI's **Opponent** choice and the lobby's
**AI difficulty** row (the host's setting `ai_difficulty`, for every AI commander in the battle, the enemy's and any
fighting beside the players) set how good the AI is, through how it thinks rather than what it's given. Each
level is a skill between recruit (0) and veteran (2):

| | Recruit | Regular | Veteran |
|---|---|---|---|
| Looks at the battle every | 3.5 s | 2 s | 1.25 s |
| Answers a threat to a FOB | every 45 s, one squad | every 20 s, two | every 12 s, three |
| Attack waves | a squad smaller, at least 70 s apart, goes with what it has after 320 s | 3 squads (4 after ten minutes), 25 s, 200 s | a squad bigger, 20 s, 160 s |
| Attacks | head-on (no base of fire, no flanking) | fix and flank (AttackPlan) | fix and flank |
| Ambushes, recon flights, answering a call for help | never | yes | yes, ambushes and recon more often |
| Fire support | only on a big target (9+), every 90 s at most | on 4+ | on 3+ |
| Battered squads pulled out | never | under a third left | under half left |
| Towns and outposts | looked at every 15 s / 40 s | 6 s / 15 s | 6 s / 15 s |
| The next FOB | 1.6 times the wait | 2 to 3.5 min after the last | as a regular |
| Its lorries' loads | -15% | as they are | +15% |

The supply handicap and bonus apply only to a side no player commands (an AI beside you never costs you supply),
and the menu says so. **Adaptive** starts as a regular and, from five minutes in, weighs its side against the
other every minute (men, vehicles, FOBs and towns): well ahead (1.5 to 1), it eases off a fifth of a level; well
behind (0.7 to 1), it presses a fifth harder; in between it drifts back towards regular. The level shows on the
loading brief and as **AI** on the status line. `--ai-difficulty=veteran` sets every AI, `--ai-difficulty=0:recruit,1:regular`
one per side (for AI-vs-AI comparisons); the test port's world query lists each commander's level.

**Command by intent** (`delegation.gd`): a commander can hand any of his squads and vehicles to his XO with an
intent instead of an order, and the XO carries it out with the AI commander's own drills, giving the squads
their orders, giving them again when the fight knocks them off, and reporting on the command net ("XO: Charlie 1,
Delta 1 - take objective, D4. Wilco.").

- **Hold sector:** the squads spread across the sector facing the way you dragged, each digs in on its piece of
  the line, and one that is knocked off it (displaced by shellfire, broken contact, chased something) is put
  back once it has collected itself. Vehicles wait a little behind the line.
- **Take objective:** a deliberate attack (`attack_plan.gd`), one squad the base of fire and the rest the
  assault, or one squad's own fire and movement; when the objective is clear they consolidate on it and hold
  it like a sector. A failed attack is re-formed and sent in again, up to three times, then they hold where they
  are and the XO says the attack has stalled. A click near a town aims at its square.
- **Screen:** a thin, wide line well forward, there to see the enemy coming. It reports contacts, and a squad
  pressed by more than it can hold falls back a bound (45 m) to the next line, twice, then holds.
- **Reserve:** the squads wait out of the fight until a squad of yours within 260 m is pinned, bleeding or stuck
  at the fix of an attack, then go to help it, joining its attack plan when it has one, and come back to the
  waiting place once that fight has gone quiet.
- **Ambush:** each squad lays an ambush (`ambush_plan.gd`) on the nearest road, side by side along it, on the side
  you dragged from; sprung or given up, it lays it again a little later for as long as the intent stands.
- A squad cut down to a third of its men is pulled back to refit and handed back to you, and the XO says so.
- **Taking them back:** any order of your own to a delegated squad, vehicle or one of its men (a move, an
  attack, a build, a fire mission), or **Take back**, returns it to your command, and the XO says it is back
  with you. Delegated units stay yours (and every allied commander can still order them); the AI commander
  never counts them as its own, so the two never pull a squad different ways.
- **On the map** each intent is drawn in the side's colour with an XO tag, its grid and phase: a sector's
  forward edge with its ticks, an objective ring, a screen's dashed line, a reserve's ring (and, committed, the
  arrow to the fight it went to), an ambush's killing zone; a faint tether runs to it from each squad still on
  its way. The squads' symbols carry an XO tab, and the order of battle and squad card read "XO HOLD · DEF E5".
- The intents are commands like any other (`delegate` and `take_back` through `World.execute_cmd`), so a client
  delegates exactly as the host does; each side's intents reach its players in the team summary.
- **An AI ally answers your pings** (`CommanderAI.answer_ping`): with an AI commander on your side, an "attack here"
  or "enemy spotted" ping gets up to two of its free squads (not a garrison, nor one already in an attack)
  sent in, two as a deliberate attack; "defend here" gets them dug in there; "need support" sends them to you.
  It says who's coming on the net, or that nobody is free; the squads go back to the company after a few minutes.

### Imported rifleman and shared impacts

The detailed rifleman uses imported rifle locomotion, a captured kneel-to-prone transition, contact IK, hand-attached weapons, moving reloads with a separate magazine, directional hit recovery, and a thirteen-body constrained ragdoll. Locally installed Male Injured Pack clips supply standing limping and dazed recovery with the rifle slung. Installed Talking, Laughing and Arm Stretching clips also replace the standing relaxed idles and recover to the armed pose; Rifle Idle supplies the armed lookout. Foot plants retain the visible boot position when acquiring contact. The shared motion and impact helpers also serve the procedural soldiers and tank. Damage and movement remain server-authoritative; the skin is presentation.

When the local Mixamo prone family is installed, forward/backward crawling, stops, idle, firing, reload and grenade throw use captured clips. The installed crouch-to-prone and prone-to-crouch transitions supply entry and recovery; the kneeling pair remains the fallback. A prone-specific captured flinch supplies frontal hit reactions while keeping the weapon grips. The shared controller preserves hand contacts during prone idle/fire and releases the hands for crawling, reloading and throwing. These local evaluation assets are not bundled automatically; missing clips retain the procedural fallback.

Ordinary battles automatically use the bundled SWAT character for Coalition riflemen and medics. The medic keeps the marked aid pack and armband as the character moves or crouches to help a casualty. With only the original skinned pack installed, they use that character instead. Other units and missing-asset installations retain their procedural models. The viewer supports clip selection, scrubbing, bones, wireframes and projectile impacts; the playable controller exercises terrain, walking, crouching, jumping and reloads. Setup and exact limitations are in [the evaluation guide](../tests/mocap/SKINNED.md). Imported models, textures and animation sources are excluded from Git and releases.

Soldiers check space for the whole kneel-to-prone transition. If a wall blocks it, a stationary soldier can take a short backward step into clear space, settle the feet, and then lower into prone. The retreat is collision-swept, navigation-checked and bounded to 1.8 metres. New movement orders or a new obstruction cancel it. If no safe space exists, the soldier remains crouched. This authoritative movement is replicated normally.

Captured contact IK anchors low supporting feet in world space, blends the ankle/forefoot support for running, and releases overstretched contacts. Ragdolls retain bounded limb and root momentum, anatomical joint limits and dropped-weapon collision cleanup. The optional skinned mode runs physics contacts at 120 Hz; the battle simulation retains the current 30 Hz cadence, including when physics runs faster.

This is an opt-in evaluation, not a complete production animation library. Authored directional crouch, precise finger wrapping, mounted reloads, vehicle boarding/seating, prone get-up, final art quality and large-crowd performance still need work. The M2 fixture passes; mounted M240 and original-model DShK reach/clearance are known remaining issues.


## Battle recordings and browser spectators

Hosts save seekable observer recordings. Unchanged scenery is cached and completed chunks are encoded on a worker so recording does less work on the simulation thread. Listed public battles can broadcast only a few seconds behind play; the website lists broadcasts and seven days of replays when persistent recording storage is enabled. The browser uses the game renderer, with camera controls, pause, speed and a timeline. Private battles stay local. Recordings are not independently verified. See [REPLAYS.md](REPLAYS.md) for the format, deployment and limitations.

## Large battles and shared AI work

Desktop skirmishes and observer games can select 1,024, 2,048 or 3,072 metre maps.
Solo games and missions launch a private headless simulation with the same game
executable. The visible game sends commands and draws interpolated snapshots;
the simulation remains authoritative for every soldier, including off-screen units.
Pause, resume and returning to the menu control the owned simulation process.
Web retains the in-process host path.

Squads stagger their planning and share nearby threat assessments (up to 0.25 s)
and building contacts (up to 0.75 s, invalidated by new contacts). Men separated
from the squad assess their own sectors. Individual line of sight, weapon fire,
damage and urgent reactions still run independently. Land orders queue through
bounded path work; destroyed obstacles trigger incremental graph rebuilding.
Native route search skips intermediate cost nodes while preserving their costs
and waypoints; platforms without the extension retain Godot route search.
Repeated blocked sight checks reuse their result only while both endpoints,
exclusions and every blocking collision box remain unchanged. Opening a door,
moving, resizing, disabling or removing a blocker invalidates the result;
smoke and positive visibility are checked afresh. Detection timing is unchanged.

Distant soldiers use shared baked poses of their procedural models, including
standing, crouching, prone and walking poses. Nearby soldiers retain articulated
animation. Distant batches outside the camera frustum and its shadow margin do
not upload transforms; panning restores them immediately. Distant palette variation and subtle gestures are simplified.
Distant vehicles use a single material surface per moving part beyond 100 m;
turrets, wheels and rotors keep their pivots. Near vehicles retain their original
materials. Wrecks retain their original materials to avoid baking meshes during
combat. Squad overview status refreshes at 10 Hz; selection remains immediate.
The battlefield status overlay retains a rasterized image between 15 Hz refreshes when the camera
is still. Panning, zooming and command input refresh it immediately; blast shake does not
invalidate this cache. Cursor hints, selection boxes and placement previews draw in a separate
layer each frame, so moving the pointer does not rebuild all squad counters. Hiding the HUD
also stops its raster updates. Smoke sight checks visit smoke grenades directly rather than every
projectile; cloud growth, movement and dissipation still take effect immediately.

Views build scenery in and around the camera first and cache visited models; local games and hosts
share the clients' spatial draw batches. Distant models and client cosmetic collision bodies remain
inactive, while host collision and the complete simulation stay active. Returning to cached scenery
does not consume the new-model construction limit. Each 64 m block is merged as soon as all of it is built, and a merged model's opaque surfaces cast one shadow together from a shadows-only mesh, so a town costs a few draws a block in each shadow cascade rather than several a wall. New scenery and grass coming into view are built nearest first within a few milliseconds a frame, so a camera move fills in over a few frames instead of freezing one. Nearby movement orders can reuse a checked route corridor, with separate
destinations and invalidation when terrain or danger changes.

Grass, bushes and stones are generated around the camera, beyond their visible
fade distance. Panning reuses nearby chunks and evicts distant ones; returning
to an area recreates the same vegetation from its seed.

See [SIMULATION_SCALING.md](SIMULATION_SCALING.md) for the native perception
boundary, measurement results and remaining limits.

Captured digging and smoking play when the optional rifleman's local activity clips are installed. The rifle follows a torso sling anchor, digging uses a hand-aligned shovel, and a lethal hit releases both rifle and shovel into physics. Sling transitions still blend between poses rather than use an authored handoff.

The optional SWAT preview uses locally installed Mixamo source and movement clips, including crouch locomotion. Its M4 mesh/textures are baked with `tests/mocap/bake_rifle.gd` into a binary resource; the legacy MoCap FBX sources are excluded from exports. Local rifle locomotion packs and prone/stow clips appear in the animation inspector; catalog availability does not automatically add new gameplay actions.

The SWAT action transitions keep the rifle slung during free-hand work, blend the existing back-reach clip into stow/draw, and preserve prone/leaning body poses during magazine handling. A visual-only low-wall continuation holds the tucked-knee pose until the model clears the barrier; simulation speed and vault timing are unchanged. `tests/mocap/action_transitions.tscn` checks equipment continuity, magazine replacement and dive clearance; `tests/mocap/vault_traversal.tscn` checks the actual soldier crossing in the motion scenario.

The local **Character Playground.cmd** launcher opens a controllable terrain lab using the shared soldier renderer. WASD/Shift/Space/C/Z move, run, jump, crouch and go prone; left mouse fires, R reloads, F toggles work, G throws and H tests the selected impact. Movement cancels work. Every gameplay action is available in a pose dropdown; the linked review screen contains all installed source clips and retains comment/approval storage. This lab requires the local SWAT assets and is not an exported game mode.

The Character Playground also supports Alt + mouse free look, preserving the character heading and movement axes while orbiting; Home resets the view. Installed Rifle 8-Way Locomotion clips supply matching crouch directions. The full catalog contains multiple Mixamo packs: owning the eight-way movement set does not provide authored vehicle, partner or every activity interaction. Those remain preview/procedural actions where no clip is routed.

The imported preview routes grenade throws through the installed Mixamo toss while retaining stance legs and grenade release timing. The installed prone family supplies armed crawling; missing clips retain the procedural alternating reach. The installed stand/kneel pair supplies stationary crouch transitions, blending from the current pose to avoid a snap on rising. The crouched grenade clip uses its throwing section with the existing visual release timing. Crouch stops settle toes; posture changes release previous foot anchors before planting again.

The Coalition mortar specialist also wears the textured character and carries his role-specific kit on the animated back. Native macOS OpenGL uses articulated soldiers because animated skin geometry disappears on that driver.

Rebel fighters and medics use the same close-up animation rig, with faction-tinted uniforms, their own rifles and a marked medic pack. Soldiers crossing trench lips step between ground levels in both directions.

The default close-up SWAT infantry presentation ships in a compiled runtime bundle (assets/infantry/infantry.zip), shared by the game and animation playground. Original authoring files are not required. See assets/infantry/README.md for rebuilding and the separate asset licenses.

Standing rifle melee uses the captured rifle punch, trimmed to meet the existing 0.55-second hit. Watchtower climbing uses a captured ladder cycle with server-controlled elevation: soldiers approach the rear ladder, climb for four seconds, then transfer onto the deck before walking through the platform's railing opening. The cycle follows elevation, with hand and boot contacts constrained to the rungs and upper side handholds. Hands-free actions blend into and out of their poses without abruptly pulling the support hand back to the rifle. The additional carrying family and turn-and-door-kick remain inspector clips: gameplay uses a two-person stretcher, and its KICK action also serves ground-level grenade kicks, so those motions are not interchangeable.

The active camera gets visible grass, shrubs and scenery on its first frame, including after a camera cut. Nearby off-screen scenery builds ahead of the view. Grass and shrub culling bounds follow their local ground heights, keeping distance fading correct beside taller mountains; small cosmetic stones use the ground height at placement. Meadow density fades towards the snow line and on steep slopes, with zero-density habitats kept empty. Smaller photographed shrub branches form seeded patches with open gaps, independently of gameplay randomness.

Alpine stone clusters combine slabs, blocks and small fragments in shared batches. Fine fragments cull beyond 180 m with a 20 m hysteresis margin; larger rocks remain visible.

Daylight uses a bundled CC0 photographic cloud panorama, aligned with the sun and cached for sky lighting and reflections. Other lighting moods retain their procedural skies.

Generated towns have distinct garden plots, narrow foundation aprons and paths leading to their generated front or side doors. Front fences leave pedestrian and driveway openings. Driveway aprons continue across sidewalks through lowered kerbs with sloping shoulders; grass stays out of the crossing. Paving follows immutable terrain elevation and retains crater cutouts; street furniture and both wire endpoints carry authoritative ground heights. Long fences are broken into short, independently destructible sections. Streets and junctions share scanned asphalt; sidewalks, drives and door paths use scanned paving slabs. CC0 photographs include mipmapped normal and roughness maps, with source credits in assets/town/LICENSE.md. Meadow and garden turf combines photographic soil/blade detail with moisture variation from sheltered soil and exposed patches. Grass uses thirty narrow pointed blades at the previous ninety-triangle clump cost, with shorter clumps in towns; grass stays outside the carriageway.

Town entrances blend gravel into asphalt through irregular edges. Local repair patches, staining, aged tile roofs, concrete roof slabs and weathered timber fences use bundled CC0 scans with mipmapped relief; metal fences retain rust and worn paint.

Trees, hedges and shrubs use photographed needle/leaf cards, preserving batched rendering, burning and destruction. Broadleaf crowns use smaller cards with open gaps at the same triangle count; photographs blend in linear light and both sides receive skylight. Beyond the playable boundary, patchy hillside forests use a four-variant, five-elevation prebaked fir atlas and two triangles per tree; slope, height and coast masks keep cliffs and water clear. The two nearest elevation views blend around the physical crown centre as the camera tilts; isolated texture-array mipmaps keep neighbouring views from bleeding together. Shared seeded density masks connect trees with woodland ground cover. High/Ultra shadows also ground those trees with cast shadows; Low/Off avoids that pass. These scenery-only trees add no combat cover. Setting View distance / detail to Near disables distant forests.

Scenery terrain and forests share a cached sky-visibility and sun-shadow map generated from the same height field as their geometry. It renders once when the map or lighting mood changes; switching moods reuses the forest batches. Ridge shadows continue across the playable boundary, while gameplay heights and visibility rules remain authoritative. Rain puddles are limited to gentle slopes.

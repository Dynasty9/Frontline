# Changelog

Every release of Frontline, newest first. The game updates itself; downloads, and this changelog with pictures,
are on [the website](https://web-production-5a4c1.up.railway.app/changelog/). Each change is written up in [`changelog/`](changelog/) as part of
the pull request that makes it.

## v0.1.5: Roaring Fires

*16 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v0.1.5)

Fires roar and crackle instead of surging like surf, and many explosions at once no longer distort.

### Fixed

#### Fires roar instead of surging

Burning buildings had the same rolling-surf sound the wind used to have. Now a fire is a steady roar with crackles on top.

- The roar sits in the middle of the range instead of a low rumble, at the same loudness as before.
- It loops without a dip or a jump.

#### No more distortion when shells land together

When several explosions went off at once the sound could clip. A limiter on the master volume now holds it just under the top, and everyday levels are unchanged.

## v0.1.4: Reconnaissance

*16 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v0.1.4)

You can see what your side can see: the fog of war is drawn on the battlefield and the minimap. Aircraft spot as they fly, and recon flights, overwatch drones and manned watchtowers push the fog back.

### New

#### A fog of war you can see

Ground your side can't see right now is drawn darker on the battlefield and the minimap, so you know where your vision ends and where you need eyes.

![The fog of war in a bridgehead battle](changelog/v0.1.4/fog-of-war/fog-of-war.jpg)

![The same moment before: nothing showed where your vision ended](changelog/v0.1.4/fog-of-war/before.jpg)

- The edge is soft, aircraft overhead aren't darkened, and at night it's lighter because everything is dark already.
- **What you see darkened is exactly what's hidden from you:** enemies inside it don't show.
- **Last-known positions:** an enemy anyone on your side has seen stays marked where it was last seen for 90 seconds, with how long ago.
- The new eye button in the map layers turns the fog off.

#### Aircraft that spot, recon flights and overwatch drones

Every aircraft now reveals the ground it flies over. New fire-support calls fly recon passes along a line you draw, or put a drone overhead to watch one spot.

![A recon pass lights a strip over the Rebel positions](changelog/v0.1.4/recon-flights/recon-pass.jpg)

![The Caesar spotter plane](changelog/v0.1.4/recon-flights/spotter-plane.jpg)

- **Aircraft spot as they fly:** bomb runs, gun runs, gunships and armed drones all reveal what's around them. The minimap shows every aircraft.
- **Recon passes** (from minute two): the Coalition's A-149 Gryphon flies fast and high, the Rebels' Caesar spotter flies slow and low. Drag out a line; the strip they fly over stays lit for six seconds.
- **Overwatch drones** (from minute four): an unarmed drone circles a spot for about a minute and shows what's around it.
- **Watchtowers** see further, and further still with a lookout up them. Placing one shows its reach.
- **The Rebels get a drone too:** the AR-2 Tayran quadcopter, at the Helipad.
- The enemy is warned when a recon flight or overwatch drone comes over, and the AI calls recon flights before it attacks ground it can't see.

## v0.1.3: Soundtrack

*16 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v0.1.3)

A synthesised orchestral soundtrack that follows the fighting, a volume slider for each kind of sound, and wind that sounds like wind.

### New

#### A soundtrack that follows the fighting

Music, made in code like everything else: a theme for the menu, and a battle score that builds as the fighting heats up and eases off in the lulls.

- **Instruments:** strings, horns, a wordless choir, piano, timpani, a war drum and a snare, played through a concert-hall reverb.
- **The menu** has a two-minute theme in D minor.
- **In battle** the score comes in layers: strings and a few piano notes when it's calm; a low-strings pulse, drums and horns as the fighting grows. After a long stretch at full intensity it eases off, and in quiet spells it rests.
- **Victory and defeat** each get a short sting.

### Improved

#### A volume slider for each kind of sound

Settings > Audio has separate sliders for music, effects, ambience and the interface, plus a switch for music in battle and one to mute the game in the background.

![Settings > Audio](changelog/v0.1.3/audio-settings/audio-settings.jpg)

- **Master, Music, Effects, Ambience and Interface**, each on its own slider.
- **Music in battle** can be switched off while keeping the menu music.
- **Mute in the background** silences the game when you switch away.
- The sliders follow your ears: halfway sounds about half as loud.

### Fixed

#### Wind that sounds like wind, not surf

The ambience used to sound like waves breaking. Now it's rushing air with gusts that come and go, over far-off artillery and gunfire.

- The wind no longer swells and fades on a fixed four-second cycle, or gets louder as you zoom out.
- The distant battle is far-off thumps and bursts instead of a low rumble.
- Wind, rain and the distant battle loop without a seam.

## v0.1.2: Fire and Smoke

*16 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v0.1.2)

Things catch fire now: woods, hedgerows, timber roofs and wrecks burn and spread it downwind. Explosions and smoke are bigger and look the part.

### New

#### Fire that spreads

Shells, bombs and burning wrecks set things alight. Fires take hold, roar, spread to whatever will burn nearby (much more readily downwind), and burn themselves out.

![A hedgerow and a grass fire, with smoke drifting downwind](changelog/v0.1.2/fire/fire-day.jpg)

![The same fires at night](changelog/v0.1.2/fire/fire-night.jpg)

- **What burns:** trees, hedges, crates, watchtowers, log dugouts, tents and plank huts, timber roofs and parked cars. Stone, brick, concrete, earth, sandbags and steel don't.
- **What sets it off:** blasts (a shell or bomb often, a grenade rarely), cars that have been badly shot up, and destroyed vehicles, which now burn where they died.
- **Grass fires:** a heavy round in long grass or undergrowth can start a ring of low flames creeping outward over blackened ground.
- **Spreading:** at full blaze a fire jumps to what's nearby, so a hedgerow or a wood can go up one tree after another.

### Improved

#### Bigger explosions and smoke

Explosions throw a proper fireball and debris, and smoke rises as one billowing column instead of a string of puffs.

![Explosions before and after](changelog/v0.1.2/explosions-and-smoke/before-and-after.jpg)

- Fireballs last long enough to see, and the bigger the round, the bigger the blast.
- Smoke from fires and wrecks rises as a continuous column and drifts with the wind.

## v0.1.1: Interface Scale

*16 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v0.1.1)

The interface grows with your window, stays sharp at any size, and can go much bigger without panels running into each other.

### Improved

#### An interface that's big enough, and stays sharp

Interface scale now follows the size of your window, text and symbols stay crisp at any scale, and it goes much bigger without the panels overlapping.

![Before and after, at 1080p](changelog/v0.1.1/interface-scale/before-and-after.jpg)

![The largest scale, with Settings open](changelog/v0.1.1/interface-scale/largest.jpg)

- **Follows the window:** at 100% the interface takes the same share of the screen at any resolution, so it's bigger at 1440p and 4K than before.
- **Sharp at any size:** text and map symbols are drawn at the scale they're shown, not stretched.
- **Goes bigger:** the slider reaches the largest scale your window has room for (2× at 1080p, 2.67× at 1440p).
- **No collisions:** the minimap, selection panel and command card make room for each other, and the Field Manual and observer bar stay on screen.
- It follows window resizes and fullscreen switches as they happen.

## v0.1.0: First Release

*16 October 2026* · [Release on GitHub](https://github.com/Dynasty9/Frontline/releases/tag/v0.1.0)

The first build you can download and play: the whole game as it stands, now with online play through Find Match, missions, camera controls from other RTS games, restyled soldiers, and a game that keeps itself up to date.

### New

#### Online play: Find Match and a list of battles

Press Find Match to drop into an open battle, or host one for the next player to find. Join Game lists every battle being hosted, and most home routers need no setup.

![Join Game: the battles being hosted, and connect by address](changelog/v0.1.0/online-play/join-a-battle.jpg)

- **Find Match** joins the best open battle (ones still in the lobby first, then the fullest). If there isn't one, it hosts a battle and lists it for others.
- **Join Game** shows every battle being hosted: its commander, how many are in it, and whether it's still in the lobby or already fighting.
- **No port forwarding for most players.** Your game and the host's are introduced to each other and connect directly; the game traffic never goes through a server. A few strict networks (some mobile and campus ones) can't be reached this way, and the lobby says so.
- **Join by address** still works for LAN and VPN games.
- **Accounts are optional.** Sign in beside your callsign and it's yours: no one else can register it, and battles you host show a tick.

#### Missions

Five short operations with objectives and radio traffic, to play alone or in co-op.

![Kingpin, one of the missions](changelog/v0.1.0/missions/kingpin.jpg)

- Each mission sets a side, a goal and a time of day, and ends in **Mission accomplished** or **Mission failed**.
- Play them alone, or host one for friends to join in co-op.

#### The game keeps itself up to date

When a new version comes out, the game downloads it in the background, checks it, and asks you to restart. Quitting works too: the next launch is the new version.

![An update downloaded and ready](changelog/v0.1.0/self-updating/update-ready.jpg)

- The menu shows the download's progress, then **Restart**.
- Every download is checked against the checksum published with the release before it's installed.
- If the game's folder can't be written to, it links to the download instead.
- The version you're running is shown at the bottom right of the menu.

#### The Frontline website

The battles being hosted right now, a Join button that opens the game and connects you, and the latest download.

- **Join from the browser:** click Join on any battle and the game opens (or the one you have open takes over) and connects you.
- **Downloads** for Windows and Linux, always the latest version.
- Start the game once after downloading, so your computer knows how to open the site's Join links.

### Improved

#### Camera controls from other RTS games, and a clearer minimap

The mouse wheel zooms towards the cursor, middle-drag turns and tilts, and the minimap's edges aren't hidden under buttons any more.

![The new camera, tilted over a village](changelog/v0.1.0/camera-and-minimap/camera.jpg)

![The minimap before and after](changelog/v0.1.0/camera-and-minimap/minimap.jpg)

- **Zoom toward the cursor:** whatever you aim at stays under the mouse.
- **Middle-drag** turns (left and right) and tilts (up and down). **Alt + middle-drag** grabs and drags the map.
- **Shift** pans faster, and panning eases in and out.
- **Backspace** (or the compass on the minimap) resets the view, **Ctrl + F** follows the selection, and **Ctrl + F5 to F8** save views that **F5 to F8** recall.
- Jumps to alerts, bases and groups glide instead of cutting.
- The minimap's buttons moved off the map, so its top row and right-hand column are visible.

#### Restyled soldiers

Soldiers have a new look, after the early Metal Gear Solid games: chunkier, clearer silhouettes that read well from the battle camera.

- New proportions and gear for both sides, so riflemen, gunners and engineers are easier to tell apart at a glance.

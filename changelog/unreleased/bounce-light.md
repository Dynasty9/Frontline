+++
title = "Bounce light: sunlit walls and streets light each other"
summary = "Sunlight thrown back off walls, roofs and roads now lights what faces them, in their colours: a sunlit wall warms the pavement, a plaza lights the statue in it, the floor of a roofless ruin picks up its walls. A new Bounce light setting, on from High."
kind = "new"

[[screenshots]]
file = "midday.jpg"
caption = "Midday, inside a roofless ruin: the foot of the shaded wall glows warm with light off the sunlit floor, fading up the wall (off above, on below)"

[[screenshots]]
file = "midday-light.jpg"
caption = "The same, bounce light only (on minus off, four times brighter): it climbs the walls from the floor"

[[screenshots]]
file = "golden.jpg"
caption = "Golden hour, from 30 m: the shaded walls and the floor of a ruin lift"

[[screenshots]]
file = "golden-light.jpg"
caption = "Golden hour, bounce light only (four times brighter)"

[[screenshots]]
file = "overcast.jpg"
caption = "Overcast, from 30 m: with no sun the walls have little light to throw, so it is subtle: a doorway lifts a little"

[[screenshots]]
file = "overcast-light.jpg"
caption = "Overcast, bounce light only (four times brighter)"

[[screenshots]]
file = "command-height.jpg"
caption = "From the usual 55 m command height, midday: the yards between the houses warm with light off their sunlit walls"

[[screenshots]]
file = "command-height-light.jpg"
caption = "The same, bounce light only (four times brighter): yards and wall feet, while open grass stays as it was"

[[videos]]
file = "flicker.webm"
poster = "flicker.jpg"
caption = "Off and on in turn, a second each, on the same frozen frames: midday, golden hour, overcast, and from the usual 55 m command height."

[[videos]]
file = "pan.webm"
poster = "pan.jpg"
caption = "The bounce light alone (brightened) while the camera pans fast: it stays on what it lights, with no smears or trails."
+++

- **What you'll see:** shaded walls facing a sunlit street glow with its colour, plinths, benches and kerbs
  standing on sunlit paving catch its warmth from below, and rooms open to the sky fill with light off their
  own walls, and light carries on from there, so shadows beside furniture and rubble are lifted rather than
  black. Sunlit floors light the foot of the walls above them, fading up the wall, and a coloured wall tints
  what lies beside it. Open ground, lit by the sky alone, looks as before, and sunlit surfaces aren't veiled.
- **From the usual command height too:** further off, the rays reach further and the light is laid on stronger,
  so yards, wall feet and roofless rooms still lift where a player usually looks from.
- **It holds still while you pan and zoom:** the light is kept from frame to frame and moves with the world,
  and nothing moving drags a smear behind it.
- **Settings > Graphics > Lighting > Bounce light:** Off, Medium or High (High casts more rays, for less grain).
  It's on Medium in the High preset and on High in Ultra and Cinematic, and costs well under a millisecond a frame
  on a fast graphics card (at 1600x900 on an RTX 3090, about a third of a millisecond on High; Medium less).
- The browser version draws without it.

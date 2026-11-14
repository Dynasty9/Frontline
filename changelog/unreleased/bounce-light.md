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
caption = "Golden hour, from 30 m: the shaded floor and the far wall of a ruin lift"

[[screenshots]]
file = "golden-light.jpg"
caption = "Golden hour, bounce light only (four times brighter)"

[[screenshots]]
file = "overcast.jpg"
caption = "Overcast, from 30 m: the floor and the walls' feet lift, lit by the paler ground round them"

[[screenshots]]
file = "overcast-light.jpg"
caption = "Overcast, bounce light only (four times brighter)"

[[videos]]
file = "flicker.webm"
poster = "flicker.jpg"
caption = "Off and on in turn, a second each, on the same frozen frames: midday, golden hour and overcast (the last view, from the usual command height, shows how faint it is from up there)."

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
- **It holds still while you pan and zoom:** the light is kept from frame to frame and moves with the world,
  and nothing moving drags a smear behind it.
- **Settings > Graphics > Lighting > Bounce light:** Off, Medium or High (High casts more rays, for less grain).
  It's on Medium in the High preset and on High in Ultra and Cinematic, and costs well under a millisecond a frame
  on a fast graphics card (at 1600x900 on an RTX 3090, about a third of a millisecond on High; Medium less).
- The browser version draws without it.

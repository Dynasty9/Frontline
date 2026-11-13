+++
title = "Bounce light: sunlit walls and streets light each other"
summary = "Sunlight thrown back off walls, roofs and roads now lights what faces them, in their colours: a sunlit wall warms the pavement, a plaza lights the statue in it, the floor of a roofless ruin picks up its walls. A new Bounce light setting, on from High."
kind = "new"

[[screenshots]]
file = "doorway.jpg"
caption = "Midday, a house front in shade: the red door glows, lit from below by the sunlit step and path (off above, on below)"

[[screenshots]]
file = "doorway-light.jpg"
caption = "The same doorway, bounce light only (on minus off, four times brighter): it lands on the door and the foot of the wall"

[[screenshots]]
file = "ruin.jpg"
caption = "Midday, inside a roofless ruin: the shaded corner by the green wall warms with light off the sunlit floor"

[[screenshots]]
file = "ruin-light.jpg"
caption = "The ruin, bounce light only (four times brighter): the floor's warm light climbs the wall and fills the corner"

[[screenshots]]
file = "street.jpg"
caption = "Midday, a ruined house by the road: the shaded tiles along the wall are lit by the sunlit floor in front"

[[screenshots]]
file = "street-light.jpg"
caption = "The same house, bounce light only (four times brighter)"

[[videos]]
file = "flicker.webm"
poster = "flicker.jpg"
caption = "Off and on in turn, a second each, on the same frozen frames: watch the door, the corner and the tiles brighten. Bounce light is strongest under a high sun, which floods the ground with light to throw back."

[[videos]]
file = "pan.webm"
poster = "pan.jpg"
caption = "The bounce light alone (brightened) while the camera pans fast: it stays on what it lights, with no smears or trails."
+++

- **What you'll see:** shaded walls facing a sunlit street glow with its colour, plinths, benches and kerbs
  standing on sunlit paving catch its warmth from below, and rooms open to the sky fill with light off their
  own walls, and light carries on from there, so shadows beside furniture and rubble are lifted rather than
  black. Open ground, lit by the sky alone, looks as before.
- **It holds still while you pan and zoom:** the light is kept from frame to frame and moves with the world,
  and nothing moving drags a smear behind it.
- **Settings > Graphics > Lighting > Bounce light:** Off, Medium or High (High casts more rays, for less grain).
  It's on Medium in the High preset and on High in Ultra and Cinematic, and costs well under a millisecond a frame
  on a fast graphics card (at 1600x900 on an RTX 3090: 0.1 to 0.35 ms on Medium, 0.35 to 0.7 ms on High).
- The browser version draws without it.

+++
title = "Bounce light: sunlit walls and streets light each other"
summary = "Sunlight thrown back off walls, roofs and roads now lights what faces them, in their colours: a sunlit wall warms the pavement, a plaza lights the statue in it, the floor of a roofless ruin picks up its walls. A new Bounce light setting, on from High."
kind = "new"

[[screenshots]]
file = "street.jpg"
caption = "A town street at golden hour, without and with bounce light"

[[screenshots]]
file = "ruin.jpg"
caption = "Inside a roofless ruin: its sunlit walls light the floor"

[[screenshots]]
file = "alley.jpg"
caption = "Between two houses: each sunlit wall lights the shaded one across from it"

[[videos]]
file = "pan.webm"
poster = "pan.jpg"
caption = "The bounce light alone (brightened) while the camera pans fast over the town square: it stays on what it lights, with no smears or trails."
+++

- **What you'll see:** shaded walls facing a sunlit street glow with its colour, plinths, benches and kerbs
  standing on sunlit paving catch its warmth from below, and rooms open to the sky fill with light off their
  own walls. Open ground, lit by the sky alone, looks as before.
- **It holds still while you pan and zoom:** the light is kept from frame to frame and moves with the world,
  and nothing moving drags a smear behind it.
- **Settings > Graphics > Lighting > Bounce light:** Off, Medium or High (High casts more rays, for less grain).
  It's on Medium in the High preset and on High in Ultra and Cinematic, and costs well under a millisecond a frame
  on a fast graphics card (0.35 ms on Medium, 0.7 ms on High at 1600x900).
- The browser version draws without it.

+++
title = "Bounce light: sunlit walls and streets light each other"
summary = "Sunlight thrown back off walls, roofs and roads now lights what faces them, in their colours: a sunlit wall warms the pavement, a plaza lights the statue in it, the floor of a roofless ruin picks up its walls. A new Bounce light setting, on from High."
kind = "new"

[[screenshots]]
file = "street.jpg"
caption = "The edge of town at golden hour: off, on, and where the light lands (the difference, four times over)"

[[screenshots]]
file = "ruin.jpg"
caption = "Inside a roofless ruin: its sunlit walls light the shaded floor, and the shadow by the crate is no longer black"

[[screenshots]]
file = "alley.jpg"
caption = "Between two houses in shade: only a little light finds its way in, as it should"

[[videos]]
file = "pan.webm"
poster = "pan.jpg"
caption = "The bounce light alone (brightened) while the camera pans fast over the town square: it stays on what it lights, with no smears or trails."
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

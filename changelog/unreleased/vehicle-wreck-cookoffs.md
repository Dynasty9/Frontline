+++
title = "Cook-off turrets and replayable wrecks"
summary = "Cook-offs throw turrets clear of the hull and settle them on the ground; wrecks restore correctly when you rewind or reopen a recorded battle."
kind = "improved"

[[screenshots]]
file = "burnt-out.jpg"
caption = "The same tank, technical and helicopter, two minutes after they were knocked out, before (top) and after (bottom): the tank's ammunition went up and blew its turret off."

[[screenshots]]
file = "helicopter-crash.jpg"
caption = "The same two shoot-downs before (top) and after (bottom): a spin-in and a heavy landing, close up and from the commander's camera."

[[videos]]
file = "cookoff-motion.webm"
poster = "cookoff-motion.jpg"
caption = "Main, then the new cook-off close up and at gameplay distance: the turret lifts, tumbles and settles beside the hull. Actual destruction at normal speed (Compatibility); replay reliability is tested separately."
+++

- **Burnt out, end to end:** every wreck, from tanks and APCs to trucks, technicals and helicopters, burns out from
  where the fire took hold. Over the best part of a minute the burn creeps across the hull, gun barrel and all,
  leaving charred black steel, the paint burnt to a pale grey film where it was hottest, rust running down the sides,
  soot streaks and ash on the tops, with a few islands of blistered paint.
- **Embers:** while it burns, embers glow in the seams around the heart of the fire.
- **Brewed up:** when a tank or IFV's ammunition goes up (more likely the harder it was hit), the turret is blown
  clean off. It lies a few metres away, upside down, on its side or dug in, its gun bent, and there's a black hole
  where it sat.
- **What burns away:** tyres burn off and wheeled vehicles sit down on their rims, canvas covers are gone, the grass
  is burnt to black stubble and the ground blackened a few metres out all round the wreck (the grass in the heart of
  a shell hole's scorch is black now too), and torn-off pieces lie round it.
- **Crashed helicopters:** the blades shatter as they hit the ground: stubs at the hub, others snapped and bent into
  the dirt, some flung clear, and the tail rotor is usually gone. A helicopter that spun in lies rolled onto its side
  with its nose dug in; one that autorotated to a heavy landing sits slumped on its belly.

The original battle tank and old tank now participate in cannon-ammunition cook-offs too. Cook-offs now lift the turret through a short arc before a low rebound and settling beside the hull. Turrets land on the dirt instead of hovering above it. Radio whips snap in the blast rather than propping up an upside-down turret. The pose follows recorded battle time, so seeking or reopening a battle restores the same stage of the motion. Wreck paint and detached-turret properties are explicitly accepted and checked by the replay reader.

The comparison sheets above are retained from the original follow-up on `0f8520d3`, against the older `1c6e13a7` baseline. They show settled appearance, not this new motion or replay compatibility. The video shows the new motion against current main at a matched close camera, followed by the new behavior at gameplay distance. It uses the Compatibility renderer; it does not establish replay compatibility or hardware performance.

+++
title = "Reflections in the shade lose the sky; soldiers take the light where they stand"
summary = "Glossy hulls, glass and wet cobbles in alleys and under eaves no longer mirror a sky they can't see, and every soldier, not just the riflemen, takes the dim, tinted light of the room, alley or wood he's in instead of standing in open-sky light."
kind = "improved"

[[screenshots]]
file = "reflections.jpg"
caption = "Rain, an alley between two houses with a car parked under the eaves. Without the light probes the car's roof and glass and the wet alley floor mirror the bright sky; with them they mirror the walls round them, about a third darker on the car, a tenth on the open roofs."

[[screenshots]]
file = "soldiers.jpg"
caption = "The same frozen moment, probes off and on: a gunner in the room takes its dim, warm light, about half as bright as he stood before, and a man by the wall outside its shade, a third darker. A man out in the open is unchanged."

[[screenshots]]
file = "wall-down.jpg"
caption = "One wall of a house knocked down, before and after, the game and what the probes see. The probes are laid again on the frame it goes; with the roof still on, what comes in is the sun through the gap and its bounce, not the open sky."
+++

- **Reflections know what's overhead, now for real:** hulls under the eaves, windows across an alley and wet
  cobbles between houses stop mirroring the open sky. (The light probes' first try at this was painted over by the
  battlefield's reflections; it now works through Godot's own specular occlusion.)
- **Every soldier sits in the scene:** machine gunners, officers, medics and the rest (not only the riflemen),
  and the distant men too, take the dim, tinted light of the room, alley or wood they stand in, and the sun is cut
  for them indoors as it is for the walls round them.
- **A new test scene,** `--scenario=alley`: two houses across a narrow alley with a car parked in it.

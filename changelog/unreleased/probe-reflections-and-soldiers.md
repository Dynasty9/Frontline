+++
title = "Reflections in the shade lose the sky; soldiers take the light where they stand"
summary = "Glossy hulls, glass and wet cobbles in alleys and under eaves no longer mirror a sky they can't see, and every soldier, not just the riflemen, takes the dim, tinted light of the room, alley or wood he's in instead of standing in open-sky light."
kind = "improved"

[[screenshots]]
file = "reflections.jpg"
caption = "Rain, an alley between two houses with a car parked under the eaves, probes off over on. With them the car's roof and windscreen (close up, right) and the wet alley floor mirror the walls round them, not the bright sky: about a third darker on the car, a tenth on the open roofs."

[[screenshots]]
file = "soldiers.jpg"
caption = "Three men, probes off over on: a gunner in a room takes its dim, warm light (about half as bright), a man in the narrow alley its shade and the brick's warmth (a fifth darker), and a man out in the sun is unchanged."

[[screenshots]]
file = "wall-down.jpg"
caption = "One wall of a house knocked down, before and after, the game and what the probes see. The probes are laid again on the frame it goes; with the roof still on, what comes in is the sun through the gap and its bounce, not the open sky."

[[videos]]
file = "alley-rain-pan.webm"
poster = "alley-rain-pan.jpg"
caption = "Same rain pan with probes enabled in both: v2.0.2 renderer (66fcc404, same alley fixture backported) and #263 (f885d98). The sheltered car window reflects less sky and the crew takes the shade. Both already include #253: covered floors stay dry. Matching camera, sky, seed and High settings; normal-speed Forward+ software-Vulkan capture, without grading."
+++

- **Reflections know what's overhead, now for real:** hulls under the eaves, windows across an alley and wet
  cobbles between houses stop mirroring the open sky. (The light probes' first try at this was painted over by the
  battlefield's reflections; it now works through Godot's own specular occlusion.)
- **Every soldier sits in the scene:** machine gunners, officers, medics and the rest (not only the riflemen),
  and the distant men too, take the dim, tinted light of the room, alley or wood they stand in, and the sun is cut
  for them indoors as it is for the walls round them.
- **A new test scene,** `--scenario=alley`: two houses across a narrow alley with a car parked in it.

The matched motion capture and its source revisions are recorded in `probe-reflections-and-soldiers/alley-rain-pan-capture.json`.
The v2.0.2 comparison already includes rain shelter (#253): floors under roofs stay dry in both builds. This pass corrects specular probe occlusion and soldier lighting, not indoor floor wetness.

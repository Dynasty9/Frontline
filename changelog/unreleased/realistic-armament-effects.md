+++
title = "Distinct grenade, shell and fuel explosions"
summary = "Grenades throw fast fragments, shells lift earth and falling clods, and vehicle fuel burns. Flares drift under parachutes, tracers dim with distance, and metal impacts shed chips."
kind = "improved"

[[videos]]
file = "armaments.webm"
poster = "after.jpg"
caption = "Current build, controlled range: grenade, roughly 110 mm HE visual scale and vehicle fuel, followed by dirt, stone and metal impacts. Ground marks are 10 m apart."

[[videos]]
file = "before.webm"
poster = "before.jpg"
caption = "Before this change: the same range, seed, camera, renderer and explosion sizes at source revision b3ec859. All three blasts use the former fireball effect."

[[videos]]
file = "flares.webm"
poster = "flares.jpg"
caption = "Current build: a following camera shows the illumination flare's parachute, suspension lines, sparks and smoke at night."

[[screenshots]]
file = "before.jpg"
caption = "Before: the HE shell uses the common fiery explosion profile."

[[screenshots]]
file = "after.jpg"
caption = "After: the same shell lifts brown earth above a short-lived cloud of detonation gas."
+++

- Fragmentation grenades have a smaller, shorter flash and fast dark fragments. HE shells throw dirt, a dust cloud and clods; sustained fire and burning fragments belong to fuel explosions.
- Ground effects follow the terrain height, including hills. Airbursts keep their flash and smoke without throwing dirt from midair.
- Illumination flares descend and drift with the wind, leave smoke behind, and stop shedding particles when their charge burns out. Their remaining smoke disperses before the flare is removed.
- Small-arms tracers light a short distance beyond the muzzle and dim further as they recede. Nearby metal impacts shed small chips alongside sparks.
- Effects reuse bounded pools and reduce detail with distance and the effects setting. Fragments and landing dust animate in shared batches, including in the browser.

These are procedural visual effects. The 110 mm label indicates approximate visual scale, not a validated blast simulation. The clips are silent, run at fixed simulation timing, and demonstrate appearance rather than frame-rate improvements.

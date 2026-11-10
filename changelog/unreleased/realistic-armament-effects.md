+++
title = "Explosions with rolling dust and lit smoke"
summary = "Explosion clouds roll and disperse, with sunlight catching their billows. HE throws dark earth; fuel burns through rising smoke. Flares descend under cloth parachutes and leave drifting trails."
kind = "improved"

[[videos]]
file = "battlefield.webm"
poster = "battlefield.jpg"
caption = "Battlefield showcase: grenade, HE and fuel explosions, tracers striking dirt, stone and a vehicle, then a descending night flare. Real terrain, vegetation and cover throughout. Forward+, 28 seconds, fixed 24 fps, normal speed; silent."

[[videos]]
file = "world.webm"
poster = "after.jpg"
caption = "After: a roughly 110 mm HE ground burst in the battlefield, with earth fans, falling clods and a rolling dust cloud. Fixed 24 fps, normal simulation speed."

[[videos]]
file = "world-before.webm"
poster = "before.jpg"
caption = "Before: the same battlefield, seed, camera, lighting and explosion size at revision b3ec859. The former effect starts with a sustained fireball."

[[videos]]
file = "impacts-close.webm"
poster = "impacts-close.jpg"
caption = "Close-up: dirt, stone and metal impacts, four seconds each. Real machine-gun flight and impact code at normal speed, without fuel smoke hiding the debris."

[[videos]]
file = "flares-close.webm"
poster = "flares-close.jpg"
caption = "Moonlit controlled close-up: the actual cloth canopy, suspension lines, descent and drifting trail. Fixed 30 fps, Forward+, normal simulation speed."

[[videos]]
file = "armaments.webm"
poster = "armaments.jpg"
caption = "Current build, left to right: grenade, HE and fuel. The second half shows machine-gun rounds striking dirt, stone and metal. Ground marks are 10 m apart. Fixed 30 fps."

[[videos]]
file = "before.webm"
poster = "before-range.jpg"
caption = "Before: the same controlled range at revision b3ec859, using the former shared explosion effect. Fixed 30 fps."

[[videos]]
file = "flares.webm"
poster = "flares.jpg"
caption = "Current build, Forward+: a following camera shows the flare's open cloth canopy, suspension lines, sparks and lingering smoke at night."

[[videos]]
file = "rts.webm"
poster = "rts.jpg"
caption = "Current build: the same HE burst from a higher RTS camera, with the cloud following the scene's lighting and depth."

[[screenshots]]
file = "before.jpg"
caption = "Before: the shell uses a fiery explosion profile."

[[screenshots]]
file = "after.jpg"
caption = "After: the same shell throws earth and a turbulent dust cloud."
+++

The showcase moves from grenade (0:00) to HE (0:04), fuel (0:09), dirt/stone/metal impacts (0:14–0:20), then the night flare (0:20). These are controlled effect demonstrations in the actual battlefield; the matched before/after clips and focused close-ups remain below.

- Grenades have a small, brief flash and fast dark fragments. HE shells throw widening fans of earth, falling clods and dust. Fuel burns through a rising cloud of darker smoke.
- Animated clouds retain their billows as they roll and disperse. Sunlight and sky light shape them, roads produce greyer dust, and wet ground produces a darker, thinner cloud.
- Dust, landing debris and crater marks follow the ground height. Airbursts retain their flash and smoke without throwing earth from midair.
- Illumination flares sway beneath open cloth parachutes, descend with the wind, and leave smoke behind. Their trails stop emitting when the charge burns out and then disperse.
- Tracers light beyond the muzzle and dim with distance. Metal impacts shed small chips alongside sparks; dirt and stone produce their own debris.
- Effects reuse bounded pools and shared debris batches. Transparent areas are trimmed before drawing, and lower effects settings reduce animation work and particle counts.

The cloud animations come from licensed CC0 fluid simulations, with credits and rebuild instructions in the repository. The roughly 110 mm scale is an artistic reference, not a calibrated blast prediction. These silent clips show actual engine output at fixed simulation timing.

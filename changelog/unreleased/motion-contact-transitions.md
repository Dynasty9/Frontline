+++
title = "Smoother rifleman steps in the motion lab"
summary = "Foot contacts blend into slopes instead of snapping out of stretched anchors."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "Before: moving foot anchors were released abruptly on the terrain route."

[[screenshots]]
file = "after.jpg"
caption = "After: the same route uses blended contacts and preserves animated toe-off."
+++

Moving feet now keep their captured stride instead of being pinned until they stretch past a fixed limit. Slope rotation and pelvis correction blend gradually, while foot-ground clearance remains enforced. Idle animation continues when movement stops, and walk/run/strafe blends align their swing phase. The demo interpolates motion between physics ticks and clears contact history on reset.

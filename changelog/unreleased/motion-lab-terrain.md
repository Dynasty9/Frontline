+++
title = "Terrain and reload handling in the motion lab"
summary = "Try rifle movement on rolling terrain, with feet adapting to slopes and magazines disappearing into the kit during reload."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "Before: the controller operated on a flat inspection floor."

[[screenshots]]
file = "after.jpg"
caption = "After: the controller climbs rolling terrain and adjusts foot placement to the ground."
+++

The playable motion lab now includes a dirt track, uphill and downhill slopes, and uneven grass banks. Character and ragdoll collisions use the visible terrain. Feet sample the ground individually, align to its normal, and lower the pelvis when needed to reach the downhill surface.

The reload magazine disappears while stowed in the kit, then the replacement appears as the hand returns. Replaying or scrubbing the clip restores visibility correctly.

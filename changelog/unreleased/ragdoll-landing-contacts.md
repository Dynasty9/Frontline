+++
title = "Ragdolls settle with firmer landing contacts"
summary = "Additional position-solving steps reduce limb penetration during the tested jogging blast."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "Before: the jogging-blast fixture reached 4.7 cm of torso/forearm collider overlap after landing."

[[screenshots]]
file = "after.jpg"
caption = "After: the same fixture stays below 1.7 cm with ten position-solving steps."
+++

Jolt now uses ten position-solving steps instead of eight. The existing overlap, joint-separation, and skin checks pass for standing, crouching, prone, three jogging impact times, and the older character's standing pose. The 16-body replacement and cleanup fixture also passes. Early transient joint separation remains separate unfinished work; this is not a guarantee against every pose or impact.

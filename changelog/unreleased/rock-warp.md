+++
title = "Break up repeating cliff textures"
summary = "World-space texture warping breaks up repeated slab patterns without adding material samples."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "Before: shared terrain baseline, identical seed and camera."

[[screenshots]]
file = "after.jpg"
caption = "After: World-space texture warping breaks up repeated slab patterns without adding material samples."

[[screenshots]]
file = "close-before.jpg"
caption = "Before: matching closer camera, shared baseline."

[[screenshots]]
file = "close-after.jpg"
caption = "After: the same closer camera; surface changes remain subtle."
+++

Three additional scalar noise reads per terrain fragment; material reads stay at eighteen. Warping is fixed in world space and shared by colour and normal coordinates.

Technique reference: [research source](https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-1-generating-complex-procedural-terrains-using-gpu).

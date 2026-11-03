+++
title = "Add directional weathering to cliffs"
summary = "Narrow mineral stains run down exposed cliffs, interrupted by ledges and changes in rock type."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "Before: shared terrain baseline, identical seed and camera."

[[screenshots]]
file = "after.jpg"
caption = "After: Narrow mineral stains run down exposed cliffs, interrupted by ledges and changes in rock type."

[[screenshots]]
file = "close-before.jpg"
caption = "Before: matching closer camera, shared baseline."

[[screenshots]]
file = "close-after.jpg"
caption = "After: the same closer camera; surface changes remain subtle."
+++

One extra scalar noise read per terrain fragment. This is directional material weathering rather than a hydrology simulation; geometry and traversal do not change.

Technique reference: [research source](https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-1-generating-complex-procedural-terrains-using-gpu).

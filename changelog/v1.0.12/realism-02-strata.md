+++
title = "Give geological layers surface relief"
summary = "Rock beds catch light along their ledges instead of appearing only as painted colour bands."
kind = "improved"

[[screenshots]]
file = "target-before.jpg"
caption = "Before: target view, matching seed and camera."

[[screenshots]]
file = "target-after.jpg"
caption = "After: target view, matching seed and camera."

[[screenshots]]
file = "wide-before.jpg"
caption = "Before: wide view, matching seed and camera."

[[screenshots]]
file = "wide-after.jpg"
caption = "After: wide view, matching seed and camera."
+++

Screen-space derivatives perturb normals from the existing tilted bedding field. No displaced collision surface or new texture reads.

Research: [primary reference](https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-1-generating-complex-procedural-terrains-using-gpu).

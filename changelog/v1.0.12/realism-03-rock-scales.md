+++
title = "Blend rock detail across different scales"
summary = "Broad cliff fractures and smaller joint patterns break up recognisable repeated rock tiles."
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

A second triplanar colour/normal scale is blended coherently. Six extra material reads at Medium/Far detail; Near keeps the cheaper original material.

Research: [primary reference](https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-1-generating-complex-procedural-terrains-using-gpu).

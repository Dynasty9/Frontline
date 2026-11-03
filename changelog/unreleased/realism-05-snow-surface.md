+++
title = "Break up smooth snow with wind-shaped surface detail"
summary = "Snow shelves gain shallow wind grooves and granular highlights instead of perfectly smooth white surfaces."
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

Adds derivative-filtered snow surface relief and changes its roughness coherently. The wind-groove approximation extends the existing slope/exposure snow coverage; it does not implement the reference occlusion map.

Research: [primary reference](https://download.nvidia.com/developer/SDK/Individual_Samples/DEMOS/Direct3D9/src/SnowAccumulation/Docs/SnowAccumulation.pdf).

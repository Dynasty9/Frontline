+++
title = "Separate ranges with distance-based scattering"
summary = "Distant mountain groups lose contrast into sky-coloured haze while nearby ground retains its detail."
kind = "improved"

[[screenshots]]
file = "target-before.jpg"
caption = "Previous proposal: target view, matching seed and camera."

[[screenshots]]
file = "target-after.jpg"
caption = "Revised: target view, matching seed and camera."

[[screenshots]]
file = "wide-before.jpg"
caption = "Previous proposal: wide view, matching seed and camera."

[[screenshots]]
file = "wide-after.jpg"
caption = "Revised: wide view, matching seed and camera."
+++

Exponential extinction with sky-coloured in-scattering; a deliberately simplified approximation, not a full atmospheric solver. Uses the existing Alpine haze option.

Research: [primary reference](https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-16-accurate-atmospheric-scattering).

The revision reduces the broad pale wash, delays scattering until beyond nearby terrain, and lets high ridges retain contrast. Approved layer relief and texture-scale changes are retained in this parent branch.

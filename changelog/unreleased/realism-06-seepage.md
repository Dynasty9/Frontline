+++
title = "Give damp cliff streaks a wet surface response"
summary = "Sheltered runoff channels darken and develop a restrained sheen while exposed rock remains dry."
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

Existing runoff/shelter fields drive darkening, roughness and a bounded direct-light lobe. This is persistent seepage styling, not a hydrology simulation.

Research: [primary reference](https://seblagarde.wordpress.com/2013/03/19/water-drop-3a-physically-based-wet-surfaces/).

Compatibility retains damp colour and roughness but skips the extra direct-light sheen to avoid bright faceting.

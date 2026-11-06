+++
title = "Natural coasts, fuller forests and alpine surfaces"
summary = "Irregular bays, fuller forests, textured snow and woodland ground cover give the battlefield more natural variation."
kind = "improved"

[[screenshots]]
file = "coast-before.jpg"
caption = "Before: the ocean ends in a square beside the scenery."

[[screenshots]]
file = "coast-after.jpg"
caption = "After: distant water follows bays around the mountains. Same seed and camera."

[[screenshots]]
file = "forest-before.jpg"
caption = "Before: sparse hillside trees and bare ground, matching close camera."

[[screenshots]]
file = "forest-after.jpg"
caption = "After: fuller canopies, connected stands and woodland ground cover, matching close camera."

[[screenshots]]
file = "compat-before.jpg"
caption = "Compatibility before: linear ground colours were displayed too dark."

[[screenshots]]
file = "compat-after.jpg"
caption = "Compatibility after: corrected material output brings ground and foliage into the same palette."
[[screenshots]]
file = "snow-before.jpg"
caption = "Before: smooth white snow on the coastal ridge."

[[screenshots]]
file = "snow-after.jpg"
caption = "After: photographed powder, granular relief and dirtier melt edges. Same ridge, seed and camera."
[[screenshots]]
file = "lighting-before.jpg"
caption = "Before: distant forest stays sunlit below a mountain ridge."

[[screenshots]]
file = "lighting-after.jpg"
caption = "After: the ridge shades its valley and forest. Same golden-hour lighting, seed and camera."
+++

The ocean keeps detailed waves near the battlefield and uses a coarser surface beyond it.

Hillside woods use varied photographed tree silhouettes and a shared placement/ground-cover mask. Trees rotate around their bases as the camera tilts. Offline edge correction removes the dark fringe from their canopies.

Snow uses photographed powder at its original two-metre scale, with darker melt edges. Forest floors blend moss and leaf litter beneath the same hillside stands. Detailed surfaces follow the terrain-detail setting; texture arrays keep these layers within the browser renderer's sampler budget.

Distant ridges now shade their valleys and forests with cached terrain lighting. Changing the time of day refreshes that lighting without rebuilding the forest. Standing rainwater stays on gentle ground instead of making cliff faces reflect like puddles.

+++
title = "Broken stone across mountain faces"
summary = "Mountain faces gain broken mineral layers, darker weathered seams and uneven pockets of loose stone."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "Before: the previous rock material, with the same seed, golden-hour lighting and camera."

[[screenshots]]
file = "after.jpg"
caption = "After: interrupted mineral layers and darker weathering break up broad rock faces."
[[screenshots]]
file = "detail.jpg"
caption = "Closer daylight view of varied rock surfaces and sheltered stone pockets."
+++

Cliff materials combine larger elongated fractures with smaller photographic grain.
The detail is baked into the existing material textures, including normals and
occlusion, so it uses no additional terrain texture samples. Tilted mineral beds
break across the faces rather than forming continuous stripes.
Sheltered seams weather darker, while loose stone collects unevenly on gentler
ground and in pockets. These masks reuse existing texture reads.

This improves surface shading; mountain silhouettes and movement limits are unchanged.

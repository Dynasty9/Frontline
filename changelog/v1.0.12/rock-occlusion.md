+++
title = "Give rock crevices more depth"
summary = "Sheltered rock crevices receive stronger ambient occlusion while exposed rock stays open to sky light."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "Before: shared terrain baseline, identical seed and camera."

[[screenshots]]
file = "after.jpg"
caption = "After: Sheltered rock crevices receive stronger ambient occlusion while exposed rock stays open to sky light."

[[screenshots]]
file = "close-before.jpg"
caption = "Before: matching closer camera, shared baseline."

[[screenshots]]
file = "close-after.jpg"
caption = "After: the same closer camera; surface changes remain subtle."

[[screenshots]]
file = "target-before.jpg"
caption = "Before: focused comparison under matched lighting."

[[screenshots]]
file = "target-after.jpg"
caption = "After: Watch the shaded recess beside the central rib under diffuse light."
+++

No new texture reads. Occlusion affects ambient lighting, with the existing direct-light contribution retained. This is a material approximation, not new ray tracing.

Technique reference: [research source](https://developer.nvidia.com/gpugems/gpugems/part-iii-materials/chapter-17-ambient-occlusion).

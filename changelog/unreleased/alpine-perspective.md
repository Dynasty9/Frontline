+++
title = "Separate distant mountain ranges with sky haze"
summary = "Optional alpine haze takes on the sky colour and settles lightly into lower valleys."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "Before: shared terrain baseline, identical seed and camera."

[[screenshots]]
file = "after.jpg"
caption = "After: Optional alpine haze takes on the sky colour and settles lightly into lower valleys."

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
caption = "After: Watch the tone and separation of the distant ridges in hazy weather."
+++

Uses existing alpine_haze option and engine fog; no new volumetric pass. Disabled/flat-map paths reset both additions. Compatibility may approximate aerial perspective differently.

Technique reference: [research source](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html).

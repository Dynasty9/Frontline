+++
title = "Preserve the captured rifleman's stride"
summary = "Locomotion keeps the authored leg swing while movement and action transitions continue blending."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "Running with an additional filter applied to every animation pose."

[[screenshots]]
file = "after.jpg"
caption = "Running with the captured gait preserved through the shared controller."
+++

Removes extra pose smoothing that shortened the effective leg swing and contributed to sliding. Direction and speed changes still blend, as do jumps and reloads. Foot contact improves, particularly during forward running, but residual sliding remains.

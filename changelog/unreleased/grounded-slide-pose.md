+++
title = "Keep combat slides low and feet first"
summary = "Sliding into cover no longer lifts the leading boot toward the soldier's head."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "The old slide combined a large backward body tilt with an excessive thigh lift."

[[screenshots]]
file = "after.jpg"
caption = "A lower hip, extended leading leg and folded trailing knee keep the slide near the ground."
+++

The shared procedural slide pose now uses a lower, feet-first posture. This also improves the slide transferred to skinned riflemen, while leaving movement speed and gameplay timing unchanged.

Entering or leaving a slide now blends even when the unit remains crouched. The original mocap contact solver also releases stretched foot plants gradually, preventing a large ankle jump during ordinary walking; resetting the actor clears those contact offsets.

+++
title = "Rifle movement follows the captured stride"
summary = "Walking, running and strafing playback now follows each animation's authored travel distance."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "Terrain controller with one shared stride distance for all movement clips."

[[screenshots]]
file = "after.jpg"
caption = "Terrain controller with playback synchronized to the captured travel distance."
+++

Skinned riflemen now synchronize their steps using each clip's original travel distance, including different forward, backward and sideways strides. Direction changes still share a continuous gait phase. This reduces foot sliding; full moving-foot planting remains unfinished.

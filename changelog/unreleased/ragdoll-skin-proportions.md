+++
title = "Ragdoll skins keep their limb lengths"
summary = "Prototype skeletal ragdolls no longer stretch their skin with temporary physics-joint separation."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "Before: bone positions followed the rigid bodies independently."

[[screenshots]]
file = "after.jpg"
caption = "After: the skeleton preserves captured proportions while following the simulated body."
+++

Ragdoll rendering preserves captured local bone positions and follows simulated child joints with rotations. The pelvis retains the simulated root position. The prone impact fixture previously changed a forearm's length by 6.3 cm; the corrected SWAT fixtures keep length error below 1 mm. Tests also bound settled skin-to-collider offset, rather than checking proportions alone. This corrects visible stretching; early physical constraint separation still needs work.

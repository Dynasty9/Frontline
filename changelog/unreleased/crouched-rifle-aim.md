+++
title = "Preserve rifle aim while crouching"
summary = "Crouch and reload blends keep the captured upper body aimed forward instead of inheriting an unrelated pelvis lean."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "The unarmed crouch pelvis tipped the rifle toward the floor."

[[screenshots]]
file = "after.jpg"
caption = "The corrected spine blend preserves rifle aim above the crouched legs."
+++

The captured animation controller compensates for the crouch pelvis rotation at the spine. Reload blends also account for the receiving pelvis, including the game's crouched reload overlay. Arm lengths, the support grip and the crouched lower body retain their existing constraints.

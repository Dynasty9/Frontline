+++
title = "Ragdolls keep their limbs outside the body"
summary = "Skinned riflemen no longer freely fold their arms and legs through their torso after a hit."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "Before: non-connected limbs could pass through each other during collapse."

[[screenshots]]
file = "after.jpg"
caption = "After: body collisions and tighter spine constraints keep the collapse supported."
+++

Skinned ragdolls now collide with their own non-connected body parts. The torso collider covers the abdomen, spine bending is more limited, and the physics solver resolves contacts and joint positions more accurately. Adjacent bones still share a flexible joint, and the ragdoll retains the animation's pose when hit.

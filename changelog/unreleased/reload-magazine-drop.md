+++
title = "Detached magazines fall independently on death"
summary = "A soldier killed while holding a magazine now drops it separately from the rifle."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "Before: the removed magazine remained attached to the dropped rifle's transform."

[[screenshots]]
file = "after.jpg"
caption = "After: the magazine falls independently and rests on the ground."
+++

The skinned reload tracks whether the visible magazine is outside the rifle. Fatal hits preserve its exact pose and give it a separate collision body with inherited motion. Magazines already stowed in the kit stay hidden; seated magazines remain with the rifle. Corpse cleanup and revival restore ownership without losing the prop.

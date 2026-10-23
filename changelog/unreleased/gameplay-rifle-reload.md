+++
title = "Captured reloads for prototype riflemen"
summary = "Standing SWAT riflemen now use the captured reload and moving magazine in gameplay."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "Before: procedural reload with a fixed magazine."

[[screenshots]]
file = "after.jpg"
caption = "After: captured hand motion and magazine handling follow the gameplay reload duration."
+++

The opt-in SWAT rifleman plays its captured reload over the rifle reload duration. The magazine disappears while stowed, returns with the replacement, and resets if the action is interrupted. Prone and crouched reloads still use the procedural fallback.

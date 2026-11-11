+++
title = "Jump animation follows the landing"
summary = "The character playground keeps the captured jump pose airborne until the character touches down."
kind = "fixed"
[[videos]]
file = "jump.mp4"
poster = "after.jpg"
caption = "Controlled playground jump with the shared controller; fixed 30 fps capture."
[[screenshots]]
file = "before.jpg"
caption = "Before: the clip fades to standing while the character is still airborne. Frames are 0.1 seconds apart."
[[screenshots]]
file = "after.jpg"
caption = "After: the captured pose follows ascent and descent, then blends out after ground contact."
+++

The installed rifle jump was shorter than the physical jump. Its pose now follows vertical movement, holds through longer falls, and recovers after actual ground contact. This fixes the early return to a walking or standing pose in midair.

Early, normal and delayed landing timing and the playground controls were checked. The recording shows a level-ground playground jump, not a battlefield or multiplayer test.

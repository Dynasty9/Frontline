+++
title = "Keep close-up soldiers animating smoothly"
summary = "Soldier animation update rates follow the camera currently on screen."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "Earlier gameplay recording with animation rate tied to the RTS camera."

[[screenshots]]
file = "after.jpg"
caption = "Gameplay recording with animation rate following the active inspection camera."
+++

Switching to the combat inspection camera now keeps nearby soldiers animating every frame, even when they are outside the inactive RTS camera's view. Distant and off-screen soldiers still use reduced update rates.

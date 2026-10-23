+++
title = "Check room before going prone"
summary = "Soldiers remain crouched when a wall blocks the space needed to lie down."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "Before: the prone transition takes the hands through the wall."

[[screenshots]]
file = "after.jpg"
caption = "After: the soldier remains crouched until there is room to lie down."
+++

The server checks cover collision against the space swept by a kneel-to-prone transition. A blocked soldier keeps a crouched posture, including in replicated state; clear space allows prone entry again. The check reserves room for the arms and boots as well as the torso, and avoids leaving a crawling action on a blocked crouched soldier.

This is a conservative clearance check, not automatic repositioning or a new wall-specific transition animation. It can keep a soldier crouched where a tighter authored transition might fit.

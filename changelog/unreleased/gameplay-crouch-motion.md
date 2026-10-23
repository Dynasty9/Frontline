+++
title = "Use captured crouch movement in gameplay"
summary = "Opt-in skinned riflemen use the shared crouch controller while moving and return to a grounded kneel when stopped."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "The gameplay rifleman previously used procedural crouch movement."

[[screenshots]]
file = "after.jpg"
caption = "Moving crouched riflemen now use the captured lower-body motion with the corrected rifle pose."
+++

The gameplay animation path now uses the shared captured controller for crouched movement, while retaining the grounded stationary kneel and its reload. Crouch sampling no longer restarts posture transitions. The support-hand constraint also blends in during stance changes, preventing an abrupt arm pull when returning from kneeling or prone.

+++
title = "Smoother skinned posture changes"
summary = "Prototype riflemen retain their corrected pose when changing between kneeling and prone."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "Before: the kneeling foot correction was dropped on entering prone."

[[screenshots]]
file = "after.jpg"
caption = "After: posture blending retains the previous corrected skin pose."
+++

Skinned procedural postures now have distinct transition states. Whole-body posture changes blend over 0.65 seconds, including interrupted changes; aiming crossfades keep their existing timing. The focused gameplay test reduced the largest sampled joint displacement from 40.5 cm to 12.7 cm per physics step. This removes an abrupt contact discontinuity but does not replace the procedural prone pose with captured motion.

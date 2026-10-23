+++
title = "Skinned gunners follow mounted grips"
summary = "Prototype skinned gunners keep both palms on the mounted weapon during traverse and recoil."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "Before: transferred arm rotations leave the hands behind the grips."

[[screenshots]]
file = "after.jpg"
caption = "After: a forward lean and arm IK place the palms on the moving anchors."

[[screenshots]]
file = "clearance-before.jpg"
caption = "Before stance correction: the forward leg enters the emplacement platform."

[[screenshots]]
file = "clearance-after.jpg"
caption = "After: the supporting boot sits beside the gunner with the knee outside the platform."
+++

The optional skinned prototype now solves mounted-gun arm contact after animation blending, preserving limb lengths and stabilizing wrist orientation. The focused kneeling M2 demo checks both palms through seven seconds of traverse and recoil. Finger wrapping and mounted reload choreography remain unfinished.

Mounted kneeling now places the supporting foot beside the gunner and bends the knee outward. The test uses the actual emplacement stance function, platform dimensions, and full traverse arc, checking leg-segment clearance as well as palm contact. Ordinary crouched reload foot placement is unchanged.

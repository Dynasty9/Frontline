+++
title = "Reduce ragdoll impact overlap"
summary = "Earlier collision contacts reduce limbs pressing into the torso and walls during impacts."
kind = "improved"

[[screenshots]]
file = "comparison.jpg"
caption = "Running wall impact before (left) and after (right)"
+++

Physics now detects potential contacts slightly earlier. In the running wall-impact test, peak forearm/torso overlap falls from 5.1 cm to 3.3 cm, while wall penetration falls from 3.9 cm to 2.6 cm. Standing, crouched and prone impacts and dropped-rifle contact checks also pass.

The ragdoll regression now checks the first second of the impact as well as the settled body. Brief contact overlap remains; this is a reduction rather than its complete elimination.

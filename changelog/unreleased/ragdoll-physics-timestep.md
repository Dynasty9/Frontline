+++
title = "Smoother physical landings"
summary = "Physics updates 120 times per second while battle logic stays at 60, improving fast ragdoll contacts."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "Running wall impact at 60 Hz: the forearm briefly enters the chest."

[[screenshots]]
file = "after.jpg"
caption = "Running wall impact at 120 Hz: smaller steps improve limb contact."
+++

Characters and dropped equipment now receive smaller physics steps. Battle AI and replication keep their own 60 Hz update, and host movement interpolates between those battle updates. Standing, crouched, running, and prone impact checks pass with the new rate, including the original character model. Accelerated test runs also retain the configured physics rate.

This changes simulation timing and can change combat outcomes for the same seed. Large-battle performance and remaining animation polish still need further evaluation.

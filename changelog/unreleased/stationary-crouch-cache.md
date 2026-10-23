+++
title = "Reduce repeated crouch animation work"
summary = "Stationary skinned riflemen reuse their unchanged lower-body animation sample."
kind = "improved"
+++

A crouched rifleman whose animation phase and transform have not changed now reuses the captured lower-body pose. Terrain contacts, hits, recoil, reloads and transitions still update. Movement, turns and controller resets invalidate the cached sample.

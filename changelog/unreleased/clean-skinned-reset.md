+++
title = "Clear stale motion when a skinned soldier resets"
summary = "Revived and reset riflemen no longer retain an earlier hit or recoil kick."
kind = "fixed"
+++

Gameplay revival and the animation demo reset now clear impact springs, recoil and sampled motion together. Teleporting back to the starting position also resets the travel origin, preventing that teleport from becoming the next ragdoll's launch velocity.

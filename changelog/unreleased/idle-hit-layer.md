+++
title = "Avoid redundant skinned pose updates"
summary = "Skinned soldiers skip inactive hit updates and unused upper-body crouch retargeting."
kind = "improved"
+++

The shared hit layer continues advancing its recovery spring, but only updates spine bones when there is a visible reaction. Idle animation poses remain unchanged, and new hits still react immediately.

Captured crouch movement retargets only the pelvis and legs it needs. The rifle's upper-body pose stays unchanged.

Fully crouched riflemen also skip standing-foot calculations that the crouch animation replaces, preserving the resulting pose while reducing animation work.

Weapon fitting stops repeating unchanged reach checks once both hands fit the held rifle.

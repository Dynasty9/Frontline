+++
title = "Skinned soldiers respond differently to bullets and blasts"
summary = "Fatal bullet hits now push the chest more than the limbs, while explosions retain their full-body throw."
kind = "fixed"
+++

The skinned ragdoll now receives the original death type through the game's shared effects path. Previously that path reduced a bullet's force before assigning the same velocity to every limb, losing the stronger chest response. Collapse preserves movement without adding impact or spin. The animation viewer and showcase use the same distinction for fatal shots and explosions.

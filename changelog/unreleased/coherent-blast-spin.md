+++
title = "Keep blast-driven ragdoll motion coherent"
summary = "A blast spins the body around its center instead of giving disconnected spins to each limb."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "Earlier blast handoff with independent limb spins."

[[screenshots]]
file = "after.jpg"
caption = "The same impact with matching motion around the body's center of mass."
+++

Blast knockback now gives each limb the matching sideways motion for rotation around the body's center of mass. This removes an artificial velocity mismatch at connected joints when animation hands off to physics. Bullet and collapse impulses retain their existing behavior. Wall penetration remains under refinement.

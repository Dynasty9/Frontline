+++
title = "Keep the rifle support grip steady during movement"
summary = "Captured rifle locomotion now keeps the support hand attached through animation blends."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "Terrain movement before support-grip stabilization."

[[screenshots]]
file = "after.jpg"
caption = "The same terrain route with the captured support grip constrained."
+++

The shared rifle controller preserves the captured idle support grip using the existing arm IK. It retains the captured elbow bend and arm lengths, and releases the constraint gradually during reloads and jumps so their hand motion stays intact.

+++
title = "Captured prone entry for prototype riflemen"
summary = "Stationary skinned riflemen use the downloaded kneel-to-prone motion and its supported aiming pose."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "Before: procedural prone aiming placed the face and rifle close to the ground."

[[screenshots]]
file = "after.jpg"
caption = "After: captured arm support and a raised head in the settled prone pose."
+++

With local SWAT and Mixamo assets installed, stationary prone idle and shooting use the captured kneel-to-prone clip through the shared gameplay driver. Interrupted transitions retain the existing pose blend, and the rifle stays attached to its native hand socket. Crawling, prone reload, and aiming over cover retain their existing fallbacks. A dedicated get-up animation and terrain fitting remain unfinished.

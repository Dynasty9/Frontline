+++
title = "Corrected skinned ragdoll hinge direction"
summary = "Bent knees and elbows retain their allowed bend when a character becomes a ragdoll."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "Earlier prototype: standing bullet collapse before the hinge direction correction."

[[screenshots]]
file = "after.jpg"
caption = "Current prototype: standing bullet collapse with corrected knee and elbow limits."
+++

Corrects reversed joint limits that could force a bent limb to snap when physics took over. This remains an experimental presentation: some blast landings still separate the physical joints too far. The images show successive prototype versions, not an isolated comparison of this fix.

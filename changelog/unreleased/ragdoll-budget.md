+++
title = "Repeated death effects preserve active ragdolls"
summary = "Duplicate skinned death effects no longer freeze an unrelated corpse when the ragdoll budget is full."
kind = "fixed"
+++

Already-dead skinned characters are rejected before evicting the oldest active ragdoll. A 17-character prototype fixture checks the 16-body limit, oldest-body replacement, duplicate death handling, weapon ownership, and eventual physics cleanup.

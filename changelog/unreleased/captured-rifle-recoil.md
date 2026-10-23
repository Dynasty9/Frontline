+++
title = "Restore firing recoil on captured rifle animations"
summary = "Captured rifle poses now respond to firing without separating the hands from the weapon."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "Captured rifle pose before the burst."

[[screenshots]]
file = "after.jpg"
caption = "Recoil raises the captured upper body and rifle together during the burst."
+++

Native rifle animations now consume the existing firing recoil spring in standing movement, captured prone poses and animation previews. The upper body, arms and rifle rise together, keeping the captured grips intact and leaving planted feet in place. Previously firing recoil was queued but only applied by the procedural weapon pose.

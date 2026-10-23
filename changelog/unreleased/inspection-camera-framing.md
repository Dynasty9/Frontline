+++
title = "Keep combat inspection shots readable near foliage"
summary = "Partial foliage cover no longer forces a tight overhead view."
kind = "fixed"

[[screenshots]]
file = "before.jpg"
caption = "Seed-3 motion demo at three seconds: the previous fallback moves directly above the soldier."

[[screenshots]]
file = "after.jpg"
caption = "The same moment keeps a normal viewing distance and favors the clearest available angle."
+++

The motion-demo camera ranks partially clear views when no angle reveals the whole soldier. Nearby foliage can still obscure a limb, but the camera preserves useful framing instead of snapping into a close overhead shot.

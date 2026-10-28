+++
title = "Smoother rifle handling between infantry actions"
summary = "The optional SWAT preview keeps its rifle through free-hand actions and improves reloads, cover aim and low-wall crossings."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "Before: grenade handling carried the rifle with the throwing hand"

[[screenshots]]
file = "after.jpg"
caption = "After: grenade handling frees the working hand and returns to rifle aim"

[[screenshots]]
file = "vault.jpg"
caption = "The actual soldier renderer keeps the knees tucked across a low wall"
+++

- Rifle stow and draw blend through the existing Mixamo back-reach clip; free-hand actions keep the rifle on the sling instead of hiding it.
- Prone and leaning reloads release the support hand to handle the magazine while preserving the body pose.
- Dive and flinch poses keep the rifle lower, and tall-wall aiming places the visible muzzle farther around the corner.
- Occupied cover positions are excluded from new cover choices.
- Low-wall crossings retain the visual vault until the character clears the obstacle without changing simulation movement timing.

This remains the optional local-asset preview. The procedural vault is not a hand-planted authored vault; vehicle boarding and mounted-weapon reloads are outside this update.

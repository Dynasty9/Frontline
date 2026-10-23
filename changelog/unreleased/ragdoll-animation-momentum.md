+++
title = "Ragdolls inherit animated limb motion"
summary = "Moving soldiers carry their limb and rifle motion into physics when they fall."
kind = "improved"
+++

The optional skinned characters now sample their final corrected pose before death. Ragdolls inherit limb translation and rotation alongside the unit's travel and impact, including the velocity at each collider's center of mass. The dropped rifle inherits its actual motion rather than receiving an arbitrary spin on bullet deaths. Resets and viewer scrubbing clear the motion history.

Motion sampling shares the skeleton transform and normalizes each bone orientation once, reducing repeated work while preserving the momentum passed into physics.

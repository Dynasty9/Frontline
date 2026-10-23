+++
title = "Skinned rifleman animation and impact evaluation"
summary = "An optional imported rifleman brings foot contacts, stable rifle grips and skeletal ragdolls into battles."
kind = "improved"

[[screenshots]]
file = "before.jpg"
caption = "Before: the original procedural and mocap comparison."

[[screenshots]]
file = "after.jpg"
caption = "After: the armored character retains its original skin weights and uses foot and two-hand contact solving."

[[screenshots]]
file = "battle.jpg"
caption = "The same skinned rifleman reacts to a staged blast in a running battle."

[[screenshots]]
file = "source-gun-before.jpg"
caption = "Before: aiming between the mannequin's hands tilted the rifle barrel upward."

[[screenshots]]
file = "source-gun-after.jpg"
caption = "After: a fixed animated hand socket retains the rifle's authored orientation."

[[screenshots]]
file = "inspector.jpg"
caption = "The model inspector shows the live source skeleton, named joints, and character mesh statistics."


[[screenshots]]
file = "reload-before.jpg"
caption = "Before: the reload hand moved while the magazine stayed inside the rifle."

[[screenshots]]
file = "reload-after.jpg"
caption = "After: the magazine is a separate prop following the reload hand."

[[screenshots]]
file = "controller.jpg"
caption = "The playable controller keeps the model inspector available during movement and actions."

+++

- Rifle idle, walk and jog share the supplied motion capture clips while preserving the receiving model's proportions.
- Planted feet and two-hand rifle contacts are solved after animation. Hits add directional recovery, and deaths transfer the same skin to constrained physics with a dropped rifle.
- The optional `--skinned-units` flag enables locally installed assets for Coalition riflemen in real battles. The `motion` test scenario includes staged infantry and tank impacts.
- This is an art and animation evaluation. Source assets are installed locally, and unsupported actions still use procedural poses. It is not a complete replacement animation library.

- Foot contacts sample the battlefield height under each boot. Short pose blends reduce snapping when switching between motion capture and procedural stances.
- Directional hit recovery also affects kneeling and prone poses while preserving the rifle grips.
- A local interactive motion viewer lets you choose sample animations, pause and scrub playback, orbit the character, and click to test projectile hits or ragdolls.

- The original mocap mannequin now holds its rifle on a fixed animated hand socket, correcting the barrel tilt and retaining the grip through lowering and relaxed poses.
- The Motion Lab now includes live skeleton and joint overlays, bone names and selection, shaded/wireframe views, and character mesh statistics for both models.
- A local SWAT character trial and 32 Mixamo animation files can now be inspected alongside the MCO sample, with native playback for reloads and the authored kneel-to-prone transition.

The optional motion lab now has a playable controller with camera-relative movement, directional animation blending, jumping, crouching, and reloads. Inspect its bones and triangles while moving, or shoot it to test ragdolls. The M4 magazine now moves with the reload hand rather than remaining fixed inside the rifle.

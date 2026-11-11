+++
title = "Captured rifle strikes and ladder climbing"
summary = "SWAT rifle strikes and watchtower climbing use captured motion, with smoother activity and weapon transitions."
kind = "improved"
[[screenshots]]
file = "ladder.jpg"
caption = "A soldier follows the watchtower's rear ladder and steps through its platform opening."
[[screenshots]]
file = "ladder-before.jpg"
caption = "Before: the soldier ascended inside the tower instead of following the ladder. Baseline fixture omits terrain textures."
[[videos]]
file = "actions.mp4"
poster = "melee.jpg"
caption = "Shared gameplay renderer: armed idle, captured rifle strike, recovery, ladder cycle and drawing the rifle again."
+++

Rifle melee now uses a captured strike timed to the existing hit. Climbing follows the watchtower's ladder over four seconds, followed by a short step onto the platform. The rear railing has an opening for the climber.

Activities blend from the previous pose, and the support hand returns gradually as the rifle leaves its sling.

Eleven additional animation clips are bundled with the optional SWAT character. The single-person carrying family and turning door kick are available in the inspector; they do not replace the game's two-person stretcher or low grenade kicks.

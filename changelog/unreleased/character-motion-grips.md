+++
title = "Steadier rifle grips and directional crouching"
summary = "Keep rifle grips through action changes, use matching directional crouch clips, and orbit the character with Alt."
kind = "fixed"

[[screenshots]]
file = "winded-before.png"
caption = "Before: support-hand placement breaks during winded recovery"

[[screenshots]]
file = "winded-after.jpg"
caption = "Walking, winded recovery and return to firing with the support hand seated on the rifle"
+++

The imported-character preview now uses all eight matching crouch directions from the installed Rifle 8-Way Locomotion pack. Direction changes blend gait phases, and planted feet release before a reversing leg overextends. Existing installations without that pack retain the previous crouch cycle.

Rifle recovery keeps both hands within reach and seats the support palm after pose blending, including cook, winded, smother, kick and idle-look transitions. Getting up from prone still releases the supporting hand naturally.

In the local Character Playground, hold Alt and move the mouse to inspect the character from another angle without changing aim or movement direction. The viewing offset remains when Alt is released; Home resets it. Right-drag still turns the character. This preview requires the locally installed evaluation assets.

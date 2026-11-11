+++
title = "Sharper blasts with rolling ground dust"
summary = "Explosions strike with a brief flash, a low rush of dust and a layered crack, rumble and falling grit. Grenades have a shorter report; larger blasts carry more weight."
kind = "improved"

[[videos]]
file = "impact-comparison.webm"
poster = "impact-comparison.jpg"
caption = "Same gun run, camera and instant. The previous take is above and the revised take below. Listen to the gun report decay. At 2 seconds grass shows between the revised bursts. At 5 seconds the center wreck is burning low while smoke still rises from the outer vehicles."

[[videos]]
file = "wreck-landing.webm"
poster = "wreck-landing.jpg"
caption = "Rightmost A-10 target at the same game time. The lower wreck lands once and stays beside its impact mark."

[[videos]]
file = "cover.webm"
poster = "cover.jpg"
caption = "Sandbag-height view. Compare the low dust behind the middle of the wall at 2 s and 10 s. The upper cloud rises over the bags in both takes."

[[videos]]
file = "world.webm"
poster = "world.jpg"
caption = "A shell lands beside a sandbag position. Watch the darker soil spread at ground level and the upper dust drift with the wind. Recorded in the game at 24 fps with sound."

[[videos]]
file = "after.webm"
poster = "after.jpg"
caption = "After, with sound: grenade at 1 second, HE at 5 seconds and fuel at 9 seconds. Unmute to hear the actual game mix. Controlled range, 30 fps, normal speed."

[[videos]]
file = "before.webm"
poster = "before.jpg"
caption = "Before this refinement, with sound: the same range, camera, seed and event timing at PR revision 3fced130. Unmute to compare the original reports."

+++

- Neighbouring impacts have different widths, heights and rolling edges. Fuel fires show brighter cores through darker soot.
- Nearby wall faces arrest low dust and leave openings at the ends and above the wall.
- A fast, low dust surge connects the rising cloud to the ground. Smoke fades into terrain and cover instead of ending at a sharp billboard edge.
- Brief flashes remain readable at 30 fps without turning HE into a sustained fireball.
- Reports combine a sharp pressure crack, an irregular low rumble, scattered ground returns and falling grit. Grenades use the shorter report instead of the shell sound.
- Sounds fade cleanly and retain headroom before mixing; the existing master limiter handles overlapping blasts. Dust uses the existing bounded particle pools, and airbursts do not throw up ground dust.

These clips contain real engine audio recorded with the picture. They are controlled effect demonstrations, not combat performance benchmarks. The original PR's other recordings remain available in its rolling-dust entry.

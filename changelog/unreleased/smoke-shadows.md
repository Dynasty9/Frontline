+++
title = "Smoke and dust cast shadows"
summary = "A smoke screen now shades the ground, the soldiers and vehicles under it and the sunlit haze, on the side away from the sun. Dust clouds, burning houses, strike plumes and drifting palls do the same."
kind = "improved"

[[screenshots]]
file = "golden-hour-off-on-diff.jpg"
caption = "Golden hour, the same frozen frame with the shadow off and on, and the difference four times over (dark is shade): the screens in the town square shade the paving, the grass and the haze on their far side from the sun"

[[screenshots]]
file = "midday-off-on-diff.jpg"
caption = "Midday, the same: with the sun high the shade lies close under the smoke"

[[screenshots]]
file = "golden-hour-top-down-diff.jpg"
caption = "Golden hour from straight above, the screens left undrawn so the ground under them shows: the shade falls the same way as the statue's and the benches' own shadows"

[[videos]]
file = "golden-hour-drift.webm"
poster = "golden-hour-drift.jpg"
caption = "Smoke screens rolling out and drifting downwind in the town square at golden hour: their shade grows and moves with them, soft and steady."

[[videos]]
file = "zoom-threshold.webm"
poster = "zoom-threshold.jpg"
caption = "Renderer diagnostic, before and after: fixed scene and lighting while the zoom input crosses 70 m and 180 m. Map resolution now changes gradually. Inert fixture, not gameplay; no grading or amplified differences."
+++

- **Smoke screens** shade what's under them and on their far side from the sun: the ground, the soldiers and vehicles
  in the smoke, the trees and houses beside it. The shade is as thick as the smoke drawn there: under the thick end
  of a full screen the ground loses about half its sunlight, under its thin tail much less.
- **The haze stops at the smoke**: in the sunlit air at dawn, golden hour and dusk, the light shafts stop at a smoke
  screen, leaving darker air on its far side.
- **Dust and fire smoke too**: a shell's dust cloud briefly shades the ground round the crater, a burning house or
  wreck throws a dark band downwind, a strike's pillar of black smoke and a barrage's drifting pall shade the ground
  beneath them, and a column's road dust leaves a faint strip. The higher the smoke, the further from it its shade
  falls, and the lower the sun, the longer.
- It shades only what's below the smoke: a hilltop or the air above it stays in the sun, and the smoke itself isn't
  darkened.
- It costs very little: about 0.03 ms a frame. Light only: who can see whom is unchanged. Not in the browser version.

- Zooming through the shadow map’s detail boundaries now changes its resolution gradually, avoiding a sudden brightness step in stationary shade.

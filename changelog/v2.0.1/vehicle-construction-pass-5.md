+++
title = "Lighter vehicle models"
summary = "Every vehicle model now has about 45% less geometry and builds about 38% faster, and looks the same."
kind = "improved"
+++

- The parts every vehicle shares (tyres, bolts, hinges, lamps, shackles, smoke dischargers, lockers and dozens
  more) were rebuilt to draw only what can be seen: hidden caps and inner faces are gone, small parts use fewer
  segments, and bends no longer carry a ball at every joint. Side-by-side renders of every vehicle family differ
  on at most 0.03% of pixels.
- Measured across all 135 vehicle models on one machine (Godot 4.7.2, team 0, seed 3, two runs each): geometry
  fell from 33.1 million to 18.5 million vertices, and building every model from cold took 16.3 seconds instead
  of 26.4. GPU time per frame on the vehicle roster scenario barely moved (13.8 to 13.1 ms at the median, within
  run-to-run noise), so expect smoother vehicle spawns rather than a higher frame rate on that scene.
- Searchlights show their lens: a solid collar used to hide it.

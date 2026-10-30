+++
title = "Less repeated work in large battles"
summary = "Large battles avoid repeated scenery and visibility work while keeping the battlefield responsive."
kind = "improved"


[[screenshots]]
file = "after.png"
caption = "After: the same map and camera, with visibility-aware rendering and native routes. Combat evolves independently between runs."

[[screenshots]]
file = "before.png"
caption = "Before: the generated 3 km battlefield at command zoom."



[layout_comparison]
before = "layout-before.jpg"
after = "layout-after.jpg"
caption = "Changelog presentation comparison, not gameplay: the top 1,000 pixels of this entry at the same 900-pixel viewport width. Open either image to inspect it."
+++

Scenery follows the camera's view, and soldiers avoid repeating sight checks against unchanged walls.

- Scenery loads around what the camera can see, including a margin for roofs and screen edges.
- Large maps store navigation cells compactly, saving about 1.25 GiB across the two 3 km land grids.
- Replay recording reuses unchanged scenery and encodes completed chunks in the background to reduce battle stalls.
- Formation planning reuses nearby cover checks while retaining the same selected positions.
- Native path search skips intermediate cost nodes while retaining terrain and danger costs.
- Soldiers reuse confirmed obstruction by an unchanged wall. Opening a door or changing the blocking geometry immediately requires a fresh check; smoke remains live.

- Distant soldiers outside the camera view no longer rebuild render batches.
- Tactical symbols retain their image between 15 Hz updates while the camera and pointer are still; camera movement and input refresh them immediately.

Large-map performance is still being measured. These changes do not establish 60 FPS support for 500-unit battles.

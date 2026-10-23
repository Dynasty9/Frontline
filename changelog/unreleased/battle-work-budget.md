+++
title = "Less repeated work in large battles"
summary = "Scenery follows the camera's view, and soldiers avoid repeating sight checks against unchanged walls."
kind = "improved"

[[screenshots]]
file = "before.png"
caption = "Before: the generated 3 km battlefield at command zoom."

[[screenshots]]
file = "after.png"
caption = "After: the same map and camera, with visibility-aware rendering and native routes. Combat evolves independently between runs."
+++

- Scenery loads around what the camera can see, including a margin for roofs and screen edges.
- Native path search skips intermediate cost nodes while retaining terrain and danger costs.
- Soldiers reuse confirmed obstruction by an unchanged wall. Opening a door or changing the blocking geometry immediately requires a fresh check; smoke remains live.

- Distant soldiers outside the camera view no longer rebuild render batches.
- Tactical symbols retain their image between 15 Hz updates while the camera and pointer are still; camera movement and input refresh them immediately.

Large-map performance is still being measured. These changes do not establish 60 FPS support for 500-unit battles.

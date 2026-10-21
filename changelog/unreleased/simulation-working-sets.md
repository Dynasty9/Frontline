+++
title = "Large-battle simulation and rendering improvements"
summary = "Desktop solo battles run simulation separately, share more AI work, and draw distant soldiers more efficiently. Skirmishes offer maps up to 3,072 metres across."
kind = "improved"

[[screenshots]]
file = "before.png"
caption = "The earlier 500-soldier rendering test on a 1,024 metre map."

[[screenshots]]
file = "after.png"
caption = "A full generated 3,072 metre battlefield, started with 480 soldiers and 20 vehicles. The 60 FPS target remains under validation."

[[screenshots]]
file = "vehicle-before.png"
caption = "Detailed vehicle materials at distant camera range, magnified for comparison."

[[screenshots]]
file = "vehicle-after.png"
caption = "Distant vehicles share simpler material surfaces while retaining their silhouettes and moving turrets."
+++

- Static scenery no longer runs an empty building simulation every tick. Fire and combat still affect it.
- Supply and unit-cap checks search the bases directly, including changes from construction, capture and destruction.
- Performance diagnostics now distinguish sustained simulation cost from occasional slow ticks.
- Updating nearby cover no longer rebuilds routes through ground whose movement cost has not changed.
- Desktop solo battles and missions run their simulation separately from drawing, with pause, resume and reconnect support.
- Skirmish setup offers 1,024, 2,048 and 3,072 metre square maps. Larger maps need more memory.
- Squad members share threat assessments and building contacts; individual weapons, visibility and damage still work independently.
- Distant soldiers share simpler animated poses, while close-up soldiers retain detailed movement.
- Movement orders spread pathfinding work across ticks, including when buildings are destroyed or routes are blocked.
- Updates include the native simulation helper as well as the game executable.

- Explosions update nearby terrain textures and cosmetic ground collision instead of rebuilding the entire map.
- Large maps load without drawing the partly built battlefield; the private simulation waits until loading finishes.
- Static scenery replication and map placement avoid repeated whole-map searches.
- Nearby scenery loads first; distant scenery is cached as you explore the map.
- Cosmetic grass, bushes and stones build around the camera rather than across the whole map during play.
- Nearby units can reuse checked movement corridors, while keeping their own destinations.
- Short unobstructed moves respond immediately, including dashes into cover.
- Squads retry an unvisited house when a rifleman becomes available to clear it.
- Soldiers checking buildings search house floors directly, skipping unrelated nearby scenery.
- Emplaced gunners choose targets their gun can reach instead of fixating on enemies outside its firing arc.
- Soldiers evaluate the same reaction priorities with less decision-processing overhead.
- Squad callsigns and order labels reuse their drawings while tracking the camera, reducing interface work in large battles.
- Stationary units avoid redundant model-transform updates, and distant soldier batches avoid rebuilding string keys each frame.
- Radio notifications reuse unchanged text drawings between their arrival flashes and fade-out.
- Distant vehicles simplify material surfaces while retaining their moving parts; close-up vehicles keep their detailed materials.
- Distant soldier rendering visits active pose batches instead of every cached pose each frame.
- Squad status markers share a short overview refresh, and empty selections avoid scanning every soldier.
- The minimap keeps distant fighting markers separate on larger maps.
- Stationary vehicles avoid repeatedly updating unchanged hull, turret and wheel transforms.

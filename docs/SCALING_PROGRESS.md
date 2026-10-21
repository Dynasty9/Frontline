# 500-unit scaling implementation

Target: 500 combined active units, 2 km then 3 km square maps, sustained 60 FPS.
Reference machine: Intel i9-11900K (8 cores / 16 threads), NVIDIA RTX 3090.
Preserve individual combat, authoritative outcomes and off-screen simulation.

## Acceptance gates

- [ ] A: repeatable stress matrix, rendered frame percentiles, long-run memory and simulation reports
- [x] B: bounded path scheduling and incremental graph rebuilds, lifecycle regression tests
- [x] C: managed local headless server, startup/readiness/version/exit/failure handling
- [ ] D: 500-unit simulation and rendering budgets on current map
- [ ] E: 2 km map, memory and multiplayer validation
- [ ] F: 3 km map, same validation
- [x] G: assess native/Rust work using measured remaining hotspots; implement if required

## Work log

- Earlier investigation removed scenery ticks, indexed FOB queries and eliminated unchanged navigation invalidations.
- Added a real-game stress scenario with configurable unit count, scenery, combat/march/idle modes and seed.

Do not interpret an unchecked gate or a headless result as validated 60 FPS support.

- B and C regression scenes pass, including blocked/reopened routes, order cancellation, delayed construction, commands, pause/resume, reconnect and child failure.
- G: native candidate selection implemented and checked against the GDScript reference; a full Rust simulation rewrite is not required by the measured evidence.
- Latest completed sustained sparse-map test: 53.7 FPS over 180 seconds, below target.
- Full generated 3 km mixed-unit runs complete without errors, but remain around 17 FPS. Deferred scenery reduced client loading from 268 s to 151 s and halved scene nodes. Spatial soldier batches reduced triangles but increased draw calls; a single-material distant pose is under validation. Close-camera and sustained target acceptance remain outstanding.

## 20 October continuation

- Private server joins now survive the menu lobby refresh; exported clients receive their battle.
- Grass streaming bounds nearby chunks; measured construction cost fell from about 11.8 to 0.12 ms per rendered frame in the two 3 km runs. Overall frame time did not improve in those runs; substantial unrelated CPU load prevents a controlled comparison.
- Headless entities no longer dispatch visual callbacks. Short clear local moves bypass the path queue so immediate cover movement is responsive.
- The full behavior suite after that change passes 52/60 tests. Remaining failures cover attack attrition, tank/defense outcomes, fire damage, gun hits, house clearing and grenade reactions. Assertions have not been relaxed.
- Latest diagnostic headless 3 km / 480 soldiers + 20 vehicles run: 366 measured ticks over 20 seconds; p50 50.26 ms, p95 89.19 ms, maximum 128.03 ms. No runtime errors, but the simulation budget fails. This was not a controlled idle-machine benchmark.
- A focused regression confirms busy riflemen no longer permanently skip an unvisited house; the tactics scenario still clears only one house and remains unresolved.
- Keep PR #93 in draft. Rendered 60 FPS and the larger-map acceptance gates remain unmet.

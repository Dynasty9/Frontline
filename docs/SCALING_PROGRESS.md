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

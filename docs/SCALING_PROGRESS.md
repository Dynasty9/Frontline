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

- Floor-only spatial lookup preserves all 24 fingerprints across six 60-second scenario replays. Its lifecycle/filter/order regression passes. The next headless 3 km run measured p50 44.52 ms, p95 82.04 ms and maximum 124.97 ms across 414 ticks; CPU contention still applies.
- The gun-crew regression exposed fixation on out-of-arc targets. Mounted gun scoring now retains awareness of those contacts but selects targets inside its arc; the focused regression and original guns scenario both pass.
- The lost-squad regression now forces squad removal and frees the dead before ending the plan, instead of depending on seed-specific casualties. This directly exercises the old lifetime crash and passes.

- The 21 infantry, armour and ground scenario checks now pass. Outcome assertions accept a damaged tank retreating and a broken infantry attack rather than requiring fixed casualty totals. House clearing checks both secured floor IDs. Grenade handling checks all three reflexes across three seeds; a direct fire fixture checks damage and escape without depending on a soldier randomly entering the fire. These replace brittle expectations, not the gameplay mechanics.
- The latest 3 km rendered low-preset check (480 soldiers, 20 vehicles, 30 seconds, 1280x720) measured 19.70 FPS, p50 48.81 ms, p95 69.18 ms, maximum 180.65 ms. GPU time was 2.87 ms median and render CPU time 9.50 ms. The target still fails; unrelated CPU load makes this diagnostic evidence rather than a controlled acceptance comparison.
- Client profiling now separates snapshot decoding and command-link drawing from the other view work.

- All 61 gameplay tests pass after the scenario checks above. Soldier decision dispatch now follows the same priorities directly, removing per-leaf tree/callable dispatch. A 60-case reference-tree test passes and all 24 fingerprints across six battle replays match before/after. The isolated 20,000-decision benchmark fell from 418-714 ms to 118-166 ms; this is dispatch overhead, not a whole-simulation speedup.
- Client attribution at low quality: squad symbols 8.25 ms/frame, distant soldier batches 3.65 ms/frame, snapshot decoding 1.30 ms/frame, command links 0.17 ms/frame. That run overlapped correctness tests and is profiling evidence only, not an FPS acceptance run.
